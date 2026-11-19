# 02 — Archivos del juego

El port **no trae datos del juego**: lee los mismos archivos que leería una Xbox 360. Por eso la estructura de carpetas importa.

## Estructura completa

Carpeta raíz de una instalación de Xbox 360:

```text
Content/0000000000000000/415608C3/
├── 00007000/     Juego (Games on Demand / GOD)
├── 000B0000/     Title Updates (aquí debe estar el TU18)
├── 00000002/     DLC / add-ons
└── 00009000/     Contenido extra del marketplace (opcional)
```

El port pide elegir la carpeta **`415608C3`** (la que contiene `00007000` y `000B0000`).

### `00007000` — el juego (obligatorio, ~7,4 GB)

Formato GOD (SVOD). Contiene:

```text
00007000/
├── 3A213694CA20E8B1940B                 cabecera (45.056 bytes, empieza por "LIVE")
└── 3A213694CA20E8B1940B.data/
    ├── Data0000 ... Data0046            47 fragmentos de ~170 MB (el último, ~68 MB)
```

- El nombre de la cabecera (16 hex) **debe coincidir** con el de la carpeta `.data`.
- Si faltan fragmentos, el port muestra *"Requires matching multipart BO2 GOD header and all data fragments"*.
- Alternativa válida: el archivo **`.iso`** de tu disco, colocado en lugar de `00007000`.

### `000B0000` — Title Update 18 (obligatorio, ~87 MB)

```text
000B0000/
└── tu0000000e_00000000
```

Detalles que confunden a todo el mundo:

- El nombre **no dice "TU18"**. El sufijo hex cambia según la región / Media ID del disco (TU8, por ejemplo, existe como `tu00000002`, `tu0000000e`, `tu00000012`…).
- El port **no se fía del nombre**: lee el paquete STFS, extrae el `default_mp.xexp` y compara su **SHA-256** con una lista de TU18 conocidos.
- Un TU de otra versión (aunque se llame parecido) **no sirve**.

Verificación: [03-extraer-y-verificar.md](03-extraer-y-verificar.md) o `tools/verificar_tu18.py`.

### `00000002` — DLC (opcional, ~7,9 GB)

Cada DLC es un paquete STFS con nombre tipo `303D76C31440625195B6B338D4F88241661B782E41` (40 hex + sufijo de 2).

En un pack completo de BO2 suelen venir: Season Pass / Nuketown 2025 / Nuketown Zombies / Revolution / Uprising / Vengeance / Apocalypse y packs de personalización.

- Sin DLC se puede jugar Zombies (mapas base: TranZit, Survival, Grief).
- Con DLC se añaden Mob of the Dead, Buried, Origins, Die Rise, Nuketown Zombies…
- El port admite hasta **32 paquetes DLC**.

## ¿De dónde salen estos archivos? (tu propia copia)

Ninguna de estas rutas implica descargar el juego de internet:

1. **Desde tu Xbox 360 con el juego comprado (GOD):** copia la carpeta `Content/0000000000000000/415608C3` de tu HDD/USB a la PC con **FATXplorer** (Windows) o desde **FSD/Aurora** por FTP, y luego pásala al teléfono.
2. **Desde tu disco físico (ISO):** ripea tu DVD de Xbox 360 a `.iso` (con tu consola) y usa el `.iso` en lugar de `00007000`.
3. **TU18:** descárgalo **desde tu consola** (FSD/Aurora lo bajan de la base de Xbox Unity) y copia el archivo de `000B0000`. Sirve el TU18 de cualquier región; el port comprueba el contenido, no el nombre.
4. **DLC:** desde tu cuenta/consola, o desde los paquetes que ya tengas comprados.

> Los packs que circulan en blogs ("DLC-TU-GOD" con guía de instalación para RGH) **no son una fuente legítima**. Si usas uno, al menos verifica el TU18 con el script antes de perder tiempo.

## Verificación rápida del árbol

```bash
ROOT="/storage/emulated/0/Games/BO2/415608C3"
ls "$ROOT"                                  # 00007000 000B0000 00000002 00009000
ls "$ROOT/00007000"/*.data | wc -l          # 47
ls "$ROOT/000B0000"                          # 1 archivo tu*
du -sh "$ROOT"                               # ~16G
```
