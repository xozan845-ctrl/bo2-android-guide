#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: MIT
#
# setup_bo2.sh — compatibilidad: instala BO2 usando el motor universal port.py.
# Equivale a:  python3 tools/port.py install bo2 ...
#
#   bash tools/setup_bo2.sh                 # todo automático
#   bash tools/setup_bo2.sh --lista enlaces.txt
#   bash tools/setup_bo2.sh --url URL --url URL
#   bash tools/setup_bo2.sh --pedir-enlaces
#   bash tools/setup_bo2.sh --dest /sdcard/Games/BO2
#   bash tools/setup_bo2.sh --no-apk        # solo datos
#   bash tools/setup_bo2.sh --force         # re-extraer
#   bash tools/setup_bo2.sh --borrar-rar    # borra los RAR al terminar
#   bash tools/setup_bo2.sh --instalar      # abre el instalador del APK
#
# Para otros juegos:  python3 tools/port.py list
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) ARGS+=(--datos "${2:?falta ruta}"); shift 2 ;;
    --src) ARGS+=(--src "${2:?falta ruta}"); shift 2 ;;
    --force|-f) ARGS+=(--forzar); shift ;;
    --yes|-y) ARGS+=(-y); shift ;;
    --no-apk) ARGS+=(--sin-apk); shift ;;
    --borrar-rar) ARGS+=(--borrar-archivos); shift ;;
    --descargar-apk) shift ;;   # ya es el comportamiento por defecto
    --help|-h)
      sed -n '6,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
exec python3 "$DIR/port.py" install bo2 "${ARGS[@]}"
