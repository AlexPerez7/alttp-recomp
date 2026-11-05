# Desarrollo

Volver al [README](../README.md). Aquí está lo que necesita quien quiere compilar, probar o empaquetar el proyecto; para jugar basta con las [releases](https://github.com/AlexPerez7/alttp-recomp/releases).

## Qué contiene

- `games/alttp_usa.toml`: identifica la ROM (CRC32 `777AAC2F`) y da al recompilador las entradas de código, las tablas de saltos (comprobadas a mano contra la ROM real) y los ganchos. Solo lleva direcciones, nombres y tamaños de tabla; ningún byte del juego.
- `games/alttp_usa/dialog.c`: C original que se compila junto al código generado. Acelera los mensajes.
- `games/alttp_usa/widefill.c`: con la pantalla ancha (`wide` en `config.ini` o `--opt wide=N`), tapa en negro las columnas extra donde no hay mapa cargado: pasado el borde del área en el exterior, y en las salas y cuevas, siempre.
- `games/alttp_usa/text.c`: vuelca los mensajes del juego a un fichero de texto y, con la opción `language`, los sustituye por los de `lang/es.txt`.
- `games/alttp_usa/menutext.c`: lo mismo para el texto fijo de la selección de partida y del registro de nombre, con `lang/es_menu.txt`.
- `scripts/check.ps1`: prueba que lo anterior funciona (necesita tu ROM).
- `scripts/release.ps1`: arma el paquete para repartir.

## Construir y ejecutar desde el código

### En Windows

```
snes-port.exe                                  # doble clic: el lanzador (eliges la ROM y juegas)
snes-port.exe roms\alttp_usa.sfc               # construye si hace falta y abre el juego
snes-port.exe roms\alttp_usa.sfc --no-launch   # solo construye
snes-port.exe clean roms\alttp_usa.sfc         # borra la caché de la ROM (si un cambio no se nota)
snes-port.exe roms\alttp_usa.sfc -- --game-opt dialog_skip=0   # opciones del juego
```

Este repositorio lleva el motor ya hecho en la raíz (`snes-port.exe`, `snes-recomp.exe`, `sdl2\`, `toolchain\` con TinyCC; licencia y README del motor como `LICENSE-engine` y `README-engine.md`), así que no hace falta clonar `snes-recomp` para jugar: **doble clic en `snes-port.exe`** abre la ventana del lanzador (reconoce el juego por `games\`), eliges tu ROM y juegas; con una ROM como argumento lo hace sin ventana. Para actualizar el motor: en `snes-recomp`, `powershell -File scripts\release.ps1`; aquí, `powershell -File scripts\update-engine.ps1`, y se sube como cualquier cambio.

### En Linux

**Desde el código:** los binarios de la raíz son de Windows; en Linux se compila el motor y se usa con el perfil de este repositorio:

```
sudo apt install build-essential pkg-config libsdl2-dev python3-pil   # compilador de C, SDL2 y Pillow (solo para check.sh)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh        # Rust, si no lo tienes
git clone https://github.com/AlexPerez7/snes-recomp ../snes-recomp
(cd ../snes-recomp && cargo build --release)
../snes-recomp/target/release/snes-port roms/alttp_usa.sfc --game games/alttp_usa.toml
```

La primera vez construye el juego con gcc (unos 3 minutos) y lo guarda en `~/.cache/snes-port`; las siguientes arranca al instante. Opciones del juego tras `--`, como en Windows. Las partidas y los estados van a `saves/` junto a `snes-port` (o a `~/.local/share/snes-port/saves` si ahí no se puede escribir). Hace falta un motor que sepa construir en Linux (con el arreglo del nombre del ejecutable y la detección de SDL2 del sistema).

### Con el motor

```
git clone https://github.com/AlexPerez7/snes-recomp
git clone https://github.com/AlexPerez7/alttp-recomp
cd snes-recomp
cargo run --release --bin snes-port -- ..\mi-carpeta\alttp_usa.sfc --game ..\alttp-recomp\games\alttp_usa.toml
```

Opciones del juego tras `--`, por ejemplo `-- --game-opt dialog_skip=0`.

## Comprobar y empaquetar

```
powershell -File scripts\check.ps1 -Rom ruta\a\alttp_usa.sfc      # genera, compila y ejecuta; ~3 min
cd ..\snes-recomp ; powershell -File scripts\release.ps1 ; cd ..\alttp-recomp
powershell -File scripts\release.ps1
```

En Linux, `scripts/check.sh [roms/alttp_usa.sfc] [ruta/a/snes-recomp]` hace lo mismo con gcc o clang (necesita Python 3 con Pillow y busca el motor en `../snes-recomp/target/release/`). `check.ps1` y `check.sh` se omiten con un aviso si falta la ROM, el motor o el compilador. `release.ps1` y `update-engine.ps1` son solo de Windows. `release.ps1` falla si el paquete llevara ROMs, partidas guardadas, estados guardados (`.sst`) o C generado.

## Limitaciones conocidas

- Los estados guardados no incluyen el fotograma en curso (se redibuja) ni variables estáticas del C propio; por ahora se guardan en un único punto del bucle principal (`[resume]` en `00:8034`).
- De las 4 178 funciones de la ROM, 2 (`01:CA17`, `08:A8E3`) se quedan como *stub* y no se ejecutan en el juego.
- La interpolación del DSP usa un núcleo en forma de campana, cercano a la gaussiana del hardware pero no su tabla exacta; la PPU no emula el entrelazado; los comportamientos que dependen de ciclos exactos no se reproducen.
