#!/usr/bin/env bash
# Mide el frontal interactivo (snes_play, con --stats) a ritmo real en varias configuraciones de imagen: fps, ms de presentación y de
# espera por fotograma (la espera es el margen que sobra), fotogramas tarde, resincronizaciones y subdesbordes de audio.
#
#   scripts/bench_play.sh [-t SEGUNDOS] [-d DRIVER] [roms/alttp_usa.sfc]
#
# -d dummy (por defecto): SDL_VIDEODRIVER=dummy con renderizador por software. No toca el servidor gráfico y corre el bucle completo
#       (emulación, PPU, escalado y filtros en la CPU), así que es una cota de CPU; NO mide la presentación real ni el shader CRT (OpenGL).
# -d x11: la ventana real. En la máquina de pruebas (Celeron N4000) se quedaba parada tras crearla (0 % de CPU), así que solo úsalo
#       para comprobar si tu equipo sí la dibuja.
# El juego con ventana no se detiene solo (--frames solo vale con --no-window): se cierra con SIGTERM a los -t segundos (100 s ~ 6000
# fotogramas, hasta que Link se maneja en su casa). Las estadísticas son de toda la ejecución, intro incluida.
# Usa el juego ya construido en la caché de snes-port (~/.cache/snes-port): construirlo antes con snes-port --no-launch.
# Escribe out/bench/play_summary.txt. Trabaja con una copia de la ROM en out/ para que config.ini y .srm no vayan junto a tu ROM.
set -u
cd "$(dirname "$0")/.." || exit 1
root=$PWD
SECS=100
DRIVER=dummy
while getopts "t:d:" o; do
    case $o in t) SECS=$OPTARG ;; d) DRIVER=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
ROM=${1:-roms/alttp_usa.sfc}
die() { echo "error: $*" >&2; exit 1; }
[ -f "$ROM" ] || { echo "omitido: no hay ROM en $ROM" >&2; exit 0; }

CACHE=${SNES_PORT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/snes-port}
GAME=""
for d in "$CACHE"/*/; do [ -x "${d}game.bin" ] && GAME=${d}game.bin; done
[ -n "$GAME" ] || { echo "omitido: el juego no está construido en $CACHE (snes-port <rom> --game games/alttp_usa.toml --no-launch)" >&2; exit 0; }

out=$root/out
bench=$out/bench
mkdir -p "$bench"
work=$bench/play
rm -rf "$work"; mkdir -p "$work"
cp "$ROM" "$work/rom.sfc"

toControl=(
    --press START@1100-1110 --press A@1300-1305 --press A@1500-1504 --press DOWN@1540-1542
    --press DOWN@1560-1562 --press DOWN@1580-1582 --press RIGHT@1600-1602 --press RIGHT@1620-1622
    --press A@1640-1643 --press A@2000-2004
)
for ((f = 2100; f < 5200; f += 50)); do toControl+=(--press "A@$f-$((f + 3))"); done

# nombre|opciones (--opt CLAVE=VALOR, solo para esa ejecución)
SCEN=(
    "base (escala 3, sharp)|scale=3"
    "escala 1, nearest|scale=1 filter=nearest"
    "escala 3, bilinear|scale=3 filter=bilinear"
    "escala 5, sharp|scale=5"
    "scanlines 50|scale=3 scanlines=50"
    "wide 96|scale=3 wide=96"
)

env_drv=()
if [ "$DRIVER" = dummy ]; then env_drv=(SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SDL_RENDER_DRIVER=software); fi

{
    echo "fecha: $(date -Is)"
    echo "cpu: $(lscpu | sed -n 's/^Model name: *//p;s/^Nombre del modelo: *//p' | head -1) ($(nproc) hilos)"
    echo "driver de vídeo: $DRIVER, duración por escenario: ${SECS}s (~$((SECS * 60)) fotogramas)"
} | tee "$bench/play_summary.txt"
printf '%-24s %9s %9s %9s %6s %8s %8s %6s\n' escenario fps present_ms espera_ms tarde resync dropped underr | tee -a "$bench/play_summary.txt"

for s in "${SCEN[@]}"; do
    name=${s%%|*}; opts=${s#*|}
    optargs=()
    for o in $opts; do optargs+=(--opt "$o"); done
    log=$work/$(echo "$name" | tr -c 'a-z0-9\n' '_').log
    (cd "$work" && exec env "${env_drv[@]}" "$GAME" rom.sfc --stats "${optargs[@]}" "${toControl[@]}" >"$log" 2>&1) &
    pid=$!
    sleep "$SECS"
    kill -TERM "$pid" 2>/dev/null
    for _ in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    st=$(grep '^stats:' "$log" || true)
    au=$(grep '^audio:' "$log" || true)
    if [ -z "$st" ]; then
        printf '%-24s %s\n' "$name" "sin estadísticas (no terminó limpiamente)" | tee -a "$bench/play_summary.txt"
        continue
    fi
    fps=$(sed -n 's/.*(\([0-9.]*\) fps).*/\1/p' <<<"$st")
    pres=$(sed -n 's/.*present \([0-9.]*\) ms.*/\1/p' <<<"$st")
    wait_ms=$(sed -n 's/.*waiting \([0-9.]*\) ms.*/\1/p' <<<"$st")
    late=$(sed -n 's/.*, \([0-9]*\) late frames.*/\1/p' <<<"$st")
    rs=$(sed -n 's/.*, \([0-9]*\) resyncs.*/\1/p' <<<"$st")
    dr=$(sed -n 's/.*, \([0-9]*\) frames dropped.*/\1/p' <<<"$au")
    ur=$(sed -n 's/.*, \([0-9]*\) underruns.*/\1/p' <<<"$au")
    printf '%-24s %9s %9s %9s %6s %8s %8s %6s\n' "$name" "$fps" "$pres" "$wait_ms" "$late" "$rs" "${dr:-?}" "${ur:-?}" | tee -a "$bench/play_summary.txt"
done
echo "(espera_ms = margen medio por fotograma; 16.64 ms es el fotograma. 'tarde' incluye la intro, que es lo más pesado.)" | tee -a "$bench/play_summary.txt"
