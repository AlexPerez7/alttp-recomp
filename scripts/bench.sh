#!/usr/bin/env bash
# Mide el tiempo por fotograma del juego con el runtime sin vídeo (headless -O2) en varios escenarios y lo compara con el presupuesto
# de 60,0988 Hz (16 639 us). Sirve para validar rendimiento en equipos modestos.
#
#   scripts/bench.sh [-r REPETICIONES] [-f FOTOGRAMAS] [roms/alttp_usa.sfc] [ruta/a/snes-recomp]
#
# Escenarios (todos juegan igual hasta que Link se maneja en su casa, fotograma ~5200):
#   base      opciones por defecto
#   opts_off  todas las mejoras de quality.c y el parche de mensajes apagados (mide su coste)
#   es        language=es (traducción de mensajes y menús al vuelo)
#   wide96    --wide 96 (el máximo ensanche de pantalla)
# Escribe out/bench/summary.txt, out/bench/<escenario>.<n>.txt (microsegundos por fotograma) y un resumen en pantalla.
# Usa el compilador y el motor igual que check.sh y reutiliza out/rom si existe (si no, genera el C). Deja la máquina sin otra carga.
set -u
cd "$(dirname "$0")/.." || exit 1
root=$PWD
REPS=1
FRAMES=5400
while getopts "r:f:" o; do
    case $o in r) REPS=$OPTARG ;; f) FRAMES=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
ROM=${1:-roms/alttp_usa.sfc}
ENGINE=${2:-}
die() { echo "error: $*" >&2; exit 1; }
skip() { echo "omitido: $*" >&2; exit 0; }

[ -f "$ROM" ] || skip "no hay ROM en $ROM"
if [ -z "$ENGINE" ]; then
    for c in "${SNES_ENGINE:-}" "${SNES_ENGINE:-}/snes-recomp" "$root/snes-recomp" "$root/../snes-recomp/target/release/snes-recomp"; do
        if [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ]; then ENGINE=$c; break; fi
    done
fi
[ -n "$ENGINE" ] || skip "no hay motor (cargo build --release en ../snes-recomp; o define SNES_ENGINE)"
CC=${CC:-}
if [ -z "$CC" ]; then for c in gcc clang cc; do command -v "$c" >/dev/null 2>&1 && { CC=$c; break; }; done; fi
[ -n "$CC" ] || skip "no hay compilador de C"

out=$root/out
gen=$out/rom
bench=$out/bench
mkdir -p "$gen" "$bench"
if [ ! -f "$gen/snes_entry.c" ]; then
    "$ENGINE" codegen "$ROM" --all -o "$gen" --game games/alttp_usa.toml >/dev/null 2>&1 || die "codegen fallo"
fi
HF=$out/headless_fast
if [ ! -x "$HF" ]; then
    echo "compilando headless_fast..."
    "$CC" -std=c11 -O2 -DSNES_RT_TICK -I"$gen" "$gen"/*.c "$gen"/game/*.c -o "$HF" -lm >"$out/build_fast.log" 2>&1 || { tail -30 "$out/build_fast.log"; die "la compilacion fallo"; }
fi
# el volcado de texto se escribe junto a la ROM: se trabaja con una copia
textRom=$out/rom.sfc
[ -f "$textRom" ] || cp "$ROM" "$textRom"

toControl=(
    --press START@1100-1110 --press A@1300-1305 --press A@1500-1504 --press DOWN@1540-1542
    --press DOWN@1560-1562 --press DOWN@1580-1582 --press RIGHT@1600-1602 --press RIGHT@1620-1622
    --press A@1640-1643 --press A@2000-2004
)
for ((f = 2100; f < 5200; f += 50)); do toControl+=(--press "A@$f-$((f + 3))"); done

declare -A SCEN=(
    [base]=""
    [opts_off]="--game-opt dialog_skip=0 --game-opt max_yellow=0 --game-opt low_hp_beep=0 --game-opt dash_turn=0 --game-opt item_switch_lr=0 --game-opt bird_cancel=0 --game-opt rupees_9999=0 --game-opt sword_pickup=0 --game-opt sword_pots=0 --game-opt more_bombs=0"
    [es]="--game-opt language=es"
    [wide96]="--wide 96"
)
ORDER=(base opts_off es wide96)

TIMEV=""
[ -x /usr/bin/time ] && TIMEV=/usr/bin/time

{
    echo "fecha: $(date -Is)"
    echo "cpu: $(lscpu | sed -n 's/^Model name: *//p;s/^Nombre del modelo: *//p' | head -1) ($(nproc) hilos), gobernador: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo ?)"
    echo "memoria: $(free -h | awk '/^Mem|^Memoria/ {print $2}'), carga al empezar: $(cut -d' ' -f1-3 /proc/loadavg)"
    echo "fotogramas por escenario: $FRAMES, repeticiones: $REPS"
} | tee "$bench/summary.txt"

