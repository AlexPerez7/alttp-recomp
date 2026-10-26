# alttp-recomp

*The Legend of Zelda: A Link to the Past* (USA) recompilado a código nativo con el motor [`snes-recomp`](https://github.com/AlexPerez7/snes-recomp). Este repositorio es el **juego**: su perfil (`games/alttp_usa.toml`), el C propio que lo mejora (`games/alttp_usa/`) y los scripts para comprobarlo y empaquetarlo. El recompilador, el runtime y `snes-port` están en el motor.

> **Aviso legal.** Este repositorio no contiene la ROM ni ningún recurso del juego (gráficos, sonido, texto, mapas), y no lo tendrá. Cada persona debe aportar su propia copia obtenida legalmente. El programa se construye en tu máquina a partir de **tu** ROM y nada derivado de ella se distribuye. Proyecto independiente y sin relación con Nintendo.

Licencia: [MIT](LICENSE), solo para el código de este repositorio; no da derechos sobre el juego.

## Qué contiene

- `games/alttp_usa.toml`: identifica la ROM (CRC32 `777AAC2F`) y da al recompilador las entradas de código, las tablas de saltos (comprobadas a mano contra la ROM real) y los ganchos. Solo lleva direcciones, nombres y tamaños de tabla; ningún byte del juego.
- `games/alttp_usa/dialog.c`: C original que se compila junto al código generado. Acelera los mensajes.
- `games/alttp_usa/widefill.c`: con la pantalla ancha (`wide` en `config.ini` o `--opt wide=N`), tapa en negro las columnas extra donde no hay mapa cargado: pasado el borde del área en el exterior, y en las salas y cuevas, siempre.
- `games/alttp_usa/text.c`: vuelca los mensajes del juego a un fichero de texto y, con la opción `language`, los sustituye por los de `lang/es.txt`.
- `scripts/check.ps1`: prueba que lo anterior funciona (necesita tu ROM).
- `scripts/release.ps1`: arma el paquete para repartir.

## Mejoras sobre el juego original

| Mejora | Cómo se usa |
|---|---|
| Pantalla ancha sin basura | Con `wide` mayor que 0 el borde del mapa y el interior de salas y cuevas se ven en negro en lugar de repetir el lado contrario del mapa. |
| Mensajes más rápidos | Mantén **R** (en el teclado, `W`) durante un mensaje y el texto sale un carácter por fotograma. Se desactiva con `--game-opt dialog_skip=0`. |

## Texto de los mensajes

El texto del juego se puede volcar a un fichero y traducir sin tocar la ROM. Con el juego construido (`play.bat`):

```
play.bat -- --game-opt dump_text=1   # escribe romslttp_messages_en.txt junto a tu ROM y sale
```

El volcado sale de **tu** copia del juego (es texto de Nintendo): se queda junto a tu ROM, está ignorado por git y no se comparte. Formato: una línea `@NNN` abre el mensaje NNN; las líneas con `#` son comentarios; los saltos de línea no cuentan; una letra, cifra, espacio o uno de `! ? . , '` es ese carácter, y cualquier otro byte va en hexadecimal entre llaves, `{73}` un byte o `{6B01}` un comando con su parámetro. El `$7F` final no se escribe.

Con la opción `language` en `es` (pestaña **Game** del menú F1, o `--game-opt language=es`) cada cuadro de texto busca su mensaje en `games/alttp_usa/lang/es.txt`, con el mismo formato; el que no esté queda en inglés. El fichero se vuelve a leer cuando cambia, así que se puede editar con el juego en marcha. Aún no hay letras con tilde ni control de anchura: eso va en cambios siguientes.

## Jugar

### Con el paquete (lo más simple)

1. Descarga `alttp-recomp-<versión>-win64.zip` y descomprímelo.
2. Arrastra **tu** ROM (`alttp_usa.sfc`) sobre `snes-port.exe`, o ábrelo con doble clic y elígela.
3. La primera vez se construye el juego en tu máquina (necesita un compilador de C: Visual Studio Build Tools, gcc o clang; sin ninguno, `snes-port` ofrece descargar TinyCC con tu permiso). Las siguientes veces arranca al instante.

Controles, menú F1, opciones, partidas guardadas (`.srm` junto a la ROM) y demás: ver el [README del motor](https://github.com/AlexPerez7/snes-recomp#readme).

### Desde este repositorio (para desarrollar)

```
play.bat                 # construye si hace falta y abre el juego (ROM en roms\alttp_usa.sfc)
play.bat -Rebuild        # borra la caché y lo construye de nuevo
play.bat -NoLaunch       # solo construye
play.bat -- --game-opt dialog_skip=0   # opciones del juego
```

`scripts\play.ps1` usa el motor de `engine\` (ignorado por git). Si no existe, lo extrae del zip más reciente de `..\snes-recomp\out\release\` o del que pases con `-EngineZip`; con `SNES_ENGINE` apuntas a otra carpeta. Una vez extraído no hace falta el repositorio del motor. Para actualizar el motor, borra `engine\` y repite.

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
powershell -File scripts\check.ps1 -Rom ruta\a\alttp_usa.sfc      # genera, compila y ejecuta; ~1 min
cd ..\snes-recomp ; powershell -File scripts\release.ps1 ; cd ..\alttp-recomp
powershell -File scripts\release.ps1 -Engine ..\snes-recomp\out\release\snes-port-0.1.0-win64.zip
```

`check.ps1` se omite con un aviso si falta la ROM, el motor o Visual Studio. `release.ps1` falla si el paquete llevara ROMs, partidas guardadas o C generado.

## Limitaciones conocidas

- De las 4 178 funciones de la ROM, 2 (`01:CA17`, `08:A8E3`) se quedan como *stub* y no se ejecutan en el juego.
- La interpolación del DSP usa un núcleo en forma de campana, cercano a la gaussiana del hardware pero no su tabla exacta; la PPU no emula el entrelazado; los comportamientos que dependen de ciclos exactos no se reproducen.

## Contribuir

Mira [CONTRIBUTING.md](CONTRIBUTING.md). Nunca subas la ROM ni nada derivado de ella.
