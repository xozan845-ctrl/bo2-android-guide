# 07 — Catálogo de ports nativos Android

El instalador es genérico: cada juego es un **manifiesto** en `tools/ports/<id>.json`. Añadir un port no requiere tocar código.

```bash
python3 tools/port.py list              # catálogo
python3 tools/port.py info gta4         # requisitos, verificación y estructura
python3 tools/port.py install gta4      # descarga APK + verifica + instala
python3 tools/port.py nuevo URL_DEL_REPO   # genera un manifiesto nuevo
```

Todos los ports siguen la misma regla: **no incluyen datos del juego**. Necesitas tu propia copia (disco, ISO, ROM o instalación de PC).

## Niveles de verificación

| Nivel | Qué significa |
|---|---|
| `apk` | APK descargado del release oficial, SHA-256 comprobado cuando el proyecto lo publica, integridad ZIP y metadatos (`package`, `minSdk`, ABI) inspeccionados. **No** implica que el juego arranque. |
| `datos` | Además, los datos del juego se extrajeron/validaron en el dispositivo (p. ej. TU18 de BO2 por SHA-256). |
| `jugado` | Se arrancó y se jugó en un dispositivo concreto. |

Ningún port está en nivel `jugado` todavía: este catálogo se mantiene desde un solo teléfono y sin datos de la mayoría de los juegos.

## Dispositivo de verificación

Todas las pruebas de esta sección se hicieron en:

```text
Samsung Galaxy A56 5G (SM-A566E)
Android 16 · Exynos 1580 (s5e8855) · GPU Xclipse 540 (RDNA, Vulkan 1.3)
arm64-v8a · 8 GB RAM · /storage/emulated/0
```

Es una GPU **Mali/Xclipse**, no Adreno: los ports que recomiendan Turnip pueden comportarse distinto aquí.

## Verificados (APK)

| ID | Juego | Release | Paquete | minSdk | Nivel |
|---|---|---|---|---|---|
| `bo2` | Black Ops II | V0.64.0 | `org.bo2port.diagnostic.scenesync` | 28 | `datos` |
| `nfsmw` | NFS Most Wanted (2005) | v0.8.2 | `com.nfsmw.android` | 26 | `apk` |
| `gow2` | Gears of War 2 | v0.4.7 | `com.santiquiroz.gow2recomp` | 29 | `apk` |
| `opencrown` | Dragon's Crown | v1.2 (APK 1.9.4) | `org.opencrown.mobile` | 28 | `apk` |
| `re4wii` | Resident Evil 4 (Wii) | v1.1 | `com.shiinobu.re4` | 29 | `apk` |
| `fifastreet12` | FIFA Street (2012) | 0.1.0 | `com.fifastreet.recomp` | 26 | `apk` |
| `codbo1` | Black Ops Zombies (T5-Jool) | alpha-v0.5 | `com.joolace.t5jool` | 29 | `apk` |
| `gta4` | GTA IV Liberty Recompiled (MidRange) | v0.5.8 | `com.libertyrecomp` | 29 | `apk` |
| `mw2` | Modern Warfare 2 | v0.1.1 | `com.mw2.recomp` | 26 | `apk` |
| `mw3` | Modern Warfare 3 | v0.1.1 | `com.mw3.recomp` | 26 | `apk` |

Los SHA-256 exactos están en cada manifiesto (`verification.sha256`).

## Catálogo completo (18)

| ID | Juego | Origen de tus datos | Estado |
|---|---|---|---|
| `bo2` | CoD Black Ops II | Xbox 360 GOD/ISO + TU18 | datos |
| `codbo1` | CoD Black Ops Zombies | tu copia (APK+OBB/ISO) | apk |
| `mw2` | CoD Modern Warfare 2 | Xbox 360 | apk |
| `mw3` | CoD Modern Warfare 3 | Xbox 360 | apk |
| `gta4` | GTA IV Liberty Recompiled | Xbox 360 | apk |
| `gta5` | GTA V (port no oficial) | PC/Xbox 360 | sin verificar |
| `re4wii` | Resident Evil 4 (Wii) | ISO RB4E08 | apk |
| `re4cube` | Resident Evil 4 (GameCube) | ISO GameCube | sin verificar |
| `fifastreet12` | FIFA Street (2012) | Xbox 360 | apk |
| `nfsmw` | NFS Most Wanted | Xbox 360 | apk |
| `nfsu1` | NFS Underground | PC | sin verificar |
| `fable2` | Fable II | Xbox 360 | sin verificar |
| `skate3` | Skate 3 | Xbox 360 | sin verificar |
| `gow2` | Gears of War 2 | Xbox 360 | apk |
| `unleashed` | Sonic Unleashed | Xbox 360 | sin verificar |
| `d2` | Diablo II LoD | PC (claves propias) | sin verificar |
| `opencrown` | Dragon's Crown | PS Vita/PS4 | apk |
| `pes6` | PES 6 | PSP ISO | sin verificar |

## Cobertura por saga

### Grand Theft Auto

