#!/usr/bin/env bash
# Equivalente en Linux de scripts/check.ps1: mismas pruebas con la ROM (mensajes con R, pantalla ancha, texto traducible, menús y
# mejoras de games/alttp_usa/quality.c). Genera el C con el motor, lo compila con gcc/clang y ejecuta el runtime sin vídeo.
#
#   scripts/check.sh [roms/alttp_usa.sfc] [ruta/a/snes-recomp]
#
# El motor se busca en: el 2º argumento, $SNES_ENGINE (carpeta o ejecutable), ./snes-recomp, ../snes-recomp/target/release/snes-recomp.
# Compilador: $CC, o gcc, o clang, o cc. Se omite con un aviso (código 0) si falta la ROM, el motor o el compilador. Todo lo que genera va
# a out/ (ignorado por git): deriva de la ROM y no se sube. Las comprobaciones de datos están en scripts/check_eval.py (Python 3 con Pillow).
set -u
cd "$(dirname "$0")/.." || exit 1
root=$PWD
ROM=${1:-roms/alttp_usa.sfc}
ENGINE=${2:-}
EVAL=(python3 -I "$root/scripts/check_eval.py")

skip() { echo "omitido: $*" >&2; exit 0; }
die() { echo "error: $*" >&2; exit 1; }

[ -f "$ROM" ] || skip "no hay ROM en $ROM"
if [ -z "$ENGINE" ]; then
    for c in "${SNES_ENGINE:-}" "${SNES_ENGINE:-}/snes-recomp" "$root/snes-recomp" "$root/../snes-recomp/target/release/snes-recomp"; do
        if [ -n "$c" ] && [ -f "$c" ] && [ -x "$c" ]; then ENGINE=$c; break; fi
    done
fi
[ -n "$ENGINE" ] && [ -x "$ENGINE" ] || skip "no hay motor (snes-recomp compilado: cargo build --release en ../snes-recomp; o define SNES_ENGINE)"
CC=${CC:-}
if [ -z "$CC" ]; then
    for c in gcc clang cc; do command -v "$c" >/dev/null 2>&1 && { CC=$c; break; }; done
fi
[ -n "$CC" ] || skip "no hay compilador de C (gcc o clang)"
command -v python3 >/dev/null 2>&1 || skip "falta python3"
python3 -c "import PIL" 2>/dev/null || skip "falta Pillow (sudo apt install python3-pil)"

out=$root/out
gen=$out/rom
rm -rf "$out"
mkdir -p "$gen/fast"

"$ENGINE" codegen "$ROM" --all -o "$gen" --game games/alttp_usa.toml >/dev/null 2>&1 || die "codegen fallo"
for f in dialog.c widefill.c text.c menutext.c hud.c quality.c icon.c; do
    [ -f "$gen/game/$f" ] || die "el motor no copio $f a out/rom/game"
done

