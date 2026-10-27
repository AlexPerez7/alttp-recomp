/* A Link to the Past (USA): quality-of-life options that change one small thing of the original.
 *
 * Low-health beep: 0D:DB75 (the status bar update, once per frame) asks for sound effect $2B in $012E when the hearts are under the
 * threshold of the table at 0D:DB60, every 32 frames. alttp_hud_beep_enter notes what $012E held on entry and alttp_hud_beep_leave, before each
 * return, takes the $2B back if this call is the one that asked for it, so the sound engine never sees it. The other effects the
 * routine asks for ($29 and $2D) are not touched. Off with `--game-opt low_hp_beep=0`. */
#include "snes_rt.h"

#define SFX_LOW_HEALTH 0x2B

static uint8_t sfx_on_entry;

void alttp_hud_beep_enter(Cpu *c) {
    (void)c;
    sfx_on_entry = wram_read8(0x012E);
}

void alttp_hud_beep_leave(Cpu *c) {
    (void)c;
    if (game_opt("low_hp_beep", 1)) return;
    if (sfx_on_entry != SFX_LOW_HEALTH && wram_read8(0x012E) == SFX_LOW_HEALTH) wram_write8(0x012E, 0);
}

/* Maximum in yellow: 0D:FC09 writes the digits of the counters into the status bar buffer in WRAM (each entry is a tile of BG3 with
 * palette 1, $2400): rupees at $C750-$C754 (from $F362), bombs at $C758-$C75A (from $F343) and arrows at $C75E-$C760 (from $F377).
 * alttp_hud_max_yellow, before its return, gives the digits of a counter that is at its maximum palette 5, whose second colour
 * is pale yellow. The maximum of rupees is 999 and those of bombs and arrows are read from the tables of 0D:DB48 and 0D:DB58, the
 * same ones the refill code uses. On with `--game-opt max_yellow=1`. */
#define PAL_MAX 0x1400u
#define PAL_MASK 0x1C00u

static void paint(uint32_t first, int n) {
    int i;
    for (i = 0; i < n; i++) {
        uint32_t a = first + 2 * i;
        uint16_t t = (uint16_t)(wram_read8(a) | wram_read8(a + 1) << 8);
        t = (uint16_t)((t & ~PAL_MASK) | PAL_MAX);
        wram_write8(a, t & 0xFF);
        wram_write8(a + 1, t >> 8);
    }
}

void alttp_hud_max_yellow(Cpu *c) {
    (void)c;
    if (!game_opt("max_yellow", 0)) return;
    if ((wram_read8(0xF362) | wram_read8(0xF363) << 8) == 999) paint(0xC750, 3);
    if (wram_read8(0xF343) == bus_read8(0x0DDB48u + wram_read8(0xF370))) paint(0xC758, 2);
    if (wram_read8(0xF377) == bus_read8(0x0DDB58u + wram_read8(0xF371))) paint(0xC75E, 2);
}

/* Turn while dashing: 07:8F86 is the handler of the dash (state $11 of $5D) and runs once per frame. At 07:9114 it compares the d-pad
 * ($F0 & $0F: 8 up, 4 down, 2 left, 1 right) with the direction Link faces ($2F: 0 up, 2 down, 4 left, 6 right, in the table of
 * 07:8F61); a different direction ends the dash. alttp_dash_turn, on entry, changes $2F to the direction pressed when it is a single
 * different one (or the other half of a diagonal that has the one Link faces), so the handler sees nothing different and the dash goes on
 * the new way. On with `--game-opt dash_turn=1`. */
#define DASHING 0x11

void alttp_dash_turn(Cpu *c) {
    static const uint8_t dir[4] = { 0x08, 0x04, 0x02, 0x01 }; /* d-pad bit for $2F = 0, 2, 4, 6 */
    uint8_t pad, facing, n;
    (void)c;
    if (!game_opt("dash_turn", 0) || wram_read8(0x5D) != DASHING) return;
    pad = wram_read8(0xF0) & 0x0F;
    facing = dir[(wram_read8(0x2F) >> 1) & 3];
    if (!pad || pad == facing) return;
    if (pad & (pad - 1)) { /* a diagonal: keep only the half that is not the one Link faces */
        if (!(pad & facing)) return;
        pad &= ~facing;
        if (pad & (pad - 1)) return;
    }
    for (n = 0; n < 4; n++) if (dir[n] == pad) wram_write8(0x2F, n * 2);
}
