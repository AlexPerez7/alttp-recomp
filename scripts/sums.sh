#!/usr/bin/env bash
# Escribe out/release/SHA256SUMS con los hashes de los paquetes de out/release (zip, tar.gz y el APK si está al lado).
# El lanzador de escritorio lo descarga de la release y solo instala un paquete cuyo SHA-256 aparezca aquí: súbelo con los paquetes.
set -euo pipefail
cd "$(dirname "$0")/../out/release"
sha256sum -- *.zip *.tar.gz *.apk 2>/dev/null > SHA256SUMS || true
cat SHA256SUMS