# el segundo ejecutable es un headless sin comprobaciones de anchura y optimizado, para las partidas largas de las mejoras de calidad
"$CC" -std=c11 -O1 -DSNES_RT_TICK -DSNES_RT_CHECKS -I"$gen" "$gen"/*.c "$gen"/game/*.c -o "$out/headless" -lm >"$out/build.log" 2>&1 &
p1=$!
"$CC" -std=c11 -O2 -DSNES_RT_TICK -I"$gen" "$gen"/*.c "$gen"/game/*.c -o "$out/headless_fast" -lm >"$out/build_fast.log" 2>&1 &
p2=$!
wait $p1 || { tail -30 "$out/build.log"; die "la compilacion fallo"; }
wait $p2 || { tail -30 "$out/build_fast.log"; die "la compilacion rapida fallo"; }

H=$out/headless
HF=$out/headless_fast

# de la pantalla de título al primer mensaje del juego (fotograma 2028 en adelante)
toMessage=(
    --press START@1100-1110 --press A@1300-1305 --press A@1500-1504 --press DOWN@1540-1542
    --press DOWN@1560-1562 --press DOWN@1580-1582 --press RIGHT@1600-1602 --press RIGHT@1620-1622
    --press A@1640-1643 --press A@2000-2004
)

# hl <nombre> <exe> <rom> args...: ejecuta el runtime sin vídeo, sin salida, y falla si termina con error
hl() {
    local name=$1 exe=$2; shift 2
    "$exe" "$@" >/dev/null 2>&1 || die "$(basename "$exe") termino con codigo $? ($name)"
}

ok=1
fail() { echo "error: $*" >&2; ok=0; }
# yes <valor 0/1> <mensaje>: marca error si el valor no es 1
need() { [ "$1" = 1 ] || fail "$2"; }
b2i() { if "$@"; then echo 1; else echo 0; fi; }

chars() {
    local name=$1; shift
    local dump=$out/dump_$name
    mkdir -p "$dump"
    hl "$name" "$H" "$ROM" --frames 2040 --frame-blocks 20000 --dump "$dump" "${toMessage[@]}" "$@"
    [ "$("${EVAL[@]}" byte "$dump/wram.bin" 0x10)" = 14 ] || die "($name) el modulo de mensajes no esta en marcha"
    "${EVAL[@]}" byte "$dump/wram.bin" 0x1CD9
}
plain=$(chars plain)
fast=$(chars fast --press R@2000-2300)
off=$(chars off --press R@2000-2300 --game-opt dialog_skip=0)
echo "caracteres a los 2040 fotogramas: sin R = $plain, con R = $fast, con R y dialog_skip=0 = $off"

# pantalla ancha: interior (fotograma 2040, el primer mensaje transcurre dentro de la casa)
hl wide "$H" "$ROM" --frames 2040 --frame-blocks 20000 --wide 32 --screenshot "$out/wide.png" "${toMessage[@]}"
wideOk=$("${EVAL[@]}" wide "$out/wide.png")
echo "pantalla ancha (interior, --wide 32): franjas negras = $wideOk"

# texto de los mensajes (games/alttp_usa/text.c): el volcado se escribe junto a la ROM, así que se trabaja con una copia en out/
textRom=$out/rom.sfc
cp "$ROM" "$textRom"
textDir=$out/text
mkdir -p "$textDir/lang"
dumptext() { hl "volcado de mensajes" "$H" "$textRom" --frames 2040 --frame-blocks 20000 --game-opt dump_text=1 "$@"; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
dumptext
en=$out/alttp_messages_en.txt
messages=$(grep -cE '^@[0-9]+$' "$en")
enHash=$(sha "$en")
if [ "$messages" = 397 ] && [ "$enHash" = e202ed47b0473ca3cd090a85054ef3f939e03fdd65b1a539fe183306dca929a1 ]; then textOk=1; else textOk=0; fi
echo "volcado de mensajes: $messages mensajes, huella correcta = $textOk"
# ida y vuelta: con lang/es.txt igual al volcado, el juego produce exactamente el mismo texto
cp "$en" "$textDir/lang/es.txt"
dumptext --game-opt language=es --game-dir "$textDir"
roundTrip=$(b2i [ "$(sha "$out/alttp_messages_es.txt")" = "$enHash" ])
echo "ida y vuelta de es.txt = volcado: idéntica = $roundTrip"
# cambiar una línea cambia solo ese mensaje
sed 's/Save And Continue{75}/Guardar y continuar{75}/' "$en" >"$textDir/lang/es.txt"
dumptext --game-opt language=es --game-dir "$textDir"
changedLines=$(diff "$en" "$out/alttp_messages_es.txt" | grep -c '^[<>]')
if diff "$en" "$out/alttp_messages_es.txt" | grep -q '^> .*Guardar y continuar' && [ "$changedLines" = 2 ]; then editOk=1; else editOk=0; fi
echo "un mensaje cambiado cambia solo ese mensaje = $editOk"
# el primer cuadro de texto es idéntico con language=en y con language=es (es.txt = volcado): la pantalla y la WRAM
cp "$en" "$textDir/lang/es.txt"
firstbox() {
    local name=$1; shift
    local d=$out/text_$name
    mkdir -p "$d"
    hl "$name" "$H" "$textRom" --frames 2040 --frame-blocks 20000 --dump "$d" --screenshot "$d/shot.png" "${toMessage[@]}" "$@"
    echo "$(sha "$d/shot.png"),$(sha "$d/wram.bin")"
}
boxEn=$(firstbox en)
boxEs=$(firstbox es --game-opt language=es --game-opt hud_text=0 --game-dir "$textDir")
boxOk=$(b2i [ "$boxEn" = "$boxEs" ])
echo "primer cuadro de texto idéntico con language=en y language=es = $boxOk"

# texto de la selección de partida y del registro de nombre (games/alttp_usa/menutext.c)
dumpmenu() { hl "volcado de menus" "$H" "$textRom" --frames 300 --frame-blocks 20000 --game-opt dump_menu=1 "$@"; }
dumpmenu
menuEn=$out/alttp_menu_en.txt
menuKeys=$(grep -cE '^[a-z_.0-9]+ = ' "$menuEn")
menuOk=$(b2i [ "$menuKeys" = 23 ])
echo "claves del volcado de menús: $menuKeys (23) = $menuOk"
cp "$menuEn" "$textDir/lang/es_menu.txt"
dumpmenu --game-opt language=es --game-dir "$textDir"
menuRound=$(b2i [ "$(sha "$out/alttp_menu_es.txt")" = "$(sha "$menuEn")" ])
echo "ida y vuelta de es_menu.txt = volcado: idéntica = $menuRound"
# capturas de las dos pantallas (selección de partida en el fotograma 1300, registro de nombre en el 1530)
toMenus=(--press START@1100-1110 --press A@1300-1305 --press A@1500-1504)
menushot() {
    local name=$1 frames=$2; shift 2
    local d=$out/menu_$name
    mkdir -p "$d"
    hl "menu $name" "$H" "$textRom" --frames "$frames" --frame-blocks 20000 --dump "$d" --screenshot "$d/shot.png" "${toMenus[@]}" "$@"
}
es=(--game-opt language=es --game-dir "$textDir")
menuSame=1
for s in "sel 1300" "name 1530"; do
    set -- $s
    menushot "$1_en" "$2"
    menushot "$1_es" "$2" "${es[@]}"
    [ "$(sha "$out/menu_$1_en/shot.png")" = "$(sha "$out/menu_$1_es/shot.png")" ] || menuSame=0
done
echo "pantallas de menú idénticas con language=en y language=es (es_menu.txt = volcado) = $menuSame"
# cambiar una cadena cambia solo su sitio: unos pocos bytes del mapa de BG3 (VRAM $C000-$CFFF)
sed 's/select.copy = COPY  PLAYER/select.copy = COPIAR/' "$menuEn" >"$textDir/lang/es_menu.txt"
menushot sel_en 1300
menushot sel_edit 1300 "${es[@]}"
menuEdit=$("${EVAL[@]}" vramdiff "$out/menu_sel_en/vram.bin" "$out/menu_sel_edit/vram.bin")
echo "cambiar select.copy cambia bytes del mapa de BG3 (1 a 48) = $menuEdit"
# traducido todo, la partida es la misma: la WRAM (que lleva el nombre) a los 2040 fotogramas no cambia
sed -e 's/select.title = PLAYER  SELECT/select.title = ELEGIR PARTIDA/' \
    -e 's/name.title =  REGISTER  YOUR  NAME/name.title = REGISTRA TU NOMBRE/' \
    -e 's/name.end = END/name.end = FIN/' "$menuEn" >"$textDir/lang/es_menu.txt"
mkdir -p "$out/menu_game_en" "$out/menu_game_es"
hl "partida en" "$H" "$textRom" --frames 2040 --frame-blocks 20000 --dump "$out/menu_game_en" "${toMessage[@]}"
hl "partida es" "$H" "$textRom" --frames 2040 --frame-blocks 20000 --dump "$out/menu_game_es" "${toMessage[@]}" "${es[@]}"
menuGame=$(b2i cmp -s "$out/menu_game_en/wram.bin" "$out/menu_game_es/wram.bin")
echo "la WRAM del juego no cambia con los menús traducidos = $menuGame"

# skip_intro: Start en el fotograma 300 (en plena intro, módulo $10 = 0) lleva a la selección de partida (módulo 1) con la opción y no hace
# nada sin ella; la pantalla a los 1300 fotogramas es idéntica a la de esperar a la intro (Start en el título, fotograma 900)
introRun() {
    local name=$1 frames=$2; shift 2
    local d=$out/intro_$name
    mkdir -p "$d"
    hl "intro $name" "$H" "$textRom" --frames "$frames" --frame-blocks 20000 --dump "$d" --screenshot "$d/shot.png" "$@"
}
introRun off 400 --press START@300-308 --game-opt skip_intro=0
introRun on 400 --press START@300-308 --game-opt skip_intro=1
introRun onA 400 --press A@300-308 --game-opt skip_intro=1
introRun wait 1300 --press START@900-908
introRun skip 1300 --press START@300-308 --game-opt skip_intro=1
introOk=$(b2i test "$("${EVAL[@]}" byte "$out/intro_off/wram.bin" 0x10)" = 0 -a "$("${EVAL[@]}" byte "$out/intro_on/wram.bin" 0x10)" = 1 \
    -a "$("${EVAL[@]}" byte "$out/intro_onA/wram.bin" 0x10)" = 1 -a "$(sha "$out/intro_wait/shot.png")" = "$(sha "$out/intro_skip/shot.png")")
echo "skip_intro: sin la opción la intro sigue, con Start o A va a la selección de partida y la pantalla es la misma = $introOk"

# mejoras de calidad (games/alttp_usa/quality.c): partida nueva hasta que Link se maneja en su casa (fotograma 5200) y, con las
# escrituras en la WRAM, comprobar cada opción (en check_eval.py). Con --trace-frames y --watch el motor lista cada cambio de una dirección.
toControl=("${toMessage[@]}")
for ((f = 2100; f < 5200; f += 50)); do toControl+=(--press "A@$f-$((f + 3))"); done
# Las partidas son independientes: se lanzan en paralelo (tantas como núcleos) y se recogen todas al final.
jobsMax=$(nproc 2>/dev/null || echo 2)
launch() {
    local name=$1 frames=$2; shift 2
    local d=$out/q_$name
    mkdir -p "$d"
    while (($(jobs -rp | wc -l) >= jobsMax)); do wait -n; done
    ( "$HF" "$textRom" --frames "$frames" --frame-blocks 20000 --dump "$d" "${toControl[@]}" "$@" >"$d/log.txt" 2>"$d/err.txt"; echo $? >"$d/rc" ) &
}

# max_yellow: los dígitos de un contador al máximo pasan de la paleta 1 a la 5
allMax=(--poke 0F360=E703E703@5250 --poke 0F343=0A@5250 --poke 0F377=1E@5250)
someMax=(--poke 0F360=F401F401@5250 --poke 0F343=0A@5250 --poke 0F377=1E@5250)
launch y_off 5400 "${allMax[@]}" --game-opt max_yellow=0
launch y_on 5400 "${allMax[@]}" --game-opt max_yellow=1
launch y_part 5400 "${someMax[@]}" --game-opt max_yellow=1

# low_hp_beep: con un corazón ($F36D = 8) el juego escribe el efecto $2B en $012E cada 32 fotogramas
launch b_on 5400 --watch 012E --trace-frames 5260-5400 --game-opt low_hp_beep=1 --poke 0F36D=08@5250
launch b_off 5400 --watch 012E --trace-frames 5260-5400 --game-opt low_hp_beep=0 --poke 0F36D=08@5250
launch b_full 5400 --watch 012E --trace-frames 5260-5400 --game-opt low_hp_beep=1

# dash_turn: con las botas se corre con A; pulsar arriba en plena carrera a la derecha (fotograma 6031)
for opt in 0 1; do
    launch "dash$opt" 6150 --poke 0F355=01@5250 --poke 0F379=FF@5250 --watch 05D --watch 02F --trace-frames 5950-6150 \
        --press A@5900-5904 --press A+RIGHT@6000-6030 --press A+UP@6031-6062 --game-opt "dash_turn=$opt"
done

# item_switch_lr: arco, bumerán y gancho, arco elegido; R en 5300, 5320 y 5340 y L en 5360
for opt in 0 1; do
    launch "sw$opt" 5450 --poke 0F340=010101@5250 --poke 00202=01@5250 --watch 00202 --watch 00303 --trace-frames 5250-5450 \
        --press R@5300-5302 --press R@5320-5322 --press R@5340-5342 --press L@5360-5362 --game-opt "item_switch_lr=$opt"
done

# bird_cancel: la flauta lleva al mapa y B cancela (con la opción Link vuelve al mismo área)
for opt in 0 1; do
    launch "bird$opt" 7300 --game-opt item_switch_lr=1 --game-opt "bird_cancel=$opt" --poke 0F34C=03@5250 --poke 00202=0C@5250 --poke 0F3C5=03@5250 \
        --press RIGHT@5300-5330 --press LEFT@5340-5350 --press DOWN@5360-6000 --press A@6100-6103 --press A@6150-6153 \
        --press A@6200-6203 --press A@6250-6253 --press R@6400-6402 --press Y@6500-6503 --press B@6900-6903 \
        --press RIGHT@7100-7130
done

# rupees_9999: tope de rupias y cuatro dígitos en el marcador
launch rup_on 5800 --poke 0F360=C409@5250 --game-opt rupees_9999=1
launch rup_big 5800 --poke 0F360=204E@5250 --game-opt rupees_9999=1 --game-opt max_yellow=1
launch rup_off 6400 --poke 0F360=C409@5250 --game-opt rupees_9999=0

# sword_pickup: el espadazo recoge una rupia fuera del alcance del cuerpo de Link
swordBase=(--poke 0F359=01@5250 --poke 0F379=FF@5250 --poke 0F3C5=02@5250 --poke 00DDF=09@5300 --poke 00E2F=D9@5300
    --poke 00D0F=64@5300 --poke 00D2F=21@5300 --poke 00D3F=09@5300)
for opt in 0 1; do
    launch "pick$opt" 5400 "${swordBase[@]}" --poke 00D1F=6F@5300 --press B@5310-5313 --game-opt "sword_pickup=$opt"
done
launch touch0 5400 "${swordBase[@]}" --poke 00D1F=5B@5300 --game-opt sword_pickup=0

# sword_pots: un espadazo rompe la vasija que alcanza
for opt in 0 1; do
    launch "pot$opt" 5580 --poke 0F359=01@5250 --poke 0F379=FF@5250 --poke 0F3C5=02@5250 --press DOWN@5300-5335 \
        --press LEFT@5340-5420 --press UP@5430-5460 --press B@5480-5483 --game-opt "sword_pots=$opt"
done

# more_bombs: cuatro bombas a la vez, cada una gastando una
for opt in 0 1; do
    launch "bomb$opt" 5360 --poke 0F343=0A@5250 --poke 00202=04@5250 --poke 00303=01@5250 --poke 00C4A=00@5299 \
        --press Y@5300-5301 --press Y@5310-5311 --press Y@5320-5321 --press Y@5330-5331 --press Y@5340-5341 --press Y@5350-5351 \
        --game-opt "more_bombs=$opt"
done
# fix_portal_chime: Link sale de casa (fotograma 5500), se le pone mirando abajo en y = $0B58, x = $0989 de la pantalla $2F y se pone un arbusto
# ($0036) en la posición de secreto $0BB2, donde esa pantalla tiene el secreto $82 (un portal). A en el 5600 lo levanta y 1B:C8A4 busca el secreto.
# Con el bit 2 de $F2AF (la pantalla ya "vista") el original no pide el sonido $1B en $012F; la opción sí. Sin el bit suena igual con las dos.
for bit in 00 02; do
    for opt in 0 1; do
        launch "portal$bit$opt" 5700 --watch 012F --trace-frames 5500-5700 --press RIGHT@5300-5330 --press LEFT@5340-5350 --press DOWN@5360-5500 \
            --poke 00020=580B@5520 --poke 00022=8909@5520 --poke 0008A=2F@5520 --poke 02BB2=3600@5520 --poke "0F2AF=$bit@5520" \
            --press A@5600-5603 --game-opt "fix_portal_chime=$opt"
    done
done
# fix_death_count: con la historia avanzada ($F3C5 = 3) y Link con 4 de vida ($F36D) un daño de $10 ($0373) lo mata en el fotograma 5300 y sale la
# pantalla de fin de partida (módulo $12). Con A en el 5800 se confirma la opción de $B0: 0 guardar y continuar, 2 (dos veces abajo) continuar sin
# guardar. El contador de muertes ($F403) pasa a 1 en el 5801; con la opción y $B0 = 2 vuelve a 0, y con $B0 = 0 se queda en 1 con las dos.
for choice in 0 2; do
    downs=()
    [ "$choice" = 2 ] && downs=(--press DOWN@5700-5702 --press DOWN@5730-5732)
    for opt in 0 1; do
        launch "death$choice$opt" 5900 --poke 0F3C5=03@5250 --poke 0F36D=04@5300 --poke 00373=10@5300 "${downs[@]}" \
            --press A@5800-5803 --game-opt "fix_death_count=$opt"
    done
done
# fix_medallion_abort: con la espada ($F359 = 1, $F379, $F3C5), Bombos ($F347), magia llena ($F36E), Bombos elegido en Y (ranura 8 en $0202, objeto $0F
# en $0303) y el espacio de efectos libre ($0C4A = 0), B se mantiene del fotograma 5300 al 5390 (la espada se carga: $3C llega a 9) y Y se pulsa en
# el 5391, cuando B se suelta. Bombos empieza ($5D = 9) y el original lo aborta en el mismo fotograma con el espadazo giratorio ($5D = 3, magia
# gastada, y luego el giro acaba y $5D vuelve a 0); con la opción $5D sigue en 9 al fotograma 5600.
for opt in 0 1; do
    launch "med$opt" 5600 --poke 0F359=01@5250 --poke 0F379=FF@5250 --poke 0F3C5=02@5250 --poke 0F347=01@5250 --poke 0F36E=80@5250 \
        --poke 00202=08@5250 --poke 00303=0F@5250 --poke 00C4A=00@5290 --watch 05D --trace-frames 5250-5600 \
        --press B@5300-5390 --press Y@5391-5393 --game-opt "fix_medallion_abort=$opt"
done
# fix_magic_refund: la devolución de magia (07:B0E9) con la función de quality.c sola (scripts/test_refund.c, tabla de costes de la ROM): sin la
# opción la magia pasa de 128 y con ella se queda en 128; por debajo del tope las dos dan lo mismo
awk '/^void alttp_magic_refund/,/^}/' games/alttp_usa/quality.c >"$out/refund_body.c"
$CC -O1 -DBODY='"'"$out"'/refund_body.c"' -o "$out/test_refund" scripts/test_refund.c || die "no compila scripts/test_refund.c"
refund=$("$out/test_refund" "$ROM" 2>&1); refundRc=$?
echo "$refund" | sed 's/^/    /'
echo "fix_magic_refund: la función sola limita la magia a 128 con la opción y no cambia nada por debajo del tope = $(b2i test $refundRc = 0)"
[ "$refundRc" = 0 ] || fail "fix_magic_refund: la función sola no limita la magia a 128"
# fix_somaria_nomagic: con el bastón de Somaria ($F350, ranura 17 en $0202, objeto $12 en $0303) y sin magia, Y en el fotograma 5300 deja el bit 6
# de $3A puesto (como si el objeto estuviera en uso); con la opción el bit se limpia al salir de 07:AEC0
for opt in 0 1; do
    launch "som$opt" 5500 --poke 0F350=01@5250 --poke 0F36E=00@5250 --poke 00202=11@5250 --poke 00303=12@5250 \
        --watch 03A --trace-frames 5250-5500 --press Y@5300-5302 --game-opt "fix_somaria_nomagic=$opt"
done
# arreglos pequeños (fix_moldorm_sound, fix_swamola_bank, fix_kiki_bomb, fix_bunny_palette): la lógica de sus ganchos con scripts/test_hooks.c
# (no se prueba que el juego llegue a esas rutinas, solo lo que el gancho hace cuando llegan)
awk '/^static uint8_t moldorm_in_46/,0' games/alttp_usa/quality.c >"$out/hooks_body.c"
$CC -O1 -DBODY='"'"$out"'/hooks_body.c"' -o "$out/test_hooks" scripts/test_hooks.c || die "no compila scripts/test_hooks.c"
hooks=$("$out/test_hooks" 2>&1); hooksRc=$?
echo "$hooks"
echo "arreglos pequeños: lógica de los ganchos = $(b2i test $hooksRc = 0)"
[ "$hooksRc" = 0 ] || fail "arreglos pequeños: la lógica de algún gancho no es la esperada"
# rupee_fast: el marcador ($F362) sigue a la cartera ($F360) de una en una; con la opción, 1/16 de la diferencia por fotograma. Se pone la cartera a 500
# ($F360 = $01F4) en el fotograma 5300 (subida) o, con las dos a 500 desde el 5250, a 0 (bajada); a los 150 fotogramas el marcador va por 150 o 350 sin la
# opción y ya ha llegado con ella; la cartera no cambia.
for opt in 0 1; do
    launch "rfu$opt" 5450 --poke 0F360=F401@5300 --game-opt "rupee_fast=$opt"
    launch "rfd$opt" 5450 --poke 0F360=F401F401@5250 --poke 0F360=0000@5300 --game-opt "rupee_fast=$opt"
done
# volumen separado de música y efectos: Link sale de su casa bajo la lluvia (efectos: lluvia, SFX) con la música sonando. 100/100 deja el sonido como
# estaba, apagar la música o los efectos lo baja sin dejarlo mudo, y apagar los dos lo deja en silencio (el motor sabe qué voces son efectos por
# [audio] sfx_voice_mask del perfil)
volIn=(--press START@1100-1110 --press A@1300-1305 --press A@1500-1504 --press DOWN@1540-1542 --press DOWN@1560-1562 --press DOWN@1580-1582
    --press RIGHT@1600-1602 --press RIGHT@1620-1622 --press A@1640-1643)
for f in $(seq 2000 90 3900); do volIn+=(--press "A@$f-$((f+3))"); done
volIn+=(--press RIGHT@4050-4093 --press DOWN@4100-5400)
mkdir -p "$out/vol"
volRun() { local n=$1; shift; "$HF" "$ROM" --frames 6200 --frame-blocks 20000 "${volIn[@]}" --wav "$out/vol/$n.wav" "$@" >/dev/null 2>&1 & }
volRun base; volRun m0 --music-volume 0; volRun s0 --sfx-volume 0; volRun z --music-volume 0 --sfx-volume 0
wait
for rc in "$out"/q_*/rc; do
    [ "$(cat "$rc")" = 0 ] || die "headless_fast termino con codigo $(cat "$rc") ($(basename "$(dirname "$rc")"))"
