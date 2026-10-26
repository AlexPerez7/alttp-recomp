# alttp-recomp

*The Legend of Zelda: A Link to the Past* (USA, CRC32 `777AAC2F`) recompilado con el motor [`snes-recomp`](https://github.com/AlexPerez7/snes-recomp) (repositorio hermano `..\snes-recomp` en esta máquina). Este repositorio es el **juego**: su perfil, el C propio que lo mejora y los scripts. El motor es una herramienta externa y compartida con otros juegos; aquí no se copia su código.

## Comandos

```
play.bat                  # construye si hace falta y abre el juego (ROM en roms\alttp_usa.sfc)
play.bat -Rebuild         # borra la caché de la ROM y reconstruye (si un cambio no se nota)
play.bat -NoLaunch        # solo construye
play.bat -- --game-opt dialog_skip=0      # opciones del C del juego tras --
powershell -File scripts\check.ps1        # genera, compila y ejecuta las pruebas con la ROM (~1 min); se omite si falta ROM, motor o Visual Studio
powershell -File scripts\release.ps1 -Engine <zip del motor>   # paquete para repartir; falla si lleva ROM, .srm o C generado
```

`scripts\play.ps1` busca `snes-port.exe` en `$env:SNES_ENGINE`, en `engine\` (ignorado por git) o, si no hay, extrae a `engine\` el zip más reciente de `..\snes-recomp\out\release\` (o el de `-EngineZip`). Para actualizar el motor: en `snes-recomp`, `powershell -File scripts\release.ps1`; aquí, borrar `engine\` y ejecutar `play.bat`. El zip debe ser del motor actual: uno viejo falla al enlazar si el C del juego usa funciones nuevas de `snes_rt.h`.

## Estructura

- `games/alttp_usa.toml`: perfil (entradas, tablas de saltos, ganchos `[[hook]]`). Solo direcciones, nombres y tamaños; ningún byte del juego.
- `games/alttp_usa/*.c`: C propio (`dialog.c` mensajes rápidos con R; `widefill.c` franjas negras en la pantalla ancha; `text.c` volcado y traducción de los mensajes con `lang/es.txt`; `menutext.c` lo mismo para la selección de partida y el registro de nombre con `lang/es_menu.txt`). Usa la API de `snes_rt.h` del motor (`wram_read8/wram_write8`, `game_opt()`, `ppu_wide()`, `ppu_wide_blank()`...). Cada fichero nuevo hay que añadirlo también a la lista de `check.ps1`.
- `scripts/`: `play.ps1`, `check.ps1`, `release.ps1`.

## Reglas

- `games/alttp_usa/lang/es.txt` y `es_menu.txt` son la traducción al español, texto propio que SÍ se sube: nunca una copia del volcado `alttp_messages_*.txt` (eso deriva de la ROM). UTF-8. Letras y signos: A-Z, a-z, 0-9, espacio, `! ? . , '`, más `á é í ó ú ñ ¿ ¡` (`text.c` los dibuja en la fuente al vuelo con `rom_overlay`; las mayúsculas acentuadas y `ü` salen sin marca), líneas de 32 letras como mucho. `es_menu.txt` sigue siendo solo A-Z, espacio y `?`.
- Nunca la ROM ni nada derivado (C generado, volcados, capturas con gráficos): `roms/`, `out/`, `engine/`, `*.sfc`, `*.smc`, `*.srm` están en `.gitignore`. Antes de cada push: `..\snes-recomp\target\release\snes-recomp.exe scan roms\alttp_usa.sfc .` debe terminar sin error.
- El C es original (clean-room). Las direcciones y tablas de saltos se comprueban a mano contra la ROM real.
- Lo que sea del traductor, la PPU, el sonido, el menú o el runtime va en `snes-recomp` (allí está OpenSpec); aquí solo lo específico de este juego. Si una mejora necesita una función nueva del motor, se añade allí de forma general y se usa desde el C de aquí. Cada repositorio se commitea y se sube por separado.
- Documentación y mensajes de commit en español.
