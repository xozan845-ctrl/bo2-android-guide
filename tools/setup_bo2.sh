#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: MIT
#
# setup_bo2.sh — deja lista la carpeta de Black Ops II para el port de Android.
#
#   1. busca los RAR multi-volumen (o un .rar único) en las carpetas típicas
#   2. comprueba espacio libre
#   3. extrae verificando CRC
#   4. localiza 415608C3 y valida la estructura (00007000 / 000B0000 / DLC)
#   5. verifica que el TU sea el TU18 por SHA-256
#   6. ofrece instalar el APK del port si lo encuentra
#
# Uso:
#   bash tools/setup_bo2.sh                 # todo automático
#   bash tools/setup_bo2.sh --yes           # sin preguntas
#   bash tools/setup_bo2.sh --src /sdcard/Download --dest /sdcard/Games/BO2
#   bash tools/setup_bo2.sh --force         # re-extraer aunque ya exista
#   bash tools/setup_bo2.sh --no-apk        # no ofrecer instalar el APK
#   bash tools/setup_bo2.sh --borrar-rar    # borrar los RAR al terminar OK
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
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# ------------------------------------------------------------------- opciones
while [ $# -gt 0 ]; do
  case "$1" in
    --dest)      DEST="${2:?falta ruta}"; shift 2 ;;
    --src)       SRC="${2:?falta ruta}"; shift 2 ;;
    --force|-f)  FORCE=1; shift ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --no-apk)    DO_APK=0; shift ;;
    --borrar-rar) DEL_RAR=1; shift ;;
    -h|--help)   usage ;;
    *) die "opción desconocida: $1 (usa --help)" ;;
  esac
done

[ -n "$SRC" ] && SRC_DIRS=("$SRC")

# ------------------------------------------------------------ dependencias
step "Comprobando dependencias"
need_pkg=()
command -v unrar >/dev/null 2>&1 || need_pkg+=(unrar)
command -v python3 >/dev/null 2>&1 || need_pkg+=(python)
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

if [ "$TREE_OK" -eq 1 ] && [ "$FORCE" -eq 0 ]; then
  step "Ya existe una instalación en $TITLE"
  ok "no hace falta extraer (usa --force para re-extraer)"
else
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
  if [ -n "$APK" ]; then
    ok "encontrado: $(basename "$APK") ($(human "$(stat -c %s "$APK")"))"
    if command -v pm >/dev/null 2>&1; then
      if pm list packages 2>/dev/null | grep -q 'org.bo2port.diagnostic'; then
        ok "el port ya está instalado"
      fi
    fi
    if ask "     ¿Abrir el instalador del APK ahora?"; then
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
