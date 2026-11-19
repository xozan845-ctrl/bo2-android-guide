# 04 — Instalar la app y elegir la carpeta

## 1. Descargar el APK (solo oficial)

- Releases: https://github.com/spartansprm/BO2-Android-xbox360/releases
- Para ARM64 elige **`BO2-v0.63.2-armv8.0.apk`** (el `BO2-v0.63.2.apk` es un universal, también sirve).
- Paquete: `org.bo2port.diagnostic`

No lo bajes de blogs, grupos de Telegram o "páginas de APK": es donde meten malware.

## 2. Instalar

1. Abre el APK desde el administrador de archivos (o `termux-open BO2-v0.63.2-armv8.0.apk`).
2. Acepta **"Instalar apps desconocidas"** para la app con la que lo abres.
3. Instalar → Abrir.

Alternativa por ADB: `adb install -r BO2-v0.63.2-armv8.0.apk`.

## 3. Primera apertura: elegir la carpeta

La app abre el **lanzador** y pide la carpeta del juego. Usa el selector de Android (SAF) y navega a:

```text
/storage/emulated/0/Games/BO2/415608C3
```

Reglas:

- Debes seleccionar la carpeta que **contiene** `00007000` y `000B0000` (y, si tienes, `00000002`).
- **No** selecciones `Games`, ni `BO2`, ni `Download`, ni la raíz: el escáner dirá *"Esa carpeta no tiene el juego"*.
- Al confirmar, Android pide **"Permitir acceso a 415608C3"** → Permitir. Sin eso no puede leer ni escribir `bo2-saves`.
- Si la app dice *"la carpeta fue elegida sin permiso"*, repite la selección y acepta el diálogo.

## 4. Escaneo

El lanzador comprueba:

1. Cabecera GOD o `.iso` válida de Black Ops II (`415608C3`).
2. TU18 presente y con hash aceptado (*"Comprobando juego y TU18"*).
3. DLC encontrados (hasta 32).
4. Espacio y permisos.

Tarda unos segundos; en un pack de 16 GB puede tardar más por el I/O. Al terminar queda en `CONTENT_READY`.

## 5. Qué crea la app

| Ruta | Contenido |
|---|---|
| `415608C3/bo2-saves/` | Partidas guardadas (se conservan al reinstalar) |
| Almacenamiento privado de la app | shaders compilados, caché de pipelines, registros |

Notas:

- La app **no copia** los 16 GB: los lee de la carpeta elegida.
- Si desinstalas y reinstalas, al volver a elegir la misma carpeta recupera el progreso de `bo2-saves`.

## 6. Controles y mando

- Controles táctiles por defecto; hay editor y perfiles (`Ajustes → Controles`).
- Con un **mando Bluetooth/USB** conectado, los controles táctiles se ocultan solos.
- Durante el juego: desliza desde el **borde izquierdo** para abrir el menú (controles / salir).