| Juego | Port nativo Android | Estado |
|---|---|---|
| GTA IV | `gta4` (LibertyRecomp, variante Mali gama media) | APK verificado |
| GTA V | `gta5` (port no oficial de la comunidad, 287 MB) | sin verificar; proyecto sin documentación |
| GTA Liberty City Stories (PSP) | [codepdbh/PSPRecomp-LCS-Android](https://github.com/codepdbh/PSPRecomp-LCS-Android) | **solo código**: no publica APK |
| GTA III / Vice City | re3 / reVC no publican APK Android listo | hay que compilar |
| GTA San Andreas / Chinatown Wars | ports **oficiales** de Rockstar (no aplica este instalador) | — |

### Resident Evil

| Juego | Port nativo Android | Estado |
|---|---|---|
| RE4 (Wii) | `re4wii` (recompilación estática RB4E08) | APK verificado |
| RE4 (GameCube) | `re4cube` (CubeEvil4 modificado) | sin verificar |
| RE5 | [luisxl15/Resident-Evil-5-Android-PORT](https://github.com/luisxl15/Resident-Evil-5-Android-PORT) | **solo código**: sin release |
| RE1 / RE2 / RE3 originales | no existe port nativo Android; usa emulador | — |
| Remakes (RE2/3/4 remake) | no hay port nativo Android | — |

### Call of Duty

| Juego | Port nativo Android | Estado |
|---|---|---|
| Black Ops II | `bo2` | datos + APK |
| Black Ops Zombies | `codbo1` (T5-Jool) | APK verificado |
| Modern Warfare 2 | `mw2` | APK verificado |
| Modern Warfare 3 | `mw3` | APK verificado |
| MW1 / Black Ops 1 / Ghosts / AW | no hay port nativo con APK | — |

### FIFA

| Juego | Port nativo Android | Estado |
|---|---|---|
| FIFA Street (2012) | `fifastreet12` | APK verificado |
| FIFA 09 | [ChunchunQ/fifa09-recomp](https://github.com/ChunchunQ/fifa09-recomp) | **solo Windows** |
| Mundial 2010 / 2014 | recompilaciones **solo Windows** | — |
| FIFA 10–23 | no existe port nativo Android; los juegos oficiales de EA están descontinuados | — |

## Verificar o promover un port

```bash
# descarga el APK del último release, comprueba hash/metadatos y marca el manifiesto
python3 tools/port.py probar gta4

# con texto propio de dispositivo (por defecto se autodetecta)
python3 tools/port.py probar re4wii --dispositivo "Pixel 8 · Android 15 · Tensor G3"
```

Si además pruebas el juego con tus datos, sube el nivel a `datos`/`jugado` editando `verification.level` y añadiendo una nota con FPS y ajustes.

## Lanzar un juego instalado

```bash
python3 tools/port.py lanzar re4wii
```

Comprueba que el paquete esté instalado y lo abre (`monkey`/`am start`). Si el port está en modo `folder`, recuerda qué carpeta de datos debe elegir la app.

## Crear un manifiesto desde un repo

```bash
python3 tools/port.py nuevo https://github.com/usuario/repo
python3 tools/port.py nuevo https://github.com/usuario/repo --nombre "Mi Juego" --modo folder --datos /sdcard/Games/MiJuego
python3 tools/port.py nuevo https://github.com/usuario/repo --probar --id miport
```

El comando:

1. consulta el repo y su último release,
2. elige el APK (prefiere `arm64`/`armv8`, descarta fuentes y checksums),
3. crea `tools/ports/<id>.json` con valores razonables,
4. con `--probar`, descarga el APK, extrae `package`/`minSdk`/ABI y rellena `verification`.

Después revisa el manifiesto (`info`) y, si el port necesita una estructura concreta, añade `data.layout` y un `verify` (como BO2).

## Esquema del manifiesto

```json
{
  "id": "bo2",
  "name": "Call of Duty: Black Ops II",
  "source": "Xbox 360 (GOD o ISO)",
  "repo": "spartansprm/BO2-Android-xbox360",
  "asset": "armv8",                 // subcadena para elegir el APK
  "asset_exclude": "armeabi",       // subcadena a evitar
  "arch": "arm64",
  "min_android": 9,
  "space_gb": 18,
  "data": {
    "mode": "folder",               // folder | iso | app-import | app-download
    "hint": "texto para el usuario",
    "dest": "/storage/emulated/0/Games/BO2",
    "layout": [
      { "path": "415608C3/00007000", "type": "dir", "min_files": 40, "desc": "Juego" },
      { "path": "415608C3/000B0000", "type": "dir", "min_files": 1, "desc": "TU18" }
    ],
    "verify": { "tool": "tu18", "path": "415608C3/000B0000" }
  },
  "notes": "notas del proyecto",
  "verification": {
    "level": "apk",
    "device": "Samsung Galaxy A56 5G (SM-A566E) · Android 16 · Exynos 1580",
    "date": "2026-11-22",
    "apk": "BO2-v0.64.0-armv8.0.apk",
    "sha256": "…",
    "package": "org.bo2port.diagnostic.scenesync",
    "min_sdk": 28
  }
}
```

## Verificación de integridad del APK

Si el release publica `SHA256SUMS.txt` o `*.sha256`, el instalador lo descarga, busca la línea del APK y compara:

```text
  OK SHA-256 coincide con el release
```

Si no coincide, **aborta**.

## Otras fuentes para explorar

- DroidPorts: https://droidports.com/
- GamePort (Xbox 360): https://gameport.games/systems/xbox360
- Awesome Android Native Ports: https://github.com/abduznik/awesome-android-native-ports
- ReXGlue SDK: https://github.com/ReXGlue/rexglue-sdk

## Nota legal

Todos los proyectos listados son recompilaciones o reimplementaciones que **exigen tu copia legítima**. Este repositorio no aloja, enlaza ni distribuye datos de juegos.
