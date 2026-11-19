# 01 — Requisitos

## Del teléfono

| Requisito | Detalle |
|---|---|
| Arquitectura | **ARM64 (arm64-v8a)**. No funciona en x86 ni en 32 bits. |
| CPU | **ARMv8.2** o superior. Referencias que cumplen: Snapdragon 845+, Exynos 990+, Helio G90+, Dimensity, Tensor, Exynos 1580, etc. |
| Android | **9 o superior**. Probado en Android 16. |
| Gráfica | **Vulkan 1.2**; o Vulkan 1.1 con las extensiones `VK_EXT_descriptor_indexing`, `VK_EXT_scalar_block_layout`, `VK_KHR_uniform_buffer_standard_layout` y `VK_KHR_sampler_mirror_clamp_to_edge`. |
| RAM | 6 GB recomendado. 4 GB arranca, pero con más cierres por memoria. |
| Almacenamiento | **~17 GB libres** para los datos del juego + margen para caché/partidas. |
| Permisos | Acceso a archivos (SAF) para elegir la carpeta del juego; "instalar apps desconocidas" para el APK. |
| Extra | Se recomienda **disipador o funda ventilada** si vas a jugar sesiones largas; el port calienta. |

La propia app lo comprueba: **Ajustes → Biblioteca → Driver de GPU** te dice si tu GPU es compatible, y al arrancar hace una comprobación de CPU/GPU (`CpuCheck`, `GpuCheck`).

## Del juego

| Elemento | Obligatorio | Formato |
|---|---|---|
| Juego | Sí | Carpeta **GOD** (`00007000`) o tu **`.iso`** del disco |
| Title Update 18 | **Sí** | `000B0000/tuXXXXXXXX_00000000` |
| DLC / mapas | No | carpeta `00000002` |

Detalles y de dónde salen en [02-archivos-del-juego.md](02-archivos-del-juego.md).

## Del equipo (para extraer/verificar)

- **7-Zip**, **WinRAR** o **unrar** (para RAR multi-volumen).
- Opcional: **Python 3** para `tools/verificar_tu18.py`.
- Opcional: **FATXplorer** (Windows) si vas a copiar los datos desde el disco de una Xbox 360.

En el teléfono, todo esto se hace con Termux:

```bash
pkg install unrar python
```
