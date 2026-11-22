#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
port.py — instalador universal de ports nativos para Android.

Lee manifiestos de tools/ports/*.json, descarga el APK oficial del release de
GitHub, extrae/valida los datos de tu copia del juego y comprueba lo que cada
port necesita (estructura de carpetas, TU18 de BO2, checksums del APK...).

Uso:
  python3 tools/port.py list
  python3 tools/port.py info bo2
  python3 tools/port.py install bo2
  python3 tools/port.py install nfsmw --solo-apk --instalar
  python3 tools/port.py verify bo2 /sdcard/Games/BO2/415608C3

Nada de datos del juego se descarga si no los aportas tú (--url/--lista).
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PORTS_DIR = os.path.join(HERE, "ports")
VERIFY_TU18 = os.path.join(HERE, "verificar_tu18.py")

TTY = sys.stdout.isatty()
C = dict(b="\033[1m", g="\033[32m", y="\033[33m", r="\033[31m", d="\033[2m", n="\033[0m") if TTY else \
    dict(b="", g="", y="", r="", d="", n="")

SRC_DIRS = [
    "/storage/emulated/0/Download",
    os.path.expanduser("~/storage/downloads"),
    "/sdcard/Download",
    "/storage/emulated/0",
    "/sdcard",
]
PART_PATTERNS = ("*.part1.rar", "*.part01.rar", "*.part001.rar")


# ------------------------------------------------------------------ utilidades
def step(msg):
    print("\n%s==>%s %s" % (C["b"], C["n"], msg))


def ok(msg):
    print("%s  OK%s %s" % (C["g"], C["n"], msg))


def warn(msg):
    print("%s  !!%s %s" % (C["y"], C["n"], msg))


def die(msg, code=1):
    print("%sERROR:%s %s" % (C["r"], C["n"], msg), file=sys.stderr)
    sys.exit(code)


def human(n):
    if n is None:
        return "?"
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or unit == "TB":
            return "%.1f %s" % (n, unit) if unit != "B" else "%d B" % n
        n /= 1024.0


def which(name):
    return shutil.which(name)


# ----------------------------------------------------------------- manifiestos
def load_manifest(port_id):
    path = os.path.join(PORTS_DIR, port_id + ".json")
    if not os.path.exists(path):
        die("no existe el port '%s' (usa: port.py list)" % port_id)
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    data["_file"] = path
    return data


def all_manifests():
    out = []
    if not os.path.isdir(PORTS_DIR):
        return out
    for name in sorted(os.listdir(PORTS_DIR)):
        if name.endswith(".json"):
            try:
                with open(os.path.join(PORTS_DIR, name), "r", encoding="utf-8") as f:
                    out.append(json.load(f))
            except Exception as e:
                warn("manifiesto inválido %s: %s" % (name, e))
    return out


# ---------------------------------------------------------------------- red
def http_get(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": "port-installer/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def latest_release(repo):
    try:
        data = json.loads(http_get("https://api.github.com/repos/%s/releases/latest" % repo).decode())
    except Exception as e:
        raise RuntimeError("no pude consultar los releases de %s: %s" % (repo, e))
    return data


def pick_asset(rel, pattern, exclude):
    assets = rel.get("assets") or []
    def bad(name):
        low = name.lower()
        return low.endswith((".sha256", ".txt", ".zip", ".tar.gz", ".log", ".json")) or "/src" in low
    cands = [a for a in assets if a["name"].lower().endswith(".apk") and not bad(a["name"])]
    if exclude:
        cands = [a for a in cands if exclude.lower() not in a["name"].lower()]
    if pattern:
        pref = [a for a in cands if pattern.lower() in a["name"].lower()]
        cands = pref or cands
    cands.sort(key=lambda a: ("arm64" not in a["name"].lower(), "armv8" not in a["name"].lower(), a["name"]))
    return cands[0] if cands else None


def download(url, dest, quiet=False):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        print("     ya existe: %s" % os.path.basename(dest))
        return dest
    print("     bajando: %s" % os.path.basename(dest))
    if which("curl"):
        cmd = ["curl", "-L", "--fail", "--retry", "3", "--retry-delay", "5", "-C", "-", "-o", dest, url]
        if not TTY or quiet:
            cmd.insert(1, "-sS")
        r = subprocess.run(cmd)
        if r.returncode != 0:
            raise RuntimeError("falló la descarga")
        return dest
    tmp = dest + ".part"
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "port-installer/1.0"})) as r, open(tmp, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        done = 0
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if TTY and total:
                sys.stdout.write("\r     %5.1f%%  %s" % (100.0 * done / total, human(done)))
                sys.stdout.flush()
    os.replace(tmp, dest)
    print()
    return dest


def resolve_mediafire(url):
    html = http_get(url).decode("utf-8", "ignore")
    m = re.search(r'https://download\d+\.mediafire\.com/[^"\'\s<>]+', html)
    if not m:
        m = re.search(r'id="downloadButton"[^>]*href="([^"]+)"', html)
    if not m:
        return None
    return m.group(0) if m.lastindex is None else m.group(1)


def resolve_url(url):
    if "mediafire.com/file/" in url:
        print("     resolviendo MediaFire...")
        direct = resolve_mediafire(url)
        if not direct:
            raise RuntimeError("no pude resolver MediaFire (¿captcha?). Bájalo a mano.")
        return direct
    return url


# ------------------------------------------------------------------ archivos
def free_gb(path):
    st = os.statvfs(path)
    return st.f_bavail * st.f_frsize / (1024.0 ** 3)


def find_part1(sources):
    for d in sources:
        if not os.path.isdir(d):
            continue
        found = []
        for pat in PART_PATTERNS:
            found += [os.path.join(d, f) for f in os.listdir(d) if f.lower().endswith(pat.replace("*", "").lower())]
        if not found:
            cands = [os.path.join(d, f) for f in os.listdir(d) if f.lower().endswith(".rar")]
            found = cands
        if found:
            found.sort(key=lambda p: os.path.getmtime(p), reverse=True)
            return found[0]
    return None


def sibling_parts(part1):
    base = re.sub(r"\.part\d+\.rar$", "", part1, flags=re.I)
    parts = [part1]
    n = 2
    while True:
        for fmt in (".part%d.rar", ".part%02d.rar", ".part%03d.rar"):
            p = base + (fmt % n)
            if os.path.exists(p):
                parts.append(p)
                break
        else:
            break
        n += 1
    return parts


EXTRACTED_PARTS = []


def extract(part1, dest):
    if not which("unrar"):
        raise RuntimeError("falta unrar (pkg install unrar)")
    os.makedirs(dest, exist_ok=True)
    log = os.path.join(os.environ.get("TMPDIR", "/tmp"), "port_unrar.log")
    with open(log, "w") as lf:
        proc = subprocess.Popen(["unrar", "x", "-o+", "-y", part1, dest + "/"], stdout=lf, stderr=subprocess.STDOUT)
        last = 0
        while proc.poll() is None:
            time.sleep(5)
            now = time.time()
            if TTY and now - last > 15:
                last = now
                size = 0
                for root, _dirs, files in os.walk(dest):
                    for f in files:
                        try:
                            size += os.path.getsize(os.path.join(root, f))
                        except OSError:
                            pass
                sys.stdout.write("\r     extraído: %s   " % human(size))
                sys.stdout.flush()
        if TTY:
            sys.stdout.write("\r")
    if proc.returncode != 0:
        raise RuntimeError("unrar terminó con error %d (log: %s)" % (proc.returncode, log))
    with open(log, "r", errors="ignore") as f:
        if "All OK" not in f.read():
            raise RuntimeError("la extracción no terminó con 'All OK' (log: %s)" % log)


# ------------------------------------------------------------------ validación
def normalize(root, rules):
    """Si te pasan la carpeta 415608C3 en vez del padre, ajusta las rutas."""
    root = os.path.abspath(root.rstrip("/"))
    if not rules:
        return root, (lambda p: p)
    first = rules[0]["path"].split("/")[0]
    if os.path.basename(root) == first:
        return root, (lambda p: p.split("/", 1)[1] if "/" in p else ".")
    return root, (lambda p: p)


def validate(root, rules, quiet=False):
    root, norm = normalize(root, rules)
    results = []
    for rule in rules:
        path = os.path.join(root, norm(rule["path"]))
        need = rule.get("min_files", 0)
        desc = rule.get("desc", rule["path"])
        if rule.get("type", "dir") == "dir":
            exists = os.path.isdir(path)
            count = 0
            if exists:
                for _dp, _dn, fs in os.walk(path):
                    count += len(fs)
            if need == 0 and not rule.get("required"):
                good = True
                detail = ("%d archivo(s)" % count) if exists else "ausente (opcional)"
            else:
                good = exists and count >= need
                detail = ("%d archivo(s)" % count) if exists else "no existe"
        else:
            good = os.path.isfile(path)
            detail = human(os.path.getsize(path)) if good else "no existe"
        results.append((good, desc, detail, path, need))
        if not quiet:
            (ok if good else warn)("%s: %s" % (desc, detail))
    return all(r[0] for r in results), root, results


def verify_tu18(folder):
    if not os.path.isfile(VERIFY_TU18):
        return None
    tus = [f for f in sorted(os.listdir(folder)) if os.path.isfile(os.path.join(folder, f))]
    if not tus:
        return False
    tu = os.path.join(folder, tus[0])
    print("     verificando %s" % tus[0])
    r = subprocess.run([sys.executable, VERIFY_TU18, tu], capture_output=True, text=True)
    for line in (r.stdout or "").strip().splitlines()[-4:]:
        print("     " + line)
    return r.returncode == 0


def verify_checksums(apk_path, rel):
    name = os.path.basename(apk_path)
    wanted = None
    for a in rel.get("assets") or []:
        low = a["name"].lower()
        if low.endswith(".sha256") or "sha256sum" in low:
            try:
                text = http_get(a["browser_download_url"], timeout=20).decode("utf-8", "ignore")
            except Exception:
                continue
            for line in text.splitlines():
                if name in line:
                    m = re.search(r"\b([0-9a-fA-F]{64})\b", line)
                    if m:
                        wanted = m.group(1).lower()
                        break
            if wanted:
                break
    if not wanted:
        return None
    h = hashlib.sha256()
    with open(apk_path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest() == wanted


def install_apk(apk_path, force_open=False):
    if force_open and which("termux-open"):
        subprocess.run(["termux-open", apk_path], check=False)
        ok("instalador abierto: pulsa Instalar")
        return True
    if which("pm"):
        r = subprocess.run(["pm", "install", "-r", apk_path], capture_output=True, text=True)
        if r.returncode == 0 and "Success" in (r.stdout or ""):
            ok("APK instalado")
            return True
    if which("termux-open"):
        subprocess.run(["termux-open", apk_path], check=False)
        ok("abre el instalador y pulsa Instalar")
        return True
    warn("instala el APK manualmente: %s" % apk_path)
    return False


# --------------------------------------------------------------------- comandos
def cmd_list(_args):
    rows = all_manifests()
    print("%sPorts disponibles (%d)%s\n" % (C["b"], len(rows), C["n"]))
    print("  %-11s %-38s %-22s %s" % ("ID", "JUEGO", "ORIGEN", "ESTADO"))
    for m in rows:
        state = "verificado" if m.get("verified") else "sin probar"
        print("  %-11s %-38s %-22s %s" % (m["id"], m["name"][:38], m.get("source", "")[:22], state))
    print("\nDetalle:  python3 tools/port.py info <id>")
    print("Instalar: python3 tools/port.py install <id>")


def cmd_info(args):
    m = load_manifest(args.port)
    print("%s%s%s  (%s)" % (C["b"], m["name"], C["n"], m["id"]))
    print("  Origen        : %s" % m.get("source", "?"))
    print("  Repo          : https://github.com/%s" % m["repo"])
    print("  Arquitectura  : %s · Android %s+ · ~%s GB libres" % (m.get("arch"), m.get("min_android", "?"), m.get("space_gb", "?")))
    print("  Datos         : %s" % m["data"].get("hint", ""))
    if m["data"].get("layout"):
        print("  Estructura esperada:")
        for r in m["data"]["layout"]:
            print("    - %-34s %s" % (r["path"], r.get("desc", "")))
    print("  Notas         : %s" % m.get("notes", ""))
    if not m.get("verified"):
        print("  %sEste port no está probado por este instalador: revisa su README.%s" % (C["y"], C["n"]))


def cmd_verify(args):
    m = load_manifest(args.port)
    rules = m["data"].get("layout") or []
    if not rules:
        warn("este port no define estructura verificable (modo %s)" % m["data"].get("mode"))
        return 0
    good, root, _ = validate(args.dir, rules)
    v = m["data"].get("verify")
    if good and v and v.get("tool") == "tu18":
        target = os.path.join(root, v["path"])
        good = verify_tu18(target) is True
    print()
    (ok if good else die)("verificación correcta: %s" % root if good else "faltan archivos en %s" % root)
    return 0 if good else 1


def collect_urls(args):
    urls = list(args.url or [])
    if args.lista:
        if not os.path.isfile(args.lista):
            die("no existe el archivo de enlaces: %s" % args.lista)
        with open(args.lista, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    urls.append(line)
    if not urls and args.pedir_enlaces and sys.stdin.isatty():
        step("Pega tus enlaces (uno por línea, Enter vacío para terminar)")
        while True:
            try:
                line = input().strip()
            except EOFError:
                break
            if not line:
                break
            urls.append(line)
    elif not urls and sys.stdin.isatty() and args.pedir_enlaces:
        warn("sin terminal interactiva: usa --url o --lista")
    return urls


def cmd_install(args):
    m = load_manifest(args.port)
    data = m["data"]
    mode = data.get("mode", "app-import")
    step("%s · %s" % (m["name"], m["id"]))
    print("  repo: https://github.com/%s" % m["repo"])
    print("  datos: %s" % data.get("hint", ""))

    if not m.get("verified"):
        warn("port no verificado por este instalador; si algo falla, revisa su README")

    dl_dir = args.dir_descargas or args.src or SRC_DIRS[0]
    sources = [dl_dir] + SRC_DIRS if not args.src else [args.src]

    # ---- datos del juego (solo si el port usa carpeta/archivos)
    game_ok = None
    if mode in ("folder", "iso") and not args.solo_apk:
        dest = args.datos or data.get("dest")
        if not dest:
            warn("este port no tiene carpeta destino fija; usa la app para elegir tus archivos")
            game_ok = None
        else:
            rules = data.get("layout") or []
            good = False
            if os.path.isdir(dest) and rules:
                good, _, _ = validate(dest, rules, quiet=True)
            if good and not args.forzar:
                step("Datos del juego ya presentes")
                ok(dest + " (usa --forzar para re-extraer)")
                game_ok = True
            else:
                step("Preparando datos del juego")
                print("     destino: %s" % dest)
                if not os.path.isdir(dest):
                    os.makedirs(dest, exist_ok=True)
                need = float(m.get("space_gb") or 0)
                if free_gb(dest) < need:
                    die("faltan ~%.0f GB libres en %s" % (need - free_gb(dest), dest))

                urls = collect_urls(args)
                if urls:
                    step("Descargando (%d enlace(s))" % len(urls))
                    for u in urls:
                        try:
                            d = download(resolve_url(u), os.path.join(dl_dir, os.path.basename(u.split("?")[0])))
                            ok(os.path.basename(d))
                        except Exception as e:
                            warn(str(e))

                part1 = find_part1(sources)
                if not part1:
                    warn("no encontré archivos que extraer")
                    print("     pon tus RAR en %s o usa --url/--lista" % dl_dir)
                    game_ok = False
                else:
                    parts = sibling_parts(part1)
                    ok("encontrado: %s (+%d parte(s))" % (os.path.basename(part1), len(parts) - 1))
                    step("Extrayendo (verifica CRC)")
                    try:
                        extract(part1, dest)
                        EXTRACTED_PARTS.extend(parts)
                    except Exception as e:
                        die(str(e))
                    ok("extracción verificada")
                    good, root, _ = validate(dest, rules)
                    game_ok = good
                    if not good:
                        die("los archivos extraídos no cumplen la estructura esperada")
                    v = data.get("verify")
                    if v and v.get("tool") == "tu18":
                        step("Verificando TU18")
                        if verify_tu18(os.path.join(root, v["path"])) is not True:
                            die("el Title Update no es un TU18 válido para este port")
                        ok("TU18 válido")

    # ---- APK
    if args.sin_apk:
        step("Resumen")
        print("     datos: %s" % ("ok" if game_ok else "pendiente"))
        print("     (--sin-apk: no se descarga el APK)")
        return 0
    step("APK oficial")
    try:
        rel = latest_release(m["repo"])
    except Exception as e:
        die(str(e))
    asset = pick_asset(rel, m.get("asset", ""), m.get("asset_exclude", ""))
    if not asset:
        die("el release %s no trae APK" % rel.get("tag_name"))
    print("     %s · %s · %s" % (rel.get("tag_name"), asset["name"], human(asset["size"])))
    try:
        apk = download(asset["browser_download_url"], os.path.join(dl_dir, asset["name"]))
    except Exception as e:
        die(str(e))
    chk = verify_checksums(apk, rel)
    if chk is True:
        ok("SHA-256 coincide con el release")
    elif chk is False:
        die("el SHA-256 del APK NO coincide: descarga corrupta o manipulada")
    else:
        print("     (el release no publica SHA-256 de este APK)")

    if not args.solo_apk:
        step("Datos: qué hacer ahora")
        if mode == "app-import":
            print("     la app importa tu copia desde su menú:")
            print("     %s" % data.get("hint", ""))
        elif mode == "app-download":
            print("     la app descarga los instaladores oficiales y pide tus claves:")
            print("     %s" % data.get("hint", ""))
        elif mode == "folder":
            if game_ok:
                print("     elige en la app: %s" % (args.datos or data.get("dest")))
            else:
                print("     cuando tengas los datos, elige la carpeta en la app")
        print("     requisitos: %s · Android %s+ · ~%s GB" % (m.get("arch"), m.get("min_android", "?"), m.get("space_gb", "?")))

    if args.borrar_archivos and EXTRACTED_PARTS:
        for f in EXTRACTED_PARTS:
            try:
                os.remove(f)
            except OSError:
                pass
        ok("archivos comprimidos eliminados (%d)" % len(EXTRACTED_PARTS))

    if args.instalar:
        install_apk(apk, force_open=True)
    else:
        print("\n  APK listo: %s" % apk)
        print("  Instálalo desde el administrador de archivos o repite con --instalar")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Instalador universal de ports nativos Android")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("list", help="lista los ports del catálogo")
    p.set_defaults(fn=cmd_list)

    p = sub.add_parser("info", help="muestra los requisitos de un port")
    p.add_argument("port")
    p.set_defaults(fn=cmd_info)

    p = sub.add_parser("verify", help="valida una carpeta de datos ya existente")
    p.add_argument("port")
    p.add_argument("dir")
    p.set_defaults(fn=cmd_verify)

    p = sub.add_parser("install", help="instala un port (APK + datos)")
    p.add_argument("port")
    p.add_argument("--datos", "--dest", dest="datos", default="", help="carpeta de datos del juego")
    p.add_argument("--src", default="", help="carpeta donde buscar/descargar los archivos")
    p.add_argument("--sin-apk", action="store_true", help="no descargar el APK")
    p.add_argument("--borrar-archivos", action="store_true", help="borra los RAR al terminar")
    p.add_argument("--url", action="append", default=[], help="enlace de descarga (repetible)")
    p.add_argument("--lista", default="", help="archivo con un enlace por línea")
    p.add_argument("--pedir-enlaces", action="store_true")
    p.add_argument("--dir-descargas", default="")
    p.add_argument("--solo-apk", action="store_true", help="solo descarga/instala el APK")
    p.add_argument("--forzar", action="store_true", help="re-extrae aunque ya exista")
    p.add_argument("--instalar", action="store_true", help="abre el instalador del APK")
    p.add_argument("--si", "-y", action="store_true", help="acepta todo (compatibilidad)")
    p.set_defaults(fn=cmd_install)

    args = ap.parse_args()
    sys.exit(args.fn(args) or 0)


if __name__ == "__main__":
    main()
