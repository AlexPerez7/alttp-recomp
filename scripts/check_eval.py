"""Comprobaciones de datos de scripts/check.sh (equivalen a las de check.ps1). Se llama con `python3 -I`.

  byte FICHERO DIR                 imprime el byte en esa dirección (decimal o 0x..)
  wide PNG                         imprime 1 si mide 320 de ancho y las 32 columnas extra de cada lado son negras
  vramdiff A B                     imprime 1 si cambian de 1 a 48 bytes y todos dentro de $C000-$CFFF
  quality OUT                      evalúa las partidas out/q_*; imprime cada resultado y sale con 1 si alguno falla
"""
import re
import sys
from pathlib import Path


def w8(w, a):
    return w[a]


def w16(w, a):
    return w[a] + 256 * w[a + 1]


def cmd_byte(path, addr):
    print(Path(path).read_bytes()[int(addr, 0)])


def cmd_wide(path):
    from PIL import Image

    im = Image.open(path).convert("RGB")
    ok = im.width == 320
    if ok:
        for x in list(range(0, 32)) + list(range(288, 320)):
            for y in (40, 100, 160):
                if im.getpixel((x, y)) != (0, 0, 0):
                    ok = False
    print(1 if ok else 0)


def cmd_vramdiff(a, b):
    va, vb = Path(a).read_bytes(), Path(b).read_bytes()
    changed = [i for i in range(min(len(va), len(vb))) if va[i] != vb[i]]
    ok = 0 < len(changed) <= 48 and all(0xC000 <= i < 0xD000 for i in changed)
    print(1 if ok else 0)


WRITE = re.compile(r"frame (\d+) block \S+ wram ([0-9A-F]+): ([0-9A-F]{2}) -> ([0-9A-F]{2})")


class Run:
    def __init__(self, out, name):
        d = Path(out) / f"q_{name}"
        self.wram = (d / "wram.bin").read_bytes()
        self.writes = []
        for f in ("log.txt", "err.txt"):
            for line in (d / f).read_text(errors="replace").splitlines():
                m = WRITE.search(line)
                if m:
                    self.writes.append((int(m[1]), int(m[2], 16), m[3], m[4]))  # fotograma, dirección, antes, después

    def at(self, addr):
        return [w for w in self.writes if w[1] == addr]


def pal(w, start, n):
    return ",".join(str((w[start + 2 * i + 1] & 0x1C) >> 2) for i in range(n))


def counters(w):
    return " ".join((pal(w, 0xC750, 3), pal(w, 0xC758, 2), pal(w, 0xC75E, 2)))


