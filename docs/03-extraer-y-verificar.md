# 03 — Extraer y verificar

## 0. Automático (script del repo)

```bash
bash tools/setup_bo2.sh
```

Hace todo lo de esta página: busca las partes, comprueba espacio, extrae con CRC, valida la estructura y verifica el TU18. Las secciones siguientes son el equivalente manual (útil si algo falla).

## 1. Los RAR multi-volumen no se "unen"

Un pack como:

```text
CODBO2-DLC-TU-GOD.part1.rar   7,5 GB
CODBO2-DLC-TU-GOD.part2.rar   7,1 GB
```

es **un solo archivo dividido**. Se abre/extiende únicamente el `part1` y la herramienta lee el `part2` sola. No hay que concatenar, ni renombrar, ni usar "unir archivos".

Comprobar que son volúmenes reales del mismo set:

```bash
head -c 8 CODBO2-DLC-TU-GOD.part1.rar | xxd   # Rar!....
head -c 8 CODBO2-DLC-TU-GOD.part2.rar | xxd   # Rar!....
unrar l CODBO2-DLC-TU-GOD.part1.rar | head    # "Details: RAR 5, volume 1"
unrar l CODBO2-DLC-TU-GOD.part2.rar | head    # "Details: RAR 5, volume 2"
```

Si `part2` no empieza por `Rar!` o el número de volumen no cuadra, el set está incompleto o mezclado.

## 2. Espacio y destino

Antes de extraer:

```bash
df -h /storage/emulated/0
```

Necesitas **~17 GB libres** (el contenido descomprimido son ~16 GB). Extrae siempre a almacenamiento interno compartido, **nunca** a `Android/data` (Android 11+ bloquea el acceso).

Ruta recomendada:

```text
/storage/emulated/0/Games/BO2/
```

## 3. Extraer (verifica CRC de paso)

```bash
mkdir -p "/storage/emulated/0/Games/BO2"
cd "/storage/emulated/0/Download"
unrar x -o+ -y CODBO2-DLC-TU-GOD.part1.rar "/storage/emulated/0/Games/BO2/"
```

Al final debe decir:

```text
All OK
```

- `All OK` = todos los CRC correctos (archivo íntegro).
- `CRC failed` / `checksum error` = descarga corrupta: vuelve a bajar la parte que falla.
- Si se corta por espacio, libera y repite con `-o+` (sobrescribe).

En PC equivalen: **WinRAR** (abrir `part1` → Extraer en…) o **7-Zip** (clic derecho en `part1` → 7-Zip → Extraer aquí).

### Test sin extraer (opcional)

```bash
unrar t CODBO2-DLC-TU-GOD.part1.rar | tail -3
```

## 4. Verificar el TU18 (lo crítico)

El port solo arranca con un TU18 real. El nombre del archivo **no basta**: hay que leer el paquete STFS, sacar el `default_mp.xexp` y comparar su SHA-256.

```bash
python3 tools/verificar_tu18.py "/storage/emulated/0/Games/BO2/415608C3/000B0000/tu0000000e_00000000"
```

Salida esperada (resumida):

```text
Paquete: title=0x415608C3 mediaId=0x457AD131 version=14.14 contentType=0xB0000
Bloques: 21975  tablas: 1

default_mp.xexp: 2172928 bytes
SHA-256       : 7f4ee5e4b5ccfe71786ddc073a0363558e89634bb26c2929335aeb7f883c9499

RESULTADO: OK — es un TU18 aceptado por el port.
```

Con `--verbose` lista además todo el contenido del paquete (útil para ver los `.ff`, `default.xexp`, etc.).

Hashes aceptados:

```text
5d5780970f6e639b17c0570bae0e52a13bd1038e23c969428aef9d0c7d78681b
7f4ee5e4b5ccfe71786ddc073a0363558e89634bb26c2929335aeb7f883c9499
```

Si dice `NO SIRVE`, cambia el archivo del TU (`000B0000`) por otro TU18 de tu región/consola.

## 5. Verificar el juego

```bash
ROOT="/storage/emulated/0/Games/BO2/415608C3"
xxd -l 4 "$ROOT/00007000/3A213694CA20E8B1940B"        # 4c49 5645  -> "LIVE"
ls "$ROOT/00007000"/*.data | wc -l                      # 47
du -sh "$ROOT/00007000"                                 # ~7,4G
```

Tamaño de referencia de los 47 fragmentos: 46 × 170.459.136 bytes + 1 × 68.595.712 bytes.

## 6. Liberar espacio

Cuando el juego arranque y funcione:

```bash
rm -f "/storage/emulated/0/Download/CODBO2-DLC-TU-GOD.part1.rar" \
      "/storage/emulated/0/Download/CODBO2-DLC-TU-GOD.part2.rar"
```

Se recuperan ~15,7 GB. **No borres** `/storage/emulated/0/Games/BO2`.
