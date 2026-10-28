# alttp-recomp

*The Legend of Zelda: A Link to the Past* (USA) recompilado a código nativo con el motor [`snes-recomp`](https://github.com/AlexPerez7/snes-recomp). Este repositorio es el **juego**: su perfil (`games/alttp_usa.toml`), el C propio que lo mejora (`games/alttp_usa/`) y los scripts para comprobarlo y empaquetarlo. El recompilador, el runtime y `snes-port` están en el motor.

> **Aviso legal.** Este repositorio no contiene la ROM ni ningún recurso del juego (gráficos, sonido, texto, mapas), y no lo tendrá. Cada persona debe aportar su propia copia obtenida legalmente. El programa se construye en tu máquina a partir de **tu** ROM y nada derivado de ella se distribuye. Proyecto independiente y sin relación con Nintendo.

Licencia: [MIT](LICENSE), solo para el código de este repositorio; no da derechos sobre el juego.

## Qué contiene

- `games/alttp_usa.toml`: identifica la ROM (CRC32 `777AAC2F`) y da al recompilador las entradas de código, las tablas de saltos (comprobadas a mano contra la ROM real) y los ganchos. Solo lleva direcciones, nombres y tamaños de tabla; ningún byte del juego.
- `games/alttp_usa/dialog.c`: C original que se compila junto al código generado. Acelera los mensajes.
- `games/alttp_usa/widefill.c`: con la pantalla ancha (`wide` en `config.ini` o `--opt wide=N`), tapa en negro las columnas extra donde no hay mapa cargado: pasado el borde del área en el exterior, y en las salas y cuevas, siempre.
- `games/alttp_usa/text.c`: vuelca los mensajes del juego a un fichero de texto y, con la opción `language`, los sustituye por los de `lang/es.txt`.
- `games/alttp_usa/menutext.c`: lo mismo para el texto fijo de la selección de partida y del registro de nombre, con `lang/es_menu.txt`.
- `scripts/check.ps1`: prueba que lo anterior funciona (necesita tu ROM).
- `scripts/release.ps1`: arma el paquete para repartir.

## Mejoras sobre el juego original

| Mejora | Cómo se usa |
|---|---|
| Pantalla ancha sin basura | Con `wide` mayor que 0 el borde del mapa y el interior de salas y cuevas se ven en negro en lugar de repetir el lado contrario del mapa. |
| Estados guardados y rebobinado | **F5** guarda, **F7** carga, **F3**/**F4** cambian de ranura (1 a 9) y mantener **Retroceso** rebobina unos 10 s. Solo en la partida: en la intro y la pantalla de título el juego cambia de pila entre NMI e IRQ y el motor lo rechaza con un aviso. Los estados (`.sst`) van a la carpeta `saves\` junto a `snes-port.exe` y nunca se publican. |
| Mensajes más rápidos | Mantén **R** (en el teclado, `W`) durante un mensaje y el texto sale un carácter por fotograma. Se desactiva con `--game-opt dialog_skip=0`. |
| Sin pitido de poca vida | Con `--game-opt low_hp_beep=0` no suena el pitido que repite el juego cuando quedan pocos corazones; el resto de efectos suena igual. Por defecto suena como en el original. |
| Máximos en amarillo | Con `--game-opt max_yellow=1`, las rupias (999), las bombas y las flechas en su tope se dibujan en amarillo pálido en el marcador. Apagado por defecto. |
| Girar mientras se corre | Con `--game-opt dash_turn=1`, cambiar de dirección durante la carrera con las botas gira a Link en lugar de cortar la carrera. Apagado por defecto. Probado con `scripts\check.ps1` (con las botas, pulsar otra dirección en plena carrera gira a Link y la carrera sigue). |
| Cambio de objeto con L/R | Con `--game-opt item_switch_lr=1`, **L** y **R** (en el teclado, `Q` y `W`) eligen el objeto anterior o siguiente que tengas, como el menú, y lo ponen en el botón Y sin abrir el menú. Solo con Link libre en mazmorras y exteriores; apagado por defecto. Probado con `scripts\check.ps1`. |
| Cancelar el viaje en pájaro | Con `--game-opt bird_cancel=1`, en la pantalla del mapa donde eliges destino tras tocar la flauta, **B** cancela: el pájaro te deja donde estabas. A, X e Y siguen eligiendo el destino. Apagado por defecto. Probado con `scripts\check.ps1` (con la opción Link vuelve al mismo área y se maneja; sin ella B elige destino). |
| Recoger objetos con la espada | Con `--game-opt sword_pickup=1`, el espadazo (y el giro) recoge los objetos del suelo (rupias, corazones, magia, bombas, flechas, llaves) que alcanza, además de tocarlos con el cuerpo. No da nada que no se pudiera recoger: solo ahorra el paso. Apagado por defecto. Probado con `scripts\check.ps1`. |
| Hasta 9999 rupias | Con `--game-opt rupees_9999=1` la cartera guarda hasta 9999 rupias en lugar de 999 y el marcador dibuja cuatro dígitos desde las 1000 (el contador sube más deprisa cuanto mayor es la diferencia). Con `max_yellow=1` el tope se pone en amarillo. Apagado por defecto. Probado con `scripts\check.ps1`. |

## Texto de los mensajes

El texto del juego se puede volcar a un fichero y traducir sin tocar la ROM. Con el juego construido (desde el lanzador o con `snes-port.exe roms\alttp_usa.sfc`):

```
snes-port.exe roms\alttp_usa.sfc -- --game-opt dump_text=1   # escribe roms\alttp_messages_en.txt junto a tu ROM y sale
```

El volcado sale de **tu** copia del juego (es texto de Nintendo): se queda junto a tu ROM, está ignorado por git y no se comparte. Formato: una línea `@NNN` abre el mensaje NNN; las líneas con `#` son comentarios; los saltos de línea no cuentan; una letra, cifra, espacio o uno de `! ? . , '` es ese carácter, y cualquier otro byte va en hexadecimal entre llaves, `{73}` un byte o `{6B01}` un comando con su parámetro. El `$7F` final no se escribe.

Con la opción `language` en `es` (pestaña **Game** del menú F1, o `--game-opt language=es`) cada cuadro de texto busca su mensaje en `games/alttp_usa/lang/es.txt`, con el mismo formato; el que no esté queda en inglés. El fichero se vuelve a leer cuando cambia, así que se puede editar con el juego en marcha. El repositorio trae esa traducción al español (382 de los 397 mensajes; los demás no tienen texto), escrita para este proyecto, en UTF-8 y con líneas de 32 letras como máximo. La fuente del juego no tiene `á é í ó ú ñ ¿ ¡`: con `language=es` el juego los dibuja al vuelo a partir de sus propias letras (sin guardar ningún byte de la fuente); las mayúsculas acentuadas y `ü` salen sin marca. Un fichero `lang/es.txt` que sea copia del volcado deriva de la ROM y no se debe subir.

## Texto de los menús

La selección de partida («PLAYER SELECT», «COPY PLAYER», «ERASE PLAYER», los avisos de borrar y copiar) y el registro de nombre («REGISTER YOUR NAME», «END») no usan los mensajes de arriba: su texto son tiles de la ROM. También se pueden sustituir sin tocar la ROM:

```
snes-port.exe roms\alttp_usa.sfc -- --game-opt dump_menu=1   # escribe roms\alttp_menu_en.txt junto a tu ROM y sale
```

Una línea `clave = TEXTO` por cadena, con su máximo de letras en un comentario; las líneas con `#` son comentarios. Con `language` en `es`, el juego lee `games/alttp_usa/lang/es_menu.txt` con el mismo formato (solo hace falta las claves que traduzcas) y se vuelve a leer cuando cambia: el texto nuevo se ve la siguiente vez que se abre la pantalla. Reglas: el texto va tras `= ` (un espacio), se pasa a mayúsculas, y lo que sobra del hueco se rellena con espacios; solo hay A–Z, espacio y `?`; un texto más largo que su hueco, o con otro carácter (acentos, `ñ`), se avisa por `stderr` con su línea y esa cadena queda en inglés. Las letras de la rejilla del nombre no se tocan: el nombre se guarda en la partida como esos códigos y se ve igual en cualquier idioma. El repositorio trae `es_menu.txt` con la traducción al español. También traduce lo que hace el botón A en el menú de pausa (`pause.lift1`-`pause.lift3`, `pause.read`, `pause.talk`, `pause.pull`, `pause.run`, `pause.swim`): las cajas van una junto a otra y el juego deja en blanco el primer mosaico de cada una, así que esas claves admiten 4 letras (`pause.run`, 5) y el texto empieza donde empieza la palabra en inglés (solo `pause.run` se centra); en las de levantar no se toca el último mosaico, que es el nivel del guante. Las etiquetas del menú de pausa (ITEM, DO, PENDANTS, EQUIPMENT), el mapa y los objetos aún no se pueden traducir.

## Jugar

### Con el paquete (lo más simple)

1. Descarga `alttp-recomp-<versión>-win64.zip` y descomprímelo.
2. Abre `snes-port.exe` con doble clic: se abre una ventana donde eliges **tu** ROM (`alttp_usa.sfc`) y el juego arranca. También puedes arrastrar la ROM sobre `snes-port.exe`.
3. La primera vez se prepara el juego en tu máquina (unos segundos, o unos minutos según el compilador). No tienes que instalar nada: el paquete lleva un compilador pequeño (TinyCC) que solo se usa si tu equipo no tiene uno (Visual Studio Build Tools, gcc o clang). Las siguientes veces la ventana te ofrece **Jugar** con la misma ROM y arranca al instante. Si algo falla, la ventana lo cuenta y puedes copiar el detalle.

Es normal que algún antivirus desconfíe de un programa sin firmar que compila código al arrancar. Todo ocurre en tu máquina, y nada de tu ROM sale de ella.

Controles, menú F1, opciones, partidas guardadas (`.srm` en `saves\` junto a `snes-port.exe`; las que haya junto a la ROM se importan solas) y demás: ver el [README del motor](https://github.com/AlexPerez7/snes-recomp#readme).

### Desde este repositorio (para desarrollar)

```
snes-port.exe                                  # doble clic: el lanzador (eliges la ROM y juegas)
snes-port.exe roms\alttp_usa.sfc               # construye si hace falta y abre el juego
snes-port.exe roms\alttp_usa.sfc --no-launch   # solo construye
snes-port.exe clean roms\alttp_usa.sfc         # borra la caché de la ROM (si un cambio no se nota)
snes-port.exe roms\alttp_usa.sfc -- --game-opt dialog_skip=0   # opciones del juego
```

Este repositorio lleva el motor ya hecho en la raíz (`snes-port.exe`, `snes-recomp.exe`, `sdl2\`, `toolchain\` con TinyCC; licencia y README del motor como `LICENSE-engine` y `README-engine.md`), así que no hace falta clonar `snes-recomp` para jugar: **doble clic en `snes-port.exe`** abre la ventana del lanzador (reconoce el juego por `games\`), eliges tu ROM y juegas; con una ROM como argumento lo hace sin ventana. Para actualizar el motor: en `snes-recomp`, `powershell -File scripts\release.ps1`; aquí, `powershell -File scripts\update-engine.ps1`, y se sube como cualquier cambio.

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

`check.ps1` se omite con un aviso si falta la ROM, el motor o Visual Studio. `release.ps1` falla si el paquete llevara ROMs, partidas guardadas, estados guardados (`.sst`) o C generado.

## Limitaciones conocidas

- Los estados guardados no incluyen el fotograma en curso (se redibuja) ni variables estáticas del C propio; por ahora se guardan en un único punto del bucle principal (`[resume]` en `00:8034`).
- De las 4 178 funciones de la ROM, 2 (`01:CA17`, `08:A8E3`) se quedan como *stub* y no se ejecutan en el juego.
- La interpolación del DSP usa un núcleo en forma de campana, cercano a la gaussiana del hardware pero no su tabla exacta; la PPU no emula el entrelazado; los comportamientos que dependen de ciclos exactos no se reproducen.

## Contribuir

Mira [CONTRIBUTING.md](CONTRIBUTING.md). Nunca subas la ROM ni nada derivado de ella.
