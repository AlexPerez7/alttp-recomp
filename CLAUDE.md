# alttp-recomp

*The Legend of Zelda: A Link to the Past* (USA, CRC32 `777AAC2F`) recompilado con el motor [`snes-recomp`](https://github.com/AlexPerez7/snes-recomp) (repositorio hermano `..\snes-recomp` en esta máquina). Este repositorio es el **juego**: su perfil, el C propio que lo mejora y los scripts. El motor es una herramienta externa y compartida con otros juegos; aquí no se copia su código.

## Comandos

```
snes-port.exe                                  # doble clic: ventana del lanzador (eliges tu ROM y juegas, sin consola)
snes-port.exe roms\alttp_usa.sfc               # construye si hace falta y abre el juego (el perfil se encuentra solo por games\ junto al exe)
snes-port.exe roms\alttp_usa.sfc --no-launch   # solo construye
snes-port.exe clean roms\alttp_usa.sfc         # borra la caché de la ROM (si un cambio no se nota)
snes-port.exe roms\alttp_usa.sfc -- --game-opt dialog_skip=0   # opciones del C del juego tras --
powershell -File scripts\check.ps1        # genera, compila y ejecuta las pruebas con la ROM (~3 min: las partidas de las mejoras de calidad se juegan en paralelo); se omite si falta ROM, motor o Visual Studio
powershell -File scripts\release.ps1   # paquete (motor de la raíz; -Engine <zip> para otro) para repartir; falla si lleva ROM, .srm o C generado
```

### Linux

Los binarios de la raíz (`snes-port.exe`, `snes-recomp.exe`, `sdl2\`, `toolchain\`) son de Windows. En Linux se usa el motor compilado desde el repositorio hermano `../snes-recomp` (el perfil se pasa con `--game`, porque no hay `games/` junto al ejecutable del motor):

```
sudo apt install build-essential pkg-config libsdl2-dev python3-pil   # una vez; Rust con rustup
(cd ../snes-recomp && cargo build --release)                          # snes-port y snes-recomp en ../snes-recomp/target/release/
../snes-recomp/target/release/snes-port roms/alttp_usa.sfc --game games/alttp_usa.toml              # construye (gcc, unos 3 min la primera vez) y juega
../snes-recomp/target/release/snes-port roms/alttp_usa.sfc --game games/alttp_usa.toml --no-launch  # solo construye
../snes-recomp/target/release/snes-port clean roms/alttp_usa.sfc                                    # borra la caché (~/.cache/snes-port)
scripts/check.sh                                                      # el equivalente de check.ps1 (gcc/clang, Python 3 con Pillow); se omite si falta ROM, motor o compilador
scripts/release.sh [version]                                          # paquete .tar.gz de Linux autónomo (lanzador del motor, ../snes-recomp/linux/build.sh) en out/release/
scripts/bench.sh [-r REPS] [-f FOTOGRAMAS]                          # tiempo por fotograma con el runtime sin vídeo (base, mejoras apagadas, language=es, --wide 96) frente a 16 639 us; escribe out/bench/summary.txt
scripts/bench_play.sh [-t SEGUNDOS] [-d dummy|x11]                    # frontal interactivo con --stats por configuración de imagen (~11 min); con -d dummy es una cota de CPU, no la ventana real
```

`check.sh` busca el motor en su 2º argumento, `$SNES_ENGINE`, `./snes-recomp` o `../snes-recomp/target/release/snes-recomp`; la lógica de datos está en `scripts/check_eval.py`. Al añadir un fichero C nuevo hay que añadirlo a la lista de `check.sh` además de a la de `check.ps1`. `release.ps1` y `update-engine.ps1` siguen siendo solo de Windows (empaquetan el motor de Windows). Las partidas y los estados van a `saves/` junto a `snes-port` (aquí `../snes-recomp/target/release/saves/`), o a `~/.local/share/snes-port/saves` si ahí no se puede escribir.

El motor va **en este repositorio**, en la raíz (`snes-port.exe`, `snes-recomp.exe`, `sdl2\`, `toolchain\` con TinyCC, `LICENSE-engine`, `README-engine.md`): el juego no depende del repositorio del motor para jugarse. `check.ps1` y `release.ps1` lo usan; doble clic en `snes-port.exe` abre el lanzador. Para actualizarlo: en `snes-recomp`, `powershell -File scripts\release.ps1`; aquí, `powershell -File scripts\update-engine.ps1`, scan, commit y push. El zip debe ser del motor actual: uno viejo falla al enlazar si el C del juego usa funciones nuevas de `snes_rt.h`.

## Estados guardados

El perfil declara `[resume]` en `00:8034` (la espera del NMI del bucle principal, dentro de la función de reset, con `S = $01FF`). El motor guarda y carga ahí: F5 guarda, F7 carga, F3/F4 cambian de ranura, Retroceso rebobina. En la intro y la pantalla de título no se puede (el juego cambia de pila entre NMI e IRQ); en la partida sí. Si algún C de este repositorio guarda estado propio en variables estáticas, hay que poder recuperarlo desde la WRAM.

Las partidas (`.srm`) y los estados (`.sst`) van a `saves\` junto a `snes-port.exe` (carpeta por instalación; `%APPDATA%\snes-port\saves` si ahí no se puede escribir). Está en `.gitignore`.

## Estructura

- `games/alttp_usa.toml`: perfil (entradas, tablas de saltos, ganchos `[[hook]]`). Solo direcciones, nombres y tamaños; ningún byte del juego.
- `games/alttp_usa/*.c`: C propio (`dialog.c` mensajes rápidos con R; `widefill.c` franjas negras en la pantalla ancha; `text.c` volcado y traducción de los mensajes con `lang/es.txt`; `menutext.c` lo mismo para la selección de partida, el registro de nombre y las acciones del menú de pausa con `lang/es_menu.txt`; `hud.c` el rótulo «LIFE» del marcador, que con `language=es` dice «VIDA»); `icon.c` el icono de la ventana del juego, que `scripts\make_icon.py` (Pillow, arte propio) escribe. Usa la API de `snes_rt.h` del motor (`wram_read8/wram_write8`, `game_opt()`, `ppu_wide()`, `ppu_wide_blank()`...). Cada fichero nuevo hay que añadirlo también a la lista de `check.ps1`.
- `scripts/`: `check.ps1` (Windows), `check.sh` + `check_eval.py` (Linux), `bench.sh` y `bench_play.sh` (rendimiento, Linux), `release.ps1`, `update-engine.ps1`, `make_icon.py`.

## Reglas

- `games/alttp_usa/lang/es.txt` y `es_menu.txt` son la traducción al español, texto propio que SÍ se sube: nunca una copia del volcado `alttp_messages_*.txt` (eso deriva de la ROM). UTF-8. Letras y signos: A-Z, a-z, 0-9, espacio, `! ? . , '`, más `á é í ó ú ñ ¿ ¡` (`text.c` los dibuja en la fuente al vuelo con `rom_overlay`; las mayúsculas acentuadas y `ü` salen sin marca), cada línea de 168 píxeles como mucho (la suma de las anchuras de la tabla de la fuente, no el número de letras: el motor del juego corta lo que pasa de ahí). Los códigos de botón `{5B}` A, `{5C}` B, `{5D}` X y `{5E}` Y se sustituyen al cargar el mensaje por la tecla o el botón del mando que el jugador usa de verdad (`input_label` del motor). `es_menu.txt` sigue siendo solo A-Z, espacio y `?`.
- Nunca la ROM ni nada derivado (C generado, volcados, capturas con gráficos): `roms/`, `out/`, `*.sfc`, `*.smc`, `*.srm`, `*.sst` (estados guardados) están en `.gitignore`. Antes de cada push, el escaneo debe terminar sin error sobre lo que se sube: `.\snes-recomp.exe scan roms\alttp_usa.sfc <dir>` con `<dir>` una exportación del commit (`git archive HEAD | tar -x -C <dir>`, con `<dir>` fuera del repositorio o en una carpeta vacía). Sobre `.` falla siempre, porque encuentra la propia ROM de `roms\`, que no se sube.
- El C es original (clean-room). Las direcciones y tablas de saltos se comprueban a mano contra la ROM real.
- Lo que sea del traductor, la PPU, el sonido, el menú o el runtime va en `snes-recomp` (allí está OpenSpec); aquí solo lo específico de este juego. Si una mejora necesita una función nueva del motor, se añade allí de forma general y se usa desde el C de aquí. Cada repositorio se commitea y se sube por separado.
- Documentación y mensajes de commit en español.
