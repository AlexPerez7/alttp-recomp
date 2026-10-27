/* A Link to the Past (USA): hides what the game has not loaded in the extra columns of a wide picture (--wide / `wide`).
 *
 * 00:80B5 runs once per frame after the main loop waits for the NMI. Outdoors ($1B = 0) the horizontal scroll limits of
 * the area are in $0604 (left) and $0606 (right), and $E2 is the camera X: when the camera is closer to a limit than E,
 * the part of the extra columns past the edge of the area is drawn black. Indoors ($1B != 0) the room is a 512x512 tilemap
 * that wraps and has no neighbour, so all the extra columns are black. In the menus (modules 0 to 5) nothing is changed. */
#include "snes_rt.h"

void alttp_hud_poll(void); /* hud.c */

static int word(int a) { return wram_read8(a) | wram_read8(a + 1) << 8; }

void alttp_wide_fill(Cpu *c) {
    int e = ppu_wide(), left, right;
    (void)c;
    alttp_hud_poll();
    if (e == 0 || wram_read8(0x10) < 6) { ppu_wide_blank_clear(); return; }
    if (wram_read8(0x1B)) { ppu_wide_blank(e, e); return; }
    left = e - (word(0xE2) - word(0x0604));
    right = e - (word(0x0606) - word(0xE2));
    ppu_wide_blank(left > 0 ? left : 0, right > 0 ? right : 0);
}
