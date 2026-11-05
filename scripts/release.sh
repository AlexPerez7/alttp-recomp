#!/usr/bin/env bash
# Arma out/release/alttp-recomp-<version>-linux-x86_64.tar.gz: snes-port y snes-recomp del motor (compilado desde ../snes-recomp),
# games/ de este repositorio, licencias y un jugar.sh. El usuario descomprime y ejecuta ./snes-port su_rom.sfc (necesita gcc y libsdl2).
# No lleva ROMs, partidas, estados ni C generado: si algo así acaba en la carpeta, falla y no crea el paquete.
#   scripts/release.sh [version] [carpeta con snes-port y snes-recomp]
set -euo pipefail
cd "$(dirname "$0")/.."
ver="${1:-0.1}"
eng="${2:-${SNES_ENGINE_DIR:-../snes-recomp/target/release}}"
for b in snes-port snes-recomp; do [ -x "$eng/$b" ] || { echo "falta $eng/$b (cargo build --release en ../snes-recomp)"; exit 1; }; done
name="alttp-recomp-$ver-linux-x86_64"
stage="out/release/$name"
rm -rf "$stage"; mkdir -p "$stage"
cp "$eng/snes-port" "$eng/snes-recomp" "$stage/"
cp -r games "$stage/games"
cp LICENSE LICENSE-engine README-engine.md "$stage/"
cat > "$stage/jugar.sh" <<'J'
#!/usr/bin/env bash
# Uso: ./jugar.sh [ruta/a/la/rom.sfc]   (por defecto roms/alttp_usa.sfc junto a este script)
cd "$(dirname "$0")"
rom="${1:-roms/alttp_usa.sfc}"
[ -f "$rom" ] || { echo "No encuentro la ROM: $rom"; echo "Uso: ./jugar.sh ruta/a/alttp_usa.sfc (USA, CRC32 777AAC2F)"; exit 1; }
command -v gcc >/dev/null || { echo "Falta gcc (sudo apt install build-essential pkg-config libsdl2-dev)"; exit 1; }
exec ./snes-port "$rom" --game games/alttp_usa.toml
J
chmod +x "$stage/jugar.sh"
bad=$(find "$stage" -type f \( -iname '*.sfc' -o -iname '*.smc' -o -iname '*.srm' -o -iname '*.sst' -o -name '*.generated.c' \) -print)
[ -z "$bad" ] || { echo "El paquete lleva ficheros que no deben ir:"; echo "$bad"; rm -rf "$stage"; exit 1; }
tar -C out/release -czf "out/release/$name.tar.gz" "$name"
echo "out/release/$name.tar.gz"
