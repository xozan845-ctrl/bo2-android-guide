#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: MIT
#
# setup_bo2.sh — deja lista la carpeta de Black Ops II para el port de Android.
#
#   1. descarga los archivos que le indiques (o busca los RAR ya bajados)
#   2. comprueba espacio libre
#   3. extrae verificando CRC
#   4. localiza 415608C3 y valida la estructura (00007000 / 000B0000 / DLC)
#   5. verifica que el TU sea el TU18 por SHA-256
#   6. descarga el APK oficial del port (GitHub) e instala
#
# Uso:
#   bash tools/setup_bo2.sh                       # todo automático
#   bash tools/setup_bo2.sh --yes                 # sin preguntas (no abre el instalador)
#   bash tools/setup_bo2.sh --instalar            # abre el instalador del APK al final
#   bash tools/setup_bo2.sh --pedir-enlaces       # pide los enlaces al ejecutar
#   bash tools/setup_bo2.sh --lista enlaces.txt   # descarga tus enlaces (1 por línea)
#   bash tools/setup_bo2.sh --url URL1 --url URL2 # enlaces sueltos (MediaFire/Directo)
#   bash tools/setup_bo2.sh --descargar-apk       # baja el APK oficial del port
#   bash tools/setup_bo2.sh --src /sdcard/Download --dest /sdcard/Games/BO2
#   bash tools/setup_bo2.sh --force               # re-extraer aunque ya exista
#   bash tools/setup_bo2.sh --no-apk              # no descargar/instalar el APK
#   bash tools/setup_bo2.sh --borrar-rar          # borrar los RAR al terminar OK
#
# Nota: este script NO incluye enlaces a datos del juego. Usa --lista/--url con
# tus propios enlaces (por ejemplo, un respaldo de tu copia). El APK, en cambio,
# se descarga automáticamente desde los releases oficiales del port.
#
set -uo pipefail

DEST_DEFAULT="/storage/emulated/0/Games/BO2"
SRC_DIRS=(
  "/storage/emulated/0/Download"
  "$HOME/storage/downloads"
  "/sdcard/Download"
  "/storage/emulated/0"
  "/sdcard"
)

DEST="$DEST_DEFAULT"
SRC=""
FORCE=0
ASSUME_YES=0
DO_APK=1
DEL_RAR=0
RAR_FILES=()
MIN_FREE_GB=17

URLS=()
LISTA=""
DL_DIR=""
DOWNLOAD_APK=1
OPEN_INSTALLER=0
PEDIR=0
APK_REPO="spartansprm/BO2-Android-xbox360"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$SCRIPT_DIR/verificar_tu18.py"
TMP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
LOG="$TMP/setup_bo2_$(date +%s).log"

# ---------------------------------------------------------------- utilidades
if [ -t 1 ]; then
  B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; N=""
fi
step() { printf '\n%s==>%s %s\n' "$B" "$N" "$1"; }
ok()   { printf '%s  OK%s %s\n' "$G" "$N" "$1"; }
warn() { printf '%s  !!%s %s\n' "$Y" "$N" "$1"; }
die()  { printf '%sERROR:%s %s\n' "$R" "$N" "$1" >&2; exit 1; }

ask() { # ask "pregunta" -> 0 sí / 1 no
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local r
  read -r -p "$1 [s/N] " r </dev/tty || return 1
  case "$r" in s|S|si|Si|SI|y|Y|yes) return 0 ;; *) return 1 ;; esac
}

human() { numfmt --to=iec "$1" 2>/dev/null || echo "$1 bytes"; }

usage() {
  sed -n '/^# setup_bo2/,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'
  exit 0
}

