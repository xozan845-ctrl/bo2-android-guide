# 06 — Problemas y soluciones

## El escáner dice que no es TU18

Mensajes: *"NO_TU18: no Black Ops II title update (TU18) found"*, *"The Black Ops II TU18 update is missing"*.

- Ejecuta `tools/verificar_tu18.py` sobre el archivo de `000B0000`.
- Si el hash no es ninguno de los dos aceptados, ese TU no sirve → consigue el TU18 de tu región/consola.
- El nombre (`tu0000000e`, `tu00000012`) **no** determina si es TU18.

## "Esa carpeta no tiene el juego"

- Debes elegir la carpeta `415608C3`, no `BO2` ni `Games`.
- Comprueba: `ls .../415608C3` → `00007000 000B0000 ...`
- Si usas `.iso`, el `.iso` y `000B0000` deben estar **en la misma carpeta**.

## "Requires matching multipart BO2 GOD header and all data fragments"

- Falta la cabecera o fragmentos `Data00XX`. Cuenta: `ls 00007000/*.data | wc -l` → **47**.
- El nombre de la cabecera debe coincidir con el de la carpeta `.data`.
- Vuelve a extraer el RAR completo (sin interrumpir).

## "The GOD header's matching .data directory is missing"

La carpeta `.data` no está junto a la cabecera. Estructura correcta:

```text
00007000/3A213694CA20E8B1940B
00007000/3A213694CA20E8B1940B.data/Data0000 ...
```

## "Esa carpeta fue elegida sin permiso"

El SAF no concedió permiso persistente. Repite: Elegir carpeta → seleccionar `415608C3` → **"Usar esta carpeta"** → **Permitir**. Si sigue: Ajustes de Android → Apps → BO2 → Permisos → Archivos y multimedia → Permitir.

## Pantalla negra, triángulos, texturas rojas o cierre al entrar a un mapa

- Casi siempre es **driver de GPU**. En `Ajustes → Biblioteca → Driver de GPU`, carga **Mesa Turnip** (Adreno) como ZIP.
- Baja resolución a 880×720 y calidad a Baja.
- Borra caché de shaders de la app y vuelve a entrar.

## Tirones al entrar a cada mapa

Normal la primera vez: se compilan pipelines de Vulkan y se guardan en caché. Activa **"Preparar shaders antes de jugar"** o importa una **biblioteca de shaders**.

## El juego no arranca / pantalla en negro con sonido

- Comprueba `Ajustes → Biblioteca → Driver de GPU`: debe decir compatible.
- Verifica que el teléfono sea **ARMv8.2+** (los SoC muy antiguos no pasan el `CpuCheck`).
- Cierra apps en segundo plano (mínimo 4 GB libres de RAM ayudan).

## Error de espacio al extraer

`unrar` necesita los 16 GB completos. Libera espacio (`df -h /storage/emulated/0`) y repite con `-o+`.

## "CRC failed" al extraer

El RAR está corrupto o incompleto → vuelve a descargar **la parte que falla** (`part1` o `part2`). No mezcles partes de sets distintos.

## La app se cierra al volver de segundo plano

Limitación de memoria de Android. Evita cambiar de app en partida; si pasa, reinicia el juego.

## DLC no aparecen

- Deben estar en `415608C3/00000002`.
- Máximo 32 paquetes.
- Los DLC de otra región a veces no cargan; usa los de tu copia.

## ¿Se puede jugar online?

El port recompila el ejecutivo de Xbox 360; **no hay online oficial**. Multijugador local/system link y bots según el modo. No esperes matchmaking de Xbox Live.

## Cómo pedir ayuda

1. `Ajustes → Biblioteca → Guardar registro de la última partida` → genera un ZIP.
2. Adjúntalo en el Discord del port: https://discord.gg/hdmde3Snr
3. Incluye modelo de teléfono, GPU, versión del port y si usaste driver propio.
