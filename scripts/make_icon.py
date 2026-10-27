"""Dibuja el icono de la ventana del juego (arte propio, ningún gráfico del juego) y escribe games/alttp_usa/icon.c.

    python scripts/make_icon.py

Necesita Pillow. El resultado se sube al repositorio, así que compilar no necesita Python. La gema es la del motor
(snes-recomp/scripts/make_icon.py) en verde, con un aro dorado.
"""
import pathlib
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
N = 1024  # se dibuja grande y se reduce, para que los bordes salgan suaves


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw(bg_top, bg_bottom, gem_light, gem_dark, gem_shine, ring=None):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    grad = Image.new("RGBA", (N, N))
    gd = ImageDraw.Draw(grad)
    for y in range(N):
        gd.line([(0, y), (N, y)], fill=lerp(bg_top, bg_bottom, y / N) + (255,))
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, N - 1, N - 1], radius=int(N * 0.22), fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    if ring:
        d.rounded_rectangle([N * 0.03, N * 0.03, N * 0.97, N * 0.97], radius=int(N * 0.19), outline=ring + (255,), width=int(N * 0.028))
    s = N / 256.0
    P = lambda x, y: (x * s, y * s)
    top, ur, lr, bot, ll, ul = P(128, 30), P(190, 88), P(190, 168), P(128, 226), P(66, 168), P(66, 88)
    mid_top, mid_bot = P(128, 88), P(128, 168)
    sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([P(x, y + 8) for x, y in [(128, 30), (190, 88), (190, 168), (128, 226), (66, 168), (66, 88)]], fill=(0, 0, 0, 90))
    img = Image.alpha_composite(img, sh)
    d = ImageDraw.Draw(img)
    d.polygon([top, ur, lr, bot, ll, ul], fill=gem_dark + (255,))
    d.polygon([top, mid_top, mid_bot, bot, ll, ul], fill=gem_light + (255,))
    d.polygon([top, ur, mid_top], fill=lerp(gem_light, gem_shine, 0.6) + (255,))
    d.polygon([top, mid_top, ul], fill=gem_shine + (255,))
    edge = lerp(gem_dark, (0, 0, 0), 0.35)
    d.line([top, ur, lr, bot, ll, ul, top], fill=edge + (255,), width=int(N * 0.012), joint="curve")
    d.line([mid_top, mid_bot], fill=edge + (255,), width=int(N * 0.008))
    return img


def write_c(img, path, size=64):
    px = img.resize((size, size), Image.LANCZOS).convert("RGBA").load()
    rows = ["    " + ",".join("0x%08X" % ((px[x, y][3] << 24) | (px[x, y][0] << 16) | (px[x, y][1] << 8) | px[x, y][2]) for x in range(size)) + "," for y in range(size)]
    text = (
        "/* A Link to the Past (USA): el icono de la ventana (barra de tareas y título). Arte propio, dibujado por scripts/make_icon.py;\n"
        " * no lleva ningún gráfico del juego. Se pone una vez, en cuanto el juego corre (alttp_wide_fill lo llama cada fotograma). */\n"
        '#include "snes_rt.h"\n\n'
        "#define ICON_SIZE %d\n"
        "static const unsigned icon[ICON_SIZE * ICON_SIZE] = {\n%s\n};\n\n"
        "void alttp_window_icon(void) {\n"
        "    static int done;\n"
        "    if (done) return;\n"
        "    done = 1;\n"
        "    snes_set_window_icon(icon, ICON_SIZE, ICON_SIZE);\n"
        "}\n"
    ) % (size, "\n".join(rows))
    path.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    icon = draw((0x1A, 0x46, 0x2C), (0x08, 0x20, 0x14), (0x62, 0xE0, 0x7E), (0x1F, 0x9A, 0x45), (0xC8, 0xFA, 0xD2), ring=(0xF2, 0xC1, 0x4E))
    write_c(icon, ROOT / "games" / "alttp_usa" / "icon.c")
    if (ROOT / "out").is_dir():
        icon.resize((256, 256), Image.LANCZOS).save(ROOT / "out" / "icon_preview.png")
    print("escrito")
