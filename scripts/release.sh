#!/usr/bin/env bash
# Arma out/release/alttp-recomp-<version>-linux-x86_64.tar.gz con el lanzador de Linux del motor (../snes-recomp/linux/build.sh):
# un ejecutable `alttp-recomp` con libtcc y SDL2 dentro. El usuario descomprime, abre `alttp-recomp`, elige su ROM y juega; no
# necesita compilador ni SDL2.
# No lleva ROMs, partidas, estados ni C generado: si algo así acaba en la carpeta, falla y no crea el paquete.
#   scripts/release.sh [version] [carpeta con snes-port y snes-recomp]
set -euo pipefail
cd "$(dirname "$0")/.."
ver="${1:-0.1}"
motor="${SNES_ENGINE_REPO:-../snes-recomp}"
[ -x "$motor/linux/build.sh" ] || { echo "falta $motor/linux/build.sh (el motor, rama con el lanzador de Linux)"; exit 1; }
name="alttp-recomp-$ver-linux-x86_64"
stage="out/release/$name"
"$motor/linux/build.sh" "$PWD/games/alttp_usa.toml" alttp-recomp
rm -rf "$stage"; mkdir -p "$stage"
cp -r "$motor/out/linux/alttp-recomp/." "$stage/"
cp README.md LICENSE LICENSE-engine README-engine.md "$stage/"
bad=$(find "$stage" -type f \( -iname '*.sfc' -o -iname '*.smc' -o -iname '*.srm' -o -iname '*.sst' -o -name 'rom_*.c' -o -name snes_entry.c -o -name snes_funcs.h \) -print)
[ -z "$bad" ] || { echo "El paquete lleva ficheros que no deben ir:"; echo "$bad"; rm -rf "$stage"; exit 1; }
tar -C out/release -czf "out/release/$name.tar.gz" "$name"
echo "out/release/$name.tar.gz"