done

volOut=$(python3 - "$out/vol" <<'PY'
import sys, wave, struct, math
def rms(n):
    w = wave.open(sys.argv[1] + "/" + n + ".wav"); d = w.readframes(w.getnframes()); s = struct.unpack("<%dh" % (len(d) // 2), d)
    return math.sqrt(sum(x * x for x in s) / max(1, len(s)))
b, m, e, z = (rms(n) for n in ("base", "m0", "s0", "z"))
print("base=%.1f sin_musica=%.1f sin_efectos=%.1f ambos_0=%.1f" % (b, m, e, z))
sys.exit(0 if b > 100 and 0 < m < b * 0.95 and 0 < e < b * 0.95 and z == 0 else 1)
PY
); volRc=$?
echo "volumen de música y efectos (RMS): $volOut = $(b2i test $volRc = 0)"
[ "$volRc" = 0 ] || fail "volumen separado: apagar la música o los efectos debe bajar el sonido sin dejarlo mudo, y apagar los dos dejarlo en silencio"

"${EVAL[@]}" quality "$out"
qualityOk=$?

need "$textOk" "el volcado debe tener 397 mensajes y la huella de siempre"
need "$roundTrip" "con es.txt igual al volcado, el texto debe salir idéntico"
need "$editOk" "cambiar una línea de es.txt debe cambiar solo ese mensaje"
need "$boxOk" "el primer cuadro de texto debe ser idéntico con language=en y language=es"
need "$menuOk" "el volcado de menús debe tener 23 claves"
need "$menuRound" "con es_menu.txt igual al volcado, el texto de los menús debe salir idéntico"
need "$menuSame" "las pantallas de menú deben ser idénticas con language=en y language=es (es_menu.txt = volcado)"
need "$menuEdit" "cambiar una cadena de menú debe cambiar solo su sitio en el mapa de BG3"
need "$menuGame" "traducir los menús no debe cambiar el estado de la partida"
need "$introOk" "con skip_intro=1 Start o A en plena intro deben llevar a la selección de partida, con la misma pantalla (y sin la opción no)"
need "$wideOk" "con --wide 32 en un interior las columnas extra deben ser negras (320 de ancho)"
[ "$plain" = 5 ] || fail "sin R deberian ser 5"
[ "$fast" -ge $((2 * plain)) ] || fail "con R deberian ser al menos el doble"
[ "$off" = "$plain" ] || fail "con dialog_skip=0, R no debe cambiar nada"
[ "$qualityOk" = 0 ] || ok=0

[ "$ok" = 1 ] || exit 1
echo "OK"
