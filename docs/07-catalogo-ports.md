# 07 — Catálogo de ports nativos Android

El instalador es genérico: cada juego es un **manifiesto** en `tools/ports/<id>.json`. Añadir un port nuevo no requiere tocar el código.

```bash
python3 tools/port.py list          # catálogo
python3 tools/port.py info bo2      # requisitos y estructura
python3 tools/port.py install bo2   # instala APK + prepara/valida datos
```

Todos los ports de esta lista siguen la misma regla: **no incluyen datos del juego**. Necesitas tu propia copia (disco, ISO, ROM o instalación de PC).

## Verificados

| ID | Juego | Origen de tus datos | Repo | Estado |
|---|---|---|---|---|
| `bo2` | Call of Duty: Black Ops II (Zombies/Campaña) | Xbox 360 GOD o ISO + TU18 | [spartansprm/BO2-Android-xbox360](https://github.com/spartansprm/BO2-Android-xbox360) | **verificado de punta a punta** (16 GB, TU18 por hash) |

## En el catálogo (APK verificado contra su release; datos según el proyecto)

| ID | Juego | Origen | Repo | Release probado |
|---|---|---|---|---|
| `nfsmw` | Need for Speed: Most Wanted (2005) | Xbox 360 (tu copia PAL) | [codepdbh/nfsmw-android](https://github.com/codepdbh/nfsmw-android) | v0.8.2 · APK + SHA-256 ✔ |
| `nfsu1` | Need for Speed: Underground (2003) | PC original | [codepdbh/nfsu1-recompiled](https://github.com/codepdbh/nfsu1-recompiled) | v0.2.15 · APK ✔ |
| `fable2` | Fable II | Xbox 360 ISO/carpeta | [hardsilinder/FableDroid](https://github.com/hardsilinder/FableDroid) | v0.6.3-beta |
| `skate3` | Skate 3 | Xbox 360 | [darchap/Skate3-Port](https://github.com/darchap/Skate3-Port) | v1.3.3 |
| `gow2` | Gears of War 2 | Xbox 360 | [santiquiroz/gears-of-war-2-pc-port](https://github.com/santiquiroz/gears-of-war-2-pc-port) | v0.4.7 · APK + `.sha256` |
| `unleashed` | Sonic Unleashed (Unleashed Recompiled) | Xbox 360 | [SansNope/UnleashedRecomp-Android](https://github.com/SansNope/UnleashedRecomp-Android) | v0.6.1 |
| `d2` | Diablo II: Lord of Destruction 1.13d | PC (claves propias) | [N1v0k/D2Android-Releases](https://github.com/N1v0k/D2Android-Releases) | v1.6.2 |
| `opencrown` | Dragon's Crown (OpenCrown Mobile) | PS Vita/PS4 (dump propio) | [Nezara/OpenCrown-PC](https://github.com/Nezara/OpenCrown-PC) | v1.2 · APK móvil 1.9.4 ✔ |
| `pes6` | Pro Evolution Soccer 6 (PSP) | PSP ISO | [haveniiii/PES6ANDROIDPORT](https://github.com/haveniiii/PES6ANDROIDPORT) | v1.3.1-beta |

**"Sin probar"** significa: el instalador resuelve y descarga el APK correcto de ese release (y verifica el SHA-256 cuando el proyecto lo publica), pero no se ha validado el arranque del juego en un dispositivo de este repo. APKs descargados y comprobados hasta ahora: `bo2`, `nfsmw`, `nfsu1`, `gow2`, `opencrown`. Revisa el README del proyecto antes de reportar fallos aquí.

## Modos de datos (`data.mode`)

| Modo | Qué hace el instalador | Ejemplos |
|---|---|---|
| `folder` | Crea la carpeta destino, extrae archivos, valida la estructura y (si aplica) verifica el TU | `bo2`, `opencrown` |
| `iso` | Deja el `.iso` en la carpeta esperada y valida | — |
| `app-import` | Solo instala el APK; la app importa tu copia desde su menú | `nfsmw`, `nfsu1`, `fable2`, `skate3`, `gow2`, `unleashed`, `pes6` |
| `app-download` | La app descarga los instaladores **oficiales** y pide tus claves | `d2` |

## Añadir un port nuevo

1. Crea `tools/ports/<id>.json`:

```json
{
  "id": "miJuego",
  "name": "Mi Juego",
  "source": "Xbox 360 (tu disco)",
  "repo": "usuario/repo",
  "asset": "arm64",
  "asset_exclude": "armeabi",
  "arch": "arm64",
  "min_android": 10,
  "space_gb": 10,
  "verified": false,
  "data": {
    "mode": "app-import",
    "hint": "La app importa tu copia desde su menú.",
    "dest": "",
    "layout": [],
    "verify": null
  },
  "notes": "notas del proyecto"
}
```

2. Comprueba que resuelve bien:

```bash
python3 tools/port.py info miJuego
python3 tools/port.py install miJuego --solo-apk
```

3. Si el port necesita una estructura concreta (como BO2), rellena `layout` y `verify`:

```json
"layout": [
  { "path": "Juego/00007000", "type": "dir", "min_files": 40, "desc": "Datos del juego" },
  { "path": "Juego/000B0000", "type": "dir", "min_files": 1,  "desc": "Title Update" }
],
"verify": { "tool": "tu18", "path": "Juego/000B0000" }
```

4. Manda un PR con el manifiesto y, si puedes, el resultado real (`verified: true` + dispositivo).

## Verificación de integridad del APK

Si el release publica `SHA256SUMS.txt`, `*.sha256` o similar, el instalador lo descarga, busca la línea del APK y compara el hash. Salida esperada:

```text
  OK SHA-256 coincide con el release
```

Si no coincide, **aborta** (descarga corrupta o APK manipulado).

## Otras fuentes de ports (para explorar)

- DroidPorts — directorio de ports Android: https://droidports.com/
- GamePort (Xbox 360): https://gameport.games/systems/xbox360
- Awesome Android Native Ports: https://github.com/abduznik/awesome-android-native-ports
- ReXGlue SDK (motor de recompilación): https://github.com/ReXGlue/rexglue-sdk

## Nota legal

Todos los proyectos listados son recompilaciones o reimplementaciones que **exigen tu copia legítima**. Este repositorio no aloja, enlaza ni distribuye datos de juegos; el instalador solo automatiza descargar el APK público de cada proyecto y organizar **tus** archivos.
