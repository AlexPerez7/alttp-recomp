# Plan de mejoras

Qué le falta al proyecto frente a los recompiladores y ports grandes de SNES (`zelda3` de snesrev, el port de Super Metroid...). Revisado contra `..\snes-recomp` el 2026-10-26.

Reparto (ver `CLAUDE.md`): lo general va al motor (`snes-recomp`, con OpenSpec); aquí solo lo específico de ALttP. Cada repositorio se commitea por separado.

## Ya existe (no hacer)

| Cosa | Dónde |
|---|---|
| Pantalla completa, VSync, aspecto, escalado entero/relleno, filtros `nearest`/`bilinear`/`sharp`, recorte, scanlines, rejilla, contador de fps | motor, pestaña **Image** |
| Remapeo de teclas y botones por jugador en un menú, mandos SDL con hotplug, 2 jugadores | motor, pestaña **Controls** |
| Volumen maestro y dispositivo de salida | motor, pestaña **Audio** |
| Avance rápido (2x a máx.) | motor, Tab / F2 |
| Pantalla ancha hasta 96 px por lado y relleno específico de ALttP | motor + `widefill.c` |
| Traducción al español de mensajes y menús, botones del jugador en los textos | `text.c`, `menutext.c`, `hud.c` |
| Opciones de juego propias, `rom_overlay`, ganchos `[[hook]]` en el perfil | motor + perfil |
| Save states (F5/F7, ranuras 1 a 9) y rebobinado (Retroceso) | motor, `[resume]` en el perfil |
| Captura PNG (F10), pruebas sin ventana (`--press`, `--poke`, `--dump`, trazas) | motor |
| Más de 200 pruebas y fuzz de 30 000 fotogramas | motor + `check.ps1` |

## Fase 1: lo que más se nota al jugar

1. **Save states y rebobinado** (motor). **Hecho** (cambio `savestates` de `snes-recomp`): perfil `[resume]` en `00:8034`, F5/F7/F3/F4 y Retroceso. Pendiente: pruebas automáticas de estado ajeno y de K pasos de rebobinado, comparar el audio, filas de menú. Hoy solo hay `.srm`. Hace falta serializar WRAM, VRAM, CGRAM, OAM, registros de la PPU, estado del SPC700/DSP, DMA/HDMA y el reloj. Teclas para guardar/cargar en varias ranuras y mantener una tecla para rebobinar (anillo de estados comprimidos por fotograma). Prueba: guardar, cargar y comparar el fotograma y el audio con `--no-window`.
2. **Shaders** (motor). Hay scanlines y rejilla, pero no CRT real, máscara de fósforo ni suavizado de borde. Valorar un paso opcional de OpenGL/D3D con shaders simples, manteniendo el camino por software como respaldo.
3. **Correcciones de bugs del original y calidad de vida** (aquí, `games/alttp_usa/*.c`), cada una como `[[option]]` activable:
   - cambio de objeto con L/R;
   - contador de rupias/llaves legible;
   - arreglos de bugs conocidos (los de `zelda3` sirven de guía; hay que comprobar cada dirección a mano contra la ROM);
   - ya hecho: mensajes rápidos (`dialog.c`).
4. **Volumen separado de música y efectos** (motor, y puede requerir saber qué voces del DSP son qué).

## Fase 2: ampliar el público

5. **Otras ROMs de ALttP** (aquí): EU, JP y la alemana. Mismo perfil con otras direcciones (`alttp_eu.toml`...); la traducción puede compartir `lang/`. Cada tabla de saltos se vuelve a comprobar a mano.
6. **CI** (ambos repos): GitHub Actions que compile, pase `cargo test` y `scripts\check.ps1` (se omite sola sin ROM) y vigile que `scan` termine sin error.
7. **Linux y macOS** (motor): el runtime ya usa SDL2 y gcc/clang; faltan rutas, el selector de ROM, la caché (`%LOCALAPPDATA%`) y los paquetes. Después Steam Deck.
8. **Instalador/paquete** más cómodo: ya existe `release.ps1`; añadir firma y una página de descargas cuando haya versión.

## Fase 3: confianza y herramientas

9. **Verificación contra un emulador de referencia** (motor): grabar entradas, ejecutar el mismo tramo en bsnes (o similar) y en el recompilado, y comparar fotogramas o WRAM cada N cuadros. Hoy el fuzz solo detecta paradas y *stubs*, no desvíos sutiles. Documentar las 2 funciones que quedan como *stub* (`01:CA17`, `08:A8E3`).
10. **Herramientas de depuración** (motor): visor interactivo de WRAM/VRAM/sprites y trazador, sobre lo que ya hay en `--dump` y `--watch`. Útil para encontrar direcciones al hacer mejoras.
11. **Precisión de tiempos**: el reloj es proporcional por bloques. Medir qué efectos del juego dependen de ciclos exactos (HDMA, ondas del Mundo Oscuro) y arreglar los que se noten.

## Fase 4: extras

12. **Audio mejorado**: pistas MSU-1 (u otro formato) opcionales, cargadas de una carpeta del usuario; ningún audio en el repositorio.
13. **60 fps o más** con interpolación, y modo 7 en alta resolución (motor; es el cambio más grande y arriesgado).
14. **Modding**: cargar C propio como plugin sin recompilar el juego, o un formato de parches de datos (ya existe la carpeta `game_dir()` editable sin reconstruir).
15. **Logros y netplay/cooperativo**: solo si hay demanda; requieren determinismo estricto, que depende de los puntos 1 y 9.

## Orden sugerido

(1 hecho) 3 → 5 → 6 → 9 → 2 → 7 → resto. Los puntos 1 y 9 desbloquean después logros y netplay.

## Notas

- Todo lo derivado de la ROM (volcados, capturas con gráficos, C generado) sigue fuera del repositorio.
- Cada punto del motor empieza con `/opsx:propose` en `snes-recomp`; aquí solo se registran los cambios del juego.
