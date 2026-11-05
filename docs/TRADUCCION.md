# Traducción y texto del juego

Volver al [README](../README.md).

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