# ------------------------------------------------------------------- opciones
while [ $# -gt 0 ]; do
  case "$1" in
    --dest)      DEST="${2:?falta ruta}"; shift 2 ;;
    --src)       SRC="${2:?falta ruta}"; shift 2 ;;
    --lista)     LISTA="${2:?falta archivo}"; shift 2 ;;
    --url)       URLS+=("${2:?falta url}"); shift 2 ;;
    --dir-descargas) DL_DIR="${2:?falta ruta}"; shift 2 ;;
    --descargar-apk) DOWNLOAD_APK=1; shift ;;
    --instalar)  OPEN_INSTALLER=1; shift ;;
    --pedir-enlaces) PEDIR=1; shift ;;
    --force|-f)  FORCE=1; shift ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --no-apk)    DO_APK=0; DOWNLOAD_APK=0; shift ;;
    --borrar-rar) DEL_RAR=1; shift ;;
    -h|--help)   usage ;;
    *) die "opción desconocida: $1 (usa --help)" ;;
  esac
done

[ -n "$SRC" ] && SRC_DIRS=("$SRC")

# carpeta donde se guardan las descargas
if [ -z "$DL_DIR" ]; then
  if [ -d "/storage/emulated/0/Download" ]; then DL_DIR="/storage/emulated/0/Download"
  elif [ -d "$HOME/storage/downloads" ]; then DL_DIR="$HOME/storage/downloads"
  else DL_DIR="${TMPDIR:-/tmp}"; fi
fi