for name in "${ORDER[@]}"; do
    for ((n = 1; n <= REPS; n++)); do
        ft=$bench/$name.$n.txt
        # shellcheck disable=SC2086
        if [ -n "$TIMEV" ]; then
            $TIMEV -f "%e %M" -o "$bench/$name.$n.time" "$HF" "$textRom" --frames "$FRAMES" --frame-blocks 20000 --frame-times "$ft" "${toControl[@]}" ${SCEN[$name]} >/dev/null 2>&1 || die "$name.$n termino con error"
        else
            "$HF" "$textRom" --frames "$FRAMES" --frame-blocks 20000 --frame-times "$ft" "${toControl[@]}" ${SCEN[$name]} >/dev/null 2>&1 || die "$name.$n termino con error"
            echo "? ?" >"$bench/$name.$n.time"
        fi
        echo "  $name #$n hecho" >&2
    done
done

python3 -I - "$bench" "$REPS" "${ORDER[@]}" <<'EOF' | tee -a "$bench/summary.txt"
import sys, statistics
from pathlib import Path
bench, reps, names = Path(sys.argv[1]), int(sys.argv[2]), sys.argv[3:]
BUDGET = 16639.0  # us por fotograma a 60,0988 Hz

def pct(v, p):
    s = sorted(v)
    return s[min(len(s) - 1, int(round(p / 100 * (len(s) - 1))))]

print()
print(f"presupuesto: {BUDGET:.0f} us/fotograma. 'sobre' = % de fotogramas que lo superan; 'x' = veces más rápido que tiempo real (media).")
print(f"{'escenario':10} {'fase':9} {'media':>7} {'p50':>7} {'p95':>7} {'p99':>7} {'max':>7} {'sobre':>7} {'x':>6}  pared(s) RSS(MiB)")
base_mean = {}
for name in names:
    for n in range(1, reps + 1):
        v = [float(x) for x in (bench / f"{name}.{n}.txt").read_text().split()]
        wall, rss = (bench / f"{name}.{n}.time").read_text().split()
        rss = f"{int(rss) / 1024:.0f}" if rss != "?" else "?"
        phases = {"todo": v, "partida": v[5200:] if len(v) > 5300 else v[-100:], "intro": v[:1100]}
        for ph, d in phases.items():
            mean = statistics.fmean(d)
            over = 100 * sum(1 for x in d if x > BUDGET) / len(d)
            extra = f"{wall:>8} {rss:>8}" if ph == "todo" else ""
            print(f"{name + ('#' + str(n) if reps > 1 else ''):10} {ph:9} {mean:7.0f} {pct(d,50):7.0f} {pct(d,95):7.0f} {pct(d,99):7.0f} {max(d):7.0f} {over:6.1f}% {BUDGET/mean:6.1f}  {extra}")
            if ph == "partida" and n == 1:
                base_mean[name] = mean
if "base" in base_mean:
    print()
    for name in names:
        if name != "base" and name in base_mean:
            print(f"coste de '{name}' frente a 'base' en partida: {100 * (base_mean[name] / base_mean['base'] - 1):+.1f}%")
EOF
