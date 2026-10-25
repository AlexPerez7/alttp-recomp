# alttp-recomp

*The Legend of Zelda: A Link to the Past* (USA) recompilado a código nativo con el motor [`snes-recomp`](https://github.com/AlexPerez7/snes-recomp). Este repositorio es el **juego**: su perfil (`games/alttp_usa.toml`), el C propio que lo mejora (`games/alttp_usa/`) y los scripts para comprobarlo y empaquetarlo. El recompilador, el runtime y `snes-port` están en el motor.

> **Aviso legal.** Este repositorio no contiene la ROM ni ningún recurso del juego (gráficos, sonido, texto, mapas), y no lo tendrá. Cada persona debe aportar su propia copia obtenida legalmente. El programa se construye en tu máquina a partir de **tu** ROM y nada derivado de ella se distribuye. Proyecto independiente y sin relación con Nintendo.

Licencia: [MIT](LICENSE), solo para el código de este repositorio; no da derechos sobre el juego.

## Qué contiene

- `games/alttp_usa.toml`: identifica la ROM (CRC32 `777AAC2F`) y da al recompilador las entradas de código, las tablas de saltos (comprobadas a mano contra la ROM real) y los ganchos. Solo lleva direcciones, nombres y tamaños de tabla; ningún byte del juego.
- `games/alttp_usa/dialog.c`: C original que se compila junto al código generado. Acelera los mensajes.
- `games/alttp_usa/widefill.c`: con la pantalla ancha (`wide` en `config.ini` o `--opt wide=N`), tapa en negro las columnas extra donde no hay mapa cargado: pasado el borde del área en el exterior, y en las salas y cuevas, siempre.
- `scripts/check.ps1`: prueba que lo anterior funciona (necesita tu ROM).
- `scripts/release.ps1`: arma el paquete para repartir.

## Mejoras sobre el juego original

| Mejora | Cómo se usa |
|---|---|
| Pantalla ancha sin basura | Con `wide` mayor que 0 el borde del mapa y el interior de salas y cuevas se ven en negro en lugar de repetir el lado contrario del mapa. |
| Mensajes más rápidos | Mantén **R** (en el teclado, `W`) durante un mensaje y el texto sale un carácter por fotograma. Se desactiva con `--game-opt dialog_skip=0`. |

## Jugar

### Con el paquete (lo más simple)

1. Descarga `alttp-recomp-<versión>-win64.zip` y descomprímelo.
2. Arrastra **tu** ROM (`alttp_usa.sfc`) sobre `snes-port.exe`, o ábrelo con doble clic y elígela.
3. La primera vez se construye el juego en tu máquina (necesita un compilador de C: Visual Studio Build Tools, gcc o clang; sin ninguno, `snes-port` ofrece descargar TinyCC con tu permiso). Las siguientes veces arranca al instante.

Controles, menú F1, opciones, partidas guardadas (`.srm` junto a la ROM) y demás: ver el [README del motor](https://github.com/AlexPerez7/snes-recomp#readme).

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