# lee los enlaces del archivo --lista
if [ -n "$LISTA" ]; then
  [ -f "$LISTA" ] || die "no existe el archivo de enlaces: $LISTA"
  while IFS= read -r linea || [ -n "$linea" ]; do
    linea="${linea%$'\r'}"
    linea="${linea#"${linea%%[![:space:]]*}"}"
    linea="${linea%"${linea##*[![:space:]]}"}"
    case "$linea" in ''|\#*) continue ;; esac
    URLS+=("$linea")
  done < "$LISTA"
fi

# ------------------------------------------------------------ dependencias
step "Comprobando dependencias"
need_pkg=()
command -v unrar >/dev/null 2>&1 || need_pkg+=(unrar)
command -v python3 >/dev/null 2>&1 || need_pkg+=(python)
command -v curl >/dev/null 2>&1 || need_pkg+=(curl)
if [ ${#need_pkg[@]} -gt 0 ]; then
  if command -v pkg >/dev/null 2>&1; then
    warn "instalando: ${need_pkg[*]}"
    pkg install -y "${need_pkg[@]}" >/dev/null 2>&1 || die "no se pudieron instalar ${need_pkg[*]}"
  else
    die "faltan: ${need_pkg[*]} (instálalos con tu gestor de paquetes)"
  fi
fi
ok "unrar $(unrar 2>/dev/null | sed -n '2s/.*UNRAR \([0-9.]*\).*/\1/p') · python $(python3 -V 2>&1 | awk '{print $2}')"

# ------------------------------------------------------- ¿ya está hecho?
find_title_dir() {
  local d
  for d in "$DEST/415608C3" "$DEST"/*/415608C3 "$DEST"/*/*/415608C3; do
    [ -d "$d/00007000" ] && { echo "$d"; return 0; }
  done
  # último recurso: buscar una carpeta 00007000 y subir un nivel
  local g
  g=$(find "$DEST" -maxdepth 4 -type d -name 00007000 2>/dev/null | head -1)
  [ -n "$g" ] && { dirname "$g"; return 0; }
  return 1
}

TREE_OK=0
if TITLE=$(find_title_dir 2>/dev/null); then
  if [ -d "$TITLE/00007000" ] && [ -d "$TITLE/000B0000" ]; then TREE_OK=1; fi
fi

# ---------------------------------------------------------------- descargas
resolver_mediafire() { # $1 = página de MediaFire -> imprime la URL directa
  local url="$1" html direct
  html=$(curl -sL --max-time 60 -A \
    "Mozilla/5.0 (Linux; Android 14; SM-A566E) AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36" \
    "$url" 2>/dev/null) || return 1
  direct=$(printf '%s' "$html" | grep -oE 'https://download[0-9]+\.mediafire\.com/[^"[:space:]<>]+' | head -1)
  if [ -z "$direct" ]; then
    direct=$(printf '%s' "$html" | grep -oE 'id="downloadButton"[^>]*href="[^"]+"' | grep -oE 'https://[^"]+' | head -1)
  fi
  [ -n "$direct" ] || return 1
  printf '%s\n' "$direct"
}

nombre_url() { local n; n=$(basename "${1%%\?*}"); n="${n//%20/ }"; printf '%s\n' "$n"; }

descargar_url() { # $1 url, $2 dir -> imprime la ruta del archivo descargado
  local url="$1" dir="$2" direct name dest
  local -a prog=(); [ -t 2 ] || prog=(-sS)
  case "$url" in
    *mediafire.com/file/*)
      printf '     resolviendo MediaFire...\n' >&2
      direct=$(resolver_mediafire "$url") || {
        printf '  !! no pude resolver el enlace (puede pedir captcha). Descárgalo a mano.\n' >&2
        return 1
      }
      ;;
    *) direct="$url" ;;
  esac
  name=$(nombre_url "$url")
  case "$name" in
    *.rar|*.RAR|*.apk|*.APK|*.zip|*.iso|*.7z) ;;
    *) name=$(nombre_url "$direct") ;;
  esac
  [ -n "$name" ] || name="descarga_$(date +%s)"
  dest="$dir/$name"
  if [ -s "$dest" ]; then
    printf '     ya existe: %s\n' "$name" >&2
  else
    printf '     bajando: %s\n' "$name" >&2
    curl -L --fail --retry 3 --retry-delay 5 -C - "${prog[@]}" \
      -o "$dest" "$direct" || { printf '  !! falló la descarga de %s\n' "$name" >&2; return 1; }
    if [ "$(head -c 4 "$dest" 2>/dev/null)" != "Rar!" ] && [ "${dest##*.}" != "apk" ] \
       && [ "${dest##*.}" != "zip" ] && [ "${dest##*.}" != "iso" ] && [ "${dest##*.}" != "7z" ]; then
      printf '  !! el archivo no parece válido (¿HTML de error?): %s\n' "$dest" >&2
      rm -f "$dest"
      return 1
    fi
  fi
  printf '%s\n' "$dest"
}

descargar_lista() {
  [ ${#URLS[@]} -eq 0 ] && return 0
  step "Descargando archivos indicados (${#URLS[@]} enlace(s))"
  mkdir -p "$DL_DIR" || die "no puedo crear $DL_DIR"
  local u d okc=0 fail=0
  for u in "${URLS[@]}"; do
    printf '   - %s\n' "$u" >&2
    if d=$(descargar_url "$u" "$DL_DIR"); then
      ok "listo: $(basename "$d") ($(human "$(stat -c %s "$d")"))"
      okc=$((okc + 1))
    else
      fail=$((fail + 1))
    fi
  done
  ok "$okc descargado(s) · $fail fallo(s) · carpeta: $DL_DIR"
  [ "$fail" -eq 0 ]
}

if [ "$TREE_OK" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
  step "Ya existe una instalación en $TITLE"
  ok "no hace falta extraer (usa --force para re-extraer)"
else
  # pedir enlaces al vuelo (así el repo queda sin enlaces y cualquiera puede usarlo)
  if [ "$PEDIR" -eq 1 ] && [ ${#URLS[@]} -eq 0 ]; then
    step "Pega tus enlaces (uno por línea, Enter vacío para terminar)"
    if [ -r /dev/tty ]; then
      while IFS= read -r linea </dev/tty; do
        linea="${linea%$'\r'}"
        [ -z "$linea" ] && break
        URLS+=("$linea")
      done
      ok "${#URLS[@]} enlace(s) recibido(s)"
    else
      warn "no hay terminal interactiva; usa --lista o --url"
    fi
  fi

  if [ ${#URLS[@]} -gt 0 ]; then
    descargar_lista || warn "hubo descargas fallidas; continúo con lo que ya esté en disco"
    SRC_DIRS=("$DL_DIR" "${SRC_DIRS[@]}")
  fi

  # ------------------------------------------------------------ buscar RAR
  step "Buscando los archivos comprimidos"
  RAR1=""
  for dir in "${SRC_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    # part1.rar / part01.rar / .r00 -> se abre por el primero
    found=$(find "$dir" -maxdepth 2 -type f \
              \( -iname '*.part1.rar' -o -iname '*.part01.rar' -o -iname '*.part001.rar' \) \
              -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    if [ -n "$found" ]; then RAR1="$found"; break; fi
  done
  if [ -z "$RAR1" ]; then
    for dir in "${SRC_DIRS[@]}"; do
      [ -d "$dir" ] || continue
      found=$(find "$dir" -maxdepth 2 -type f -iname '*.rar' \
                -printf '%T@ %s %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f3-)
      if [ -n "$found" ]; then RAR1="$found"; break; fi
    done
  fi
  [ -n "$RAR1" ] || die "no encontré ningún .rar en: ${SRC_DIRS[*]} (usa --src)"

  ok "encontrado: $RAR1 ($(human "$(stat -c %s "$RAR1")"))"

    case "$RAR1" in
    *.[pP][aA][rR][tT]1.rar|*.[pP][aA][rR][tT]01.rar|*.[pP][aA][rR][tT]001.rar)
      base="${RAR1%.[pP][aA][rR][tT]*}"
      n=2; total=0
      RAR_FILES=("$RAR1")
      while :; do
        p2="${base}.part${n}.rar"; p2b="${base}.part0${n}.rar"; p2c="${base}.part00${n}.rar"
        if [ -f "$p2" ]; then last="$p2"; elif [ -f "$p2b" ]; then last="$p2b"; elif [ -f "$p2c" ]; then last="$p2c"; else break; fi
        RAR_FILES+=("$last")
        total=$((n)); n=$((n+1))
      done
      if [ "$total" -gt 0 ]; then
        ok "$((total - 1)) volumen(es) más detectado(s) (último: $(basename "$last"))"
      else
        warn "no encontré part2: el set puede estar incompleto"
      fi
      ;;
    *) RAR_FILES=("$RAR1") ;;
  esac

  # ------------------------------------------------------ comprobar volumen
  step "Comprobando que el archivo es válido"
  magic=$(head -c 4 "$RAR1" 2>/dev/null)
  [ "$magic" = "Rar!" ] || die "el archivo no es un RAR ($RAR1)"
  unrar l "$RAR1" 2>&1 | grep -qi 'RAR 5\|RAR 4' || die "unrar no reconoce el archivo"
  ok "cabecera RAR correcta"
  unrar l "$RAR1" 2>/dev/null | tail -3 | head -2

  # ------------------------------------------------------------- espacio
  step "Comprobando espacio libre"
  mkdir -p "$DEST" || die "no puedo crear $DEST"
  avail_kb=$(df -Pk "$DEST" | awk 'NR==2{print $4}')
  need_kb=$((MIN_FREE_GB * 1024 * 1024))
  printf '     libre: %s · necesario: ~%s GB\n' "$(human $((avail_kb*1024)))" "$MIN_FREE_GB"
  if [ "$avail_kb" -lt "$need_kb" ]; then
    die "no hay espacio suficiente en la partición de $DEST"
  fi
  ok "espacio suficiente"

  # ------------------------------------------------------------- extraer
  step "Extrayendo (verifica CRC de todos los archivos)"
  echo "     destino: $DEST"
  printf '     log: %s\n' "$LOG"
  unrar x -o+ -y "$RAR1" "$DEST/" >"$LOG" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 15
    printf '\r     extraído: %-8s' "$(du -sh "$DEST" 2>/dev/null | cut -f1)"
  done
  wait "$pid"; rc=$?
  printf '\r     extraído: %-8s\n' "$(du -sh "$DEST" 2>/dev/null | cut -f1)"
  if [ "$rc" -ne 0 ] || ! grep -q 'All OK' "$LOG"; then
    grep -iE 'CRC|checksum|error|corrupt' "$LOG" | tail -10
    die "la extracción no terminó bien (rc=$rc). Revisa el log: $LOG"
  fi
  ok "extracción completa y verificada (All OK)"

  TITLE=$(find_title_dir) || die "no encontré la carpeta del juego dentro de $DEST"
fi

# -------------------------------------------------------------- validación
step "Validando la estructura del juego"
echo "     carpeta del juego: $TITLE"

HEADER=$(find "$TITLE/00007000" -maxdepth 1 -type f ! -name '*.data' 2>/dev/null | head -1)
[ -n "$HEADER" ] || die "falta la cabecera GOD en 00007000"
[ "$(head -c 4 "$HEADER")" = "LIVE" ] || die "la cabecera GOD no empieza por LIVE"
DATA_DIR="$HEADER.data"
[ -d "$DATA_DIR" ] || die "falta la carpeta ${DATA_DIR##*/}"
frags=$(find "$DATA_DIR" -maxdepth 1 -name 'Data*' | wc -l)
[ "$frags" -ge 40 ] || die "solo hay $frags fragmentos Data en ${DATA_DIR##*/} (se esperan ~47)"
ok "juego: $(basename "$HEADER") + $frags fragmentos ($(du -sh "$TITLE/00007000" | cut -f1))"

[ -d "$TITLE/000B0000" ] || die "falta la carpeta 000B0000 (Title Update)"
TU=$(find "$TITLE/000B0000" -maxdepth 1 -type f | head -1)
[ -n "$TU" ] || die "000B0000 está vacía"
ok "title update: $(basename "$TU") ($(du -sh "$TU" | cut -f1))"

if [ -d "$TITLE/00000002" ]; then
  n_dlc=$(find "$TITLE/00000002" -maxdepth 1 -type f | wc -l)
  ok "DLC: $n_dlc paquete(s) ($(du -sh "$TITLE/00000002" | cut -f1))"
else
  warn "sin DLC (00000002): solo mapas base"
fi
[ -d "$TITLE/00009000" ] && ok "contenido extra 00009000 presente"

# ---------------------------------------------------------------- TU18
step "Verificando que el Title Update sea el TU18"
if [ ! -f "$VERIFY" ]; then
  warn "no encontré tools/verificar_tu18.py; sáltate este paso"
  TU_OK=2
else
  python3 "$VERIFY" "$TU"
  TU_OK=$?
fi

# ------------------------------------------------------------------ APK
APK=""
if [ "$DO_APK" -eq 1 ]; then
  step "Buscando el APK del port"
  for dir in "${SRC_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    APK=$(find "$dir" -maxdepth 2 -type f -iname 'BO2*v*.apk' -printf '%T@ %p\n' 2>/dev/null \
            | sort -rn | head -1 | cut -d' ' -f2-)
    [ -n "$APK" ] && break
  done
  if [ -z "$APK" ] && [ "$DOWNLOAD_APK" -eq 1 ]; then
    step "Descargando el APK oficial (GitHub releases)"
    json=$(curl -sL --max-time 30 \
      "https://api.github.com/repos/$APK_REPO/releases/latest" 2>/dev/null)
    apk_url=$(printf '%s' "$json" | tr ',' '\n' \
      | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | sed 's/.*"\(https[^"]*\)"/\1/' | grep -i '\.apk' \
      | grep -iE 'armv8' | head -1)
    [ -z "$apk_url" ] && apk_url=$(printf '%s' "$json" | tr ',' '\n' \
      | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | sed 's/.*"\(https[^"]*\)"/\1/' | grep -i '\.apk' | head -1)
    if [ -n "$apk_url" ]; then
      mkdir -p "$DL_DIR"
      apk_name=$(basename "$apk_url")
      if [ -s "$DL_DIR/$apk_name" ]; then
        APK="$DL_DIR/$apk_name"
        ok "ya descargado: $apk_name"
      else
        echo "     $apk_url"
        aprog=(); [ -t 2 ] || aprog=(-sS)
        if curl -L --fail --retry 3 -C - "${aprog[@]}" -o "$DL_DIR/$apk_name" "$apk_url"; then
          APK="$DL_DIR/$apk_name"
          ok "APK descargado: $apk_name ($(human "$(stat -c %s "$APK")"))"
        else
          warn "falló la descarga del APK"
        fi
      fi
    else
      warn "no pude consultar los releases (¿sin internet o límite de la API?)"
      echo "     descárgalo de: https://github.com/$APK_REPO/releases"
    fi
  fi

  if [ -n "$APK" ]; then
    ok "encontrado: $(basename "$APK") ($(human "$(stat -c %s "$APK")"))"
    if command -v pm >/dev/null 2>&1; then
      if pm list packages 2>/dev/null | grep -q 'org.bo2port.diagnostic'; then
        ok "el port ya está instalado"
      fi
    fi
    if [ "$OPEN_INSTALLER" -eq 1 ] || { [ "$ASSUME_YES" -eq 0 ] && ask "     ¿Abrir el instalador del APK ahora?"; }; then
      if command -v termux-open >/dev/null 2>&1; then
        termux-open "$APK" >/dev/null 2>&1 && ok "instalador abierto: pulsa Instalar"
      else
        warn "abre el APK manualmente desde el administrador de archivos"
      fi
    fi
  else
    warn "no hay APK en las carpetas buscadas"
    echo "     descárgalo de: https://github.com/spartansprm/BO2-Android-xbox360/releases"
  fi
fi

# --------------------------------------------------------------- resumen
step "Resumen"
echo "     Carpeta del juego : $TITLE"
echo "     Total             : $(du -sh "$TITLE" | cut -f1)"
echo "     Libre en disco    : $(df -h "$DEST" | awk 'NR==2{print $4}')"
case "${TU_OK:-2}" in
  0) echo "     TU18              : ${G}válido${N}" ;;
  1) echo "     TU18              : ${R}NO válido${N} -> consigue otro TU18" ;;
  *) echo "     TU18              : sin verificar" ;;
esac

cat <<EOF

${B}Siguiente paso (en la app BO2):${N}
  1. Abre el port y elige idioma.
  2. "Elegir carpeta del juego" -> navega a:
       $TITLE
     y selecciona ESA carpeta (la que contiene 00007000 y 000B0000).
  3. Acepta el permiso de acceso a la carpeta y espera el escaneo.
  4. Ajustes: Resolución Original 880x720, Calidad Baja/Media,
     "Preparar shaders antes de jugar" activado.
  5. Jugar -> Zombies.

Si algo falla, revisa docs/06-problemas.md
EOF

if [ "$DEL_RAR" -eq 1 ]; then
  if [ "${TU_OK:-2}" -eq 0 ]; then
    step "Borrando los RAR"
    for f in "${RAR_FILES[@]:-}"; do
      [ -f "$f" ] && rm -f "$f"
    done
    ok "RAR eliminados (se recuperó espacio)"
  else
    warn "no borro los RAR: el TU18 no está validado"
  fi
else
  echo "Cuando confirmes que el juego arranca, puedes borrar los RAR y recuperar ~16 GB."
  echo "  (o vuelve a ejecutar con --borrar-rar)"
fi

[ "${TU_OK:-2}" -eq 1 ] && exit 1
exit 0