def cmd_quality(out):
    ok = True

    def report(good, text, error):
        nonlocal ok
        print(f"{text} -> {good}")
        if not good:
            print(f"error: {error}", file=sys.stderr)
            ok = False

    R = lambda n: Run(out, n)

    # max_yellow
    y_off, y_on, y_part = (counters(R(n).wram) for n in ("y_off", "y_on", "y_part"))
    report(
        y_off == "1,1,1 1,1 1,1" and y_on == "5,5,5 5,5 5,5" and y_part == "1,1,1 5,5 5,5",
        f"max_yellow: paletas (rupias bombas flechas) apagado = {y_off}, activo = {y_on}, con 500 rupias = {y_part}",
        "max_yellow=1 debe pasar a la paleta 5 solo los contadores al máximo, y =0 no debe cambiar nada",
    )

    # low_hp_beep
    b_on, b_off, b_full = (R(n).at(0x12E) for n in ("b_on", "b_off", "b_full"))
    set_on = [w for w in b_on if w[3] == "2B"]
    clr_on = [w for w in b_on if w[2] == "2B"]
    set_off = [w for w in b_off if w[3] == "2B"]
    clr_off = [w for w in b_off if w[2] == "2B"]
    beep_on = len(set_on) >= 4 and len(set_on) == len(clr_on) and all(c[0] > s[0] for s, c in zip(set_on, clr_on))
    beep_off = len(set_off) == len(set_on) and len(clr_off) == len(set_off) and all(c[0] == s[0] for s, c in zip(set_off, clr_off))
    others = lambda ws: len([w for w in ws if w[3] != "2B" and w[2] != "2B"])
    report(beep_on, f"low_hp_beep: con poca vida el $2B se pide {len(set_on)} veces y dura un fotograma",
           "con poca vida y low_hp_beep=1 el efecto $2B debe pedirse y quedar un fotograma (como siempre)")
    report(beep_off, "low_hp_beep: con la opción en 0 se borra en el mismo fotograma",
           "con low_hp_beep=0 el efecto $2B debe borrarse en el mismo fotograma en que se pide")
    report(len(b_full) == 0, "low_hp_beep: con la vida llena no hay nada", "con la vida llena no debe haber ningún $2B")
    report(others(b_on) == others(b_off), "low_hp_beep: los demás efectos no cambian", "low_hp_beep no debe tocar los demás efectos de sonido")

    # dash_turn
    d0, d1 = R("dash0").writes, R("dash1").writes
    first = lambda ws, pred: next((w for w in ws if pred(w)), None)
    run0 = first(d0, lambda w: w[1] == 0x5D and w[3] == "11")
    end0 = first(d0, lambda w: w[1] == 0x5D and w[2] == "11")
    end1 = first(d1, lambda w: w[1] == 0x5D and w[2] == "11")
    turn1 = first(d1, lambda w: w[1] == 0x2F)
    dash_ok = None not in (run0, end0, end1, turn1) and end0[0] <= 6033 and turn1[3] == "00" and turn1[0] <= 6033 and end1[0] >= turn1[0] + 3
    report(dash_ok, f"dash_turn: carrera en {run0 and run0[0]}; sin la opción acaba en {end0 and end0[0]}; con ella Link gira en {turn1 and turn1[0]} y acaba en {end1 and end1[0]}",
           "con dash_turn=1 pulsar otra dirección en plena carrera debe girar a Link sin cortarla (y sin la opción la corta)")

    # item_switch_lr
    sw0 = [w for w in R("sw0").writes if w[0] > 5250]
    sw1 = [w for w in R("sw1").writes if w[0] > 5250]
    slots = ",".join(w[3] for w in sw1 if w[1] == 0x202)
    items = len([w for w in sw1 if w[1] == 0x303])
    report(len(sw0) == 0 and slots == "02,03,01,03" and items >= 4,
           f"item_switch_lr: sin la opción {len(sw0)} escrituras; con ella la ranura pasa por {slots} y $0303 cambia {items} veces",
           "con item_switch_lr=1 L y R deben cambiar el objeto elegido saltando las ranuras vacías (y sin la opción no deben hacer nada)")

    # bird_cancel
    link = lambda w: dict(module=w[0x10], sub=w[0x11], area=w[0x8A], x=w16(w, 0x22), y=w16(w, 0x20))
    l0, l1 = link(R("bird0").wram), link(R("bird1").wram)
    report(l1["module"] == 9 and l1["sub"] == 0 and l1["area"] == 0x34 and l1["x"] > 2256 and l0["area"] != 0x34,
           f"bird_cancel: con la opción área ${l1['area']:02X} (módulo {l1['module']}) y x = {l1['x']}; sin ella área ${l0['area']:02X}",
           "con bird_cancel=1 B en la elección de destino de la flauta debe volver al mismo sitio (y sin la opción, elegir destino)")

    # rupees_9999
    digits = lambda w: " ".join(f"{w16(w, 0xC74E + 2 * i):04X}" for i in range(4))
    ro, rb, rf = (R(n).wram for n in ("rup_on", "rup_big", "rup_off"))
    rup_ok = (w16(ro, 0xF360) == 2500 and w16(ro, 0xF362) == 2500 and digits(ro) == "2492 2495 2490 2490"
              and w16(rb, 0xF360) == 9999 and w16(rb, 0xF362) == 9999 and digits(rb) == "3499 3499 3499 3499"
              and w16(rf, 0xF360) == 999 and w16(rf, 0xF362) == 999)
    report(rup_ok, f"rupees_9999: con 2500 el marcador llega a {w16(ro, 0xF362)} ({digits(ro)}); con 20000 {w16(rb, 0xF362)} ({digits(rb)}); sin la opción {w16(rf, 0xF360)}",
           "con rupees_9999=1 el tope debe ser 9999 con cuatro dígitos en el marcador (y 999 sin la opción)")

    # sword_pickup
    p0, p1, t0 = (R(n).wram for n in ("pick0", "pick1", "touch0"))
    pick_ok = (w16(p0, 0xF360) == 0 and p0[0xDDF] == 9 and w16(p1, 0xF360) == 1 and p1[0xDDF] == 0
               and w16(t0, 0xF360) == 1 and t0[0xDDF] == 0)
    report(pick_ok, f"sword_pickup: sin la opción {w16(p0, 0xF360)} rupias, con ella {w16(p1, 0xF360)}; tocándola sin espada {w16(t0, 0xF360)}",
           "con sword_pickup=1 el espadazo debe recoger un objeto fuera del alcance del cuerpo (sin la opción no) y tocarlo debe seguir recogiéndolo")

    # sword_pots
    def pot(w):
        attrs = " ".join(f"{w[0x12000 + r * 64 + 37]:02X}" for r in (43, 45, 47))
        shards = len([i for i in range(16) if w[0xE20 + i] == 0xEC])
        return attrs, shards, w[0x10], w[0x11]

    q0, q1 = pot(R("pot0").wram), pot(R("pot1").wram)
    report(q0[0] == "70 71 72" and q0[1] == 0 and q1[0] == "70 71 00" and q1[1] >= 1 and q1[2] == 7 and q1[3] == 0,
           f"sword_pots: baldosas sin la opción {q0[0]}, con ella {q1[0]} y {q1[1]} sprite(s) de vasija rota",
           "con sword_pots=1 un espadazo en mazmorra debe romper la vasija que alcanza (y sin la opción no)")

    # more_bombs
    def bombs(w):
        return len([i for i in range(5) if w[0xC4A + i] == 7]), w[0xF343]

    m0, m1 = bombs(R("bomb0").wram), bombs(R("bomb1").wram)
    report(m0 == (2, 8) and m1 == (4, 6),
           f"more_bombs: bombas a la vez sin la opción {m0[0]} (quedan {m0[1]} de 10), con ella {m1[0]} (quedan {m1[1]})",
           "con more_bombs=1 deben poder estar cuatro bombas a la vez, cada una gastando una (y sin la opción dos)")

    # fix_portal_chime
    def chimes(n):
        return len([w for w in R(n).at(0x12F) if w[2] == "00" and w[3] == "1B"])

    pc = {n: chimes(n) for n in ("portal000", "portal001", "portal020", "portal021")}
    report(pc == {"portal000": 1, "portal001": 1, "portal020": 0, "portal021": 1},
           f"fix_portal_chime: sonidos al levantar la roca sin el bit 2: {pc['portal000']} y {pc['portal001']}; con él: {pc['portal020']} sin la opción y {pc['portal021']} con ella",
           "con fix_portal_chime=1 la roca del portal ($82) debe sonar aunque la pantalla ya esté vista (y sin la opción no); sin el bit debe sonar igual con las dos")

    # fix_death_count
    dc = {n: R(n).wram[0xF403] | R(n).wram[0xF404] << 8 for n in ("death00", "death01", "death20", "death21")}
    report(dc == {"death00": 1, "death01": 1, "death20": 1, "death21": 0},
           f"fix_death_count: muertes con guardar y continuar {dc['death00']} sin la opción y {dc['death01']} con ella; con continuar sin guardar {dc['death20']} y {dc['death21']}",
           "con fix_death_count=1 continuar sin guardar no debe contar la muerte (y sin la opción sí); guardar y continuar la cuenta siempre")

    sys.exit(0 if ok else 1)


def main():
    cmd, args = sys.argv[1], sys.argv[2:]
    {"byte": cmd_byte, "wide": cmd_wide, "vramdiff": cmd_vramdiff, "quality": cmd_quality}[cmd](*args)


if __name__ == "__main__":
    main()
