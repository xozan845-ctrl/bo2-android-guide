# Black Ops II Zombies en Android — guía + automatización

Guía reproducible para instalar y configurar el **port nativo de Call of Duty: Black Ops II (Xbox 360) para Android ARM64**, con:

- un **script que hace todo solo** (busca los RAR, extrae, verifica y deja la carpeta lista),
- **verificación criptográfica del TU18** (lo que realmente exige el port),
- ajustes recomendados y solución de problemas.

Probado de punta a punta en un **Samsung Galaxy A56 5G** (Android 16, Exynos 1580, Xclipse 540) y verificable en cualquier ARM64 con Android 9+.

> **Aviso legal:** este repositorio **no contiene ni distribuye** datos del juego ni enlaces de descarga del mismo. Necesitas tu **propia copia** de Black Ops II de Xbox 360 y su TU18.

---

## Automático (recomendado)

```bash
pkg install git unrar python -y
git clone https://github.com/xozan845-ctrl/bo2-android-guide.git
cd bo2-android-guide
bash tools/setup_bo2.sh
```

El script:

1. **Busca** los `.part1.rar` / `.part2.rar` (o `.r01`, o un `.rar` único) en `Download`, `~/storage/downloads`, `/sdcard` y `/storage/emulated/0`.
2. Comprueba que estén las dos partes y que haya **espacio libre** suficiente.
3. **Extrae** con `unrar`, verificando CRC de todo el archivo (`All OK`).
4. **Localiza** la carpeta `415608C3` y valida la estructura (`00007000`, 47 fragmentos, `000B0000`).
5. **Verifica el TU18** por SHA-256 del `default_mp.xexp` contra los hashes que acepta el port.
6. Detecta el **APK** en Descargas y opcionalmente abre el instalador.
7. Te imprime la **ruta exacta** que debes elegir dentro de la app.

Opciones:

```bash
bash tools/setup_bo2.sh --help
bash tools/setup_bo2.sh --dest /sdcard/Games/BO2   # otra carpeta destino
bash tools/setup_bo2.sh --src /sdcard/Download     # buscar solo ahí
bash tools/setup_bo2.sh --force                    # re-extraer aunque ya exista
bash tools/setup_bo2.sh --no-apk                   # no ofrecer instalar el APK
bash tools/setup_bo2.sh --yes                      # sin preguntas
```

---

## Manual (resumen)

```text
1. Consigue TU copia de BO2 (GOD o ISO) + TU18 + DLC.
2. Copia a:  /storage/emulated/0/Games/BO2/415608C3/
3. Verifica: python3 tools/verificar_tu18.py <archivo_tu>
4. Instala el APK oficial del port.
5. En la app: Elegir carpeta del juego -> 415608C3.
6. Ajustes -> Original 880x720 + Preparar shaders -> Jugar -> Zombies.
```

Estructura esperada:

```text
/storage/emulated/0/Games/BO2/
└── 415608C3/                  <-- esta carpeta se elige en la app
    ├── 00007000/              JUEGO (obligatorio, ~7,4 GB)
    │   ├── 3A213694CA20E8B1940B          cabecera SVOD/GOD
    │   └── 3A213694CA20E8B1940B.data/    Data0000 ... Data0046
    ├── 000B0000/              TITLE UPDATE 18 (obligatorio, ~87 MB)
    ├── 00000002/              DLC (opcional, ~7,9 GB)
    └── 00009000/              contenido extra (opcional, ~7 MB)
```

---

## Documentación

| Documento | Contenido |
|---|---|
| [docs/01-requisitos.md](docs/01-requisitos.md) | Teléfono, Android, GPU y qué archivos hacen falta |
| [docs/02-archivos-del-juego.md](docs/02-archivos-del-juego.md) | Estructura del juego, TU18 y DLC (y de dónde salen legalmente) |
| [docs/03-extraer-y-verificar.md](docs/03-extraer-y-verificar.md) | RAR multi-volumen, CRC, verificación del TU18 |
| [docs/04-instalar-app.md](docs/04-instalar-app.md) | APK oficial, instalación y elección de carpeta |
| [docs/05-configuracion.md](docs/05-configuracion.md) | Ajustes recomendados y rendimiento por dispositivo |
| [docs/06-problemas.md](docs/06-problemas.md) | Errores típicos y solución |

## La app (oficial)

| Recurso | URL |
|---|---|
| Repositorio del port | https://github.com/spartansprm/BO2-Android-xbox360 |
| **APK (releases)** | https://github.com/spartansprm/BO2-Android-xbox360/releases |
| Proyecto base (Switch/Windows) | https://github.com/AlvaroEPena/bo2-360-nx |
| Discord de soporte | https://discord.gg/hdmde3Snr |

- Paquete: `org.bo2port.diagnostic` — versión documentada: **0.63.2**
- Requisitos: **ARM64**, CPU **ARMv8.2+**, **Vulkan 1.2**, Android 9+

Descarga el APK **solo de los releases oficiales**: en sitios de descargas y grupos de Telegram es donde inyectan malware.

---

## Hashes TU18 aceptados por el port

`default_mp.xexp`:

```text
5d5780970f6e639b17c0570bae0e52a13bd1038e23c969428aef9d0c7d78681b
7f4ee5e4b5ccfe71786ddc073a0363558e89634bb26c2929335aeb7f883c9499
```

Si tu TU no da ninguno de esos dos, **no es TU18** y el port se negará a arrancar: consigue otro.

## Licencia

- Documentación y scripts de instalación: **MIT** (ver `LICENSE`)
- `tools/verificar_tu18.py`: **GPL-3.0** (port del lector STFS de `StfsPatchVerifier` del proyecto BO2-Android-xbox360)
- Call of Duty / Black Ops II son marcas de Activision. Este repo no está afiliado a Activision, Microsoft ni Google.
