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
   - contador de rupias/llaves legible;
   - arreglos de bugs conocidos (los de `zelda3` sirven de guía; hay que comprobar cada dirección a mano contra la ROM);
   - ya hecho: hasta 9999 rupias con `rupees_9999=1` (`quality.c`: la cuenta se hace en C desde el gancho de entrada de `0D:DB75`, que deja a la rutina original valores iguales y limitados a 999; los cuatro dígitos se dibujan al final de `0D:FC09`; apagado por defecto; probado en `check.ps1`); cancelar el viaje en pájaro con B con `bird_cancel=1` (`quality.c`: gancho en `0A:B78B` y reemplazo en C de `02:EC39`, que con el viaje cancelado no recoloca a Link; la marca de cancelado va en el bit 7 de `$1AF0` para que un estado guardado en pleno viaje la conserve (comprobado a mano cargando el estado en otro proceso); apagado por defecto; probado en `check.ps1`; sin la opción la WRAM tras un viaje es idéntica a la del original); cambio de objeto con L/R con `item_switch_lr=1` (`quality.c`, desde el gancho de entrada de `0D:DB75`; apagado por defecto; probado en `check.ps1`); mensajes rápidos (`dialog.c`) pitido de poca vida desactivable con `low_hp_beep=0` (`quality.c`, gancho en `0D:DB75`; probado en `check.ps1`) y rupias, bombas y flechas máximas en amarillo con `max_yellow=1` (`quality.c`, gancho en `0D:FC09`; apagado por defecto) y girar mientras se corre con `dash_turn=1` (`quality.c`, gancho al entrar en el manejador del dash `07:8F86`; apagado por defecto; probado en `check.ps1`);
   - **pruebas** (hechas el 2026-10-27 en `check.ps1`, sección de `quality.c`, con una partida nueva hasta que Link se maneja en su casa, fotograma 5200, y con `--poke`, `--watch` y `--trace-frames`): `max_yellow` (999 rupias, bombas y flechas al máximo: paleta 1 apagado y 5 encendido; con 500 rupias solo cambian bombas y flechas), `low_hp_beep` (con un corazón el `$2B` se pide cada 32 fotogramas; con la opción en 1 dura un fotograma como siempre, en 0 se borra en el mismo fotograma; con la vida llena no hay ninguno; los demás efectos no cambian) y `dash_turn` (con `$F355=1` y `$F379=FF` se corre con A; pulsar arriba a media carrera sin la opción la corta, con ella `$2F` pasa a 0 y la carrera sigue hasta la pared). Lo que no se comprueba es el sonido real, solo la petición en `$012E`. Cada mejora nueva añade su prueba ahí. Las ocho partidas se lanzan en paralelo y `check.ps1` entero tarda unos 3 minutos (antes 10); se acortaría más con estados guardados del `headless` si el motor permite cargarlos pronto;
   - candidatos de `zelda3` (`zelda3.ini`) aún sin hacer: espejo al Mundo Oscuro, recoger con la espada, romper vasijas con la espada, más bombas activas.
4. **Volumen separado de música y efectos** (motor, y puede requerir saber qué voces del DSP son qué).

## Fase 2: ampliar el público

5. **Otras ROMs de ALttP** (aquí): EU, JP y la alemana. Mismo perfil con otras direcciones (`alttp_eu.toml`...); la traducción puede compartir `lang/`. Cada tabla de saltos se vuelve a comprobar a mano.
6. **CI** (ambos repos): GitHub Actions que compile, pase `cargo test` y `scripts\check.ps1` (se omite sola sin ROM) y vigile que `scan` termine sin error.
   - **Hecho aquí** (`.github/workflows/ci.yml`, sin ROM): nada derivado de la ROM en git, perfil TOML válido, cada `.c` en la lista de `check.ps1` y el C propio compila con gcc contra `snes_rt.h` del motor (con un `snes_funcs.h` de relleno). Falta ver que pase en GitHub la primera vez (no se ha subido) y, en `snes-recomp`, su propio CI (`cargo build`/`cargo test`). `check.ps1` y `scan` necesitan la ROM y siguen siendo locales.
7. **Linux y macOS** (motor): el runtime ya usa SDL2 y gcc/clang; faltan rutas, el selector de ROM, la caché (`%LOCALAPPDATA%`) y los paquetes. Después Steam Deck.
8. **Instalador/paquete** más cómodo: ya existe `release.ps1`; añadir firma y una página de descargas cuando haya versión.
8b. **Paquete para quien solo quiere jugar** (motor + aquí). Meta: descargar el zip, arrastrar la ROM sobre `snes-port.exe` o abrirlo con doble clic y elegirla en un selector, y jugar, sin instalar nada. Revisado el 2026-10-27 contra `..\snes-recomp`:
   - **Hecho en el motor (2026-10-27, cambio `launcher-window`)**: `snes-port.exe` abre con doble clic una ventana propia (sin consola) donde eliges la ROM, con **Jugar** y la ROM recordada las veces siguientes; muestra el estado de la construcción y los errores (con «Copiar detalle»); español o inglés según Windows; arrastrar la ROM sigue valiendo y solo muestra ventana si hay algo que decir; el paquete lleva TinyCC en `toolchain\tcc` y no pide descargar nada; desde terminal todo sigue como antes. Probado a mano con capturas y con el TinyCC del paquete simulando un equipo sin compilador (`SNES_PORT_NO_LOCAL_COMPILER=1`).
   - **Ya existía**: arrastrar la ROM; caché por CRC32 (la primera vez construye, las siguientes arranca al instante); sin compilador local ofrece descargar TinyCC 0.9.27 (480 KiB, SHA-256 fijado, solo con permiso; `--download-compiler` lo acepta de antemano); `release.ps1` arma el zip con SDL2 y sin ROM.
   - **Medido** (2026-10-27, i5-13420H): sin ventana TinyCC da 117 fps y MSVC 248; con ventana y audio TinyCC mantiene 60 fps con unos 8 ms libres por fotograma, con 1,2 % de fotogramas tardíos; un equipo con la mitad de potencia quedaría corto. clang portátil lo duplicaría pero pesa 80 MB (decisión provisional: TinyCC en el paquete, clang como opción si hace falta; ver `design.md` del motor).
   - **Falta**: probar el paquete completo en un Windows limpio (máquina virtual o equipo sin Visual Studio ni gcc, con y sin red), una partida con muchos sprites y un equipo más lento con TinyCC, y probar a mano `snes-port.exe` en `cmd` y PowerShell interactivos; valorar un segundo paquete con clang si el equipo va justo; firma de código (antivirus). Lo de motor, en `snes-recomp` (`openspec/changes/launcher-window`).

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
