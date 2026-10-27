# Contribuir

Este repositorio es el juego (*A Link to the Past*, USA); el recompilador, el runtime y `snes-port` están en [`snes-recomp`](https://github.com/AlexPerez7/snes-recomp), y sus reglas generales (OpenSpec, clean-room, pruebas) están en su [CONTRIBUTING.md](https://github.com/AlexPerez7/snes-recomp/blob/main/CONTRIBUTING.md). Un fallo del traductor, de la PPU o del sonido va allí.

## Reglas que no se negocian

- **Nunca la ROM ni nada derivado de ella**: ni en commits, ni en issues, ni en PR. Eso incluye volcados de VRAM/WRAM, capturas con gráficos del juego, el C generado y bytes de tablas copiados de la ROM. `.gitignore` excluye `*.sfc`, `*.smc`, `*.srm`, `roms/` y `out/`. Antes de abrir un PR, con el motor compilado:

  ```
  .\snes-recomp.exe scan ruta\a\alttp_usa.sfc .
  ```

  Debe terminar sin error.
- **Código propio.** El C que añadas aquí es original (clean-room). Documentación pública sobre el juego (mapas de memoria de la comunidad) puede servir de pista para encontrar una dirección, pero la dirección se comprueba a mano contra la ROM real.
- **Tablas de saltos** comprobadas a mano antes de añadirlas a `games/alttp_usa.toml`.

## Qué se puede aportar

- **Mejoras del juego**: ganchos `before`/`after`/`replace` en `games/alttp_usa.toml` con su C en `games/alttp_usa/`. Se activan con la ROM original y, si pueden molestar, tienen una opción (`game_opt("clave", defecto)`, que se pasa con `--game-opt clave=valor`).
- **Direcciones y tablas** que falten (`snes-recomp discover <rom> --game games/alttp_usa.toml --unresolved` lista los saltos indirectos sin tabla).
- **Documentación** de cómo funciona una parte del juego y de las direcciones que usan los ganchos.

El C de los ganchos usa solo la interfaz de `runtime/snes_rt.h` del motor: `wram_read8`/`wram_write8`, `joy1_state()` y `game_opt()`.

## Probar

```
powershell -File scripts\check.ps1 -Rom ruta\a\alttp_usa.sfc
```

Genera el C con el motor, lo compila y ejecuta el juego sin ventana hasta el primer mensaje. Si añades un gancho nuevo, amplía `check.ps1` con una comprobación del byte de WRAM que cambia (mira cómo lo hace con `$1CD9`). Para ver el efecto a mano: `snes-port ... --game games\alttp_usa.toml`.

## Commits y PR

- Mensajes en español, en imperativo, con el qué y el porqué en la primera línea.
- Describe en el PR qué dirección de la ROM tocas, cómo la comprobaste y con qué ROM (sin adjuntar nada de ella).
