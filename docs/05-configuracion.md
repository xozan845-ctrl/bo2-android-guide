# 05 — Configuración recomendada

Los ajustes del lanzador se aplican la **próxima vez** que pulsas Jugar.

## Imagen

| Ajuste | Recomendado para empezar | Por qué |
|---|---|---|
| **Resolución** | **Original 880×720** | Es la nativa de Xbox 360. Full HD cuesta ≈3,3× más que Original. |
| **Tipo de pantalla** | Pantalla completa (sin deformar) | En pantallas 20:9 evita barras; "Original" deja 16:9 con barras. |
| **Nitidez** | Máxima | Compensa la resolución baja. |
| **Calidad del escenario** | Baja o Media | La mayor palanca de FPS. "Alta" = como Xbox 360, solo en gama alta. |
| **Filtrado anisotrópico** | El del juego (2×–4×) | Subirlo apenas se nota y cuesta. |
| **Memoria para texturas** (experimental) | 768 MB (1 GB si tienes 8 GB+) | Reduce caídas bruscas de FPS. |
| **Preparar shaders antes de jugar** | **Activado** | Evita tirones; la primera vez en cada mapa espera unos segundos. |

## Biblioteca

- **Driver de GPU** (solo Adreno/Snapdragon): carga **Mesa Turnip** o un driver Qualcomm más nuevo en ZIP, como en los emuladores. Úsalo solo si ves pantalla negra, geometría sin dibujar o cuelgues del driver. Si falla, el juego vuelve solo al driver del sistema.
- **Biblioteca de shaders**: importa shaders ya compilados para quitar los tirones iniciales (útil si juegas el mismo mapa varias veces).
- **Guardar registro de la última partida**: genera un ZIP con log + datos de GPU para pedir soporte en el Discord.
- **Partidas guardadas**: copia/restaura el progreso a `415608C3/bo2-saves` (sobrevive a reinstalar).

## Ajustes en el juego (Zombies)

- Empieza en **TranZit / Survival** para calibrar FPS antes de mapas grandes (Origins es el más pesado).
- Baja **sombras** y **calidad de modelos** dentro del menú del juego si tienes caídas.
- Luces dinámicas: el port las desactiva siempre (fogonazos sin iluminación propia) porque en algunas GPU cerraban el juego.

## Rendimiento observado

| Dispositivo | GPU | Resultado |
|---|---|---|
| Galaxy A54 | Mali-G68 | ~45 FPS a 880×720 con ajustes bajos; ~20–25 FPS en Full HD/Alta |
| POCO X7 Pro | Mali-G720 | 60 FPS con todo al máximo |
| **Galaxy A56 5G** | Xclipse 540 | _pendiente de completar en este repo_ |
| iPhone (referencia, no Android) | — | el port no aplica |

Regla general: en gama media, **880×720 + Nitidez Máxima + escenario Bajo/Medio** es lo que mejor se ve/rinde.

## Batería y térmica

- El port mantiene la CPU a tope: espera consumo alto y calor.
- Evita jugar cargando; si el teléfono hace throttling, notarás caída de FPS sostenida.
- Límite de FPS en el juego (30/60) ayuda a la batería.

## Perfiles de control sugeridos

1. **Zombies – 4 dedos**: joystick izquierdo, mirar con el pulgar derecho, disparar/apuntar arriba a la derecha, recargar/interactuar accesibles.
2. Activa **CORRER automático** para no pelear con el joystick.
3. Si usas mando, oculta los controles táctiles (se hace solo) y sube la sensibilidad del stick derecho.
