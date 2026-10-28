/* A Link to the Past (USA): quality-of-life options that change one small thing of the original.
 *
 * Low-health beep: 0D:DB75 (the status bar update, once per frame) asks for sound effect $2B in $012E when the hearts are under the
 * threshold of the table at 0D:DB60, every 32 frames. alttp_hud_beep_enter notes what $012E held on entry and alttp_hud_beep_leave, before each
 * return, takes the $2B back if this call is the one that asked for it, so the sound engine never sees it. The other effects the
 * routine asks for ($29 and $2D) are not touched. Off with `--game-opt low_hp_beep=0`. */
#include "snes_rt.h"
#include "snes_funcs.h"

#define SFX_LOW_HEALTH 0x2B

static uint8_t sfx_on_entry;

static void item_switch(Cpu *c);

void alttp_hud_beep_enter(Cpu *c) {
    item_switch(c);
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

/* Item switch with L/R: the menu keeps the chosen item in $0202 (slot 1-20; the item owned in a slot is non-zero at $F33F + slot) and, when
 * it closes, copies the item that Y uses to $0303 from the table at 0D:FA15 and redraws the box of the status bar (0D:FA85). The status bar
 * routine (0D:DB75) runs once per frame; item_switch, called from the entry hook of that routine (alttp_hud_beep_enter), does the same on its own when L or R is newly pressed ($F6 bit 5 and 4)
 * while Link moves freely in the underworld or the overworld ($10 = 7 or 9, $11 = 0, $5D = 0): it goes to the previous or next slot that
 * has an item, wrapping around, as the menu does. On with `--game-opt item_switch_lr=1`. */
#define SLOT_COUNT 20
#define PAD_L 0x20
#define PAD_R 0x10

static void item_switch(Cpu *c) {
    uint8_t pressed = wram_read8(0xF6) & (PAD_L | PAD_R), mod = wram_read8(0x10), slot = wram_read8(0x0202);
    int step, n;
    if (!game_opt("item_switch_lr", 0) || !slot || pressed == (PAD_L | PAD_R) || !pressed) return;
    if ((mod != 7 && mod != 9) || wram_read8(0x11) || wram_read8(0x5D)) return;
    step = (pressed == PAD_R) ? 1 : SLOT_COUNT - 1;
    for (n = 0; n < SLOT_COUNT - 1; n++) {
        slot = (uint8_t)((slot - 1 + step) % SLOT_COUNT + 1);
        if (wram_read8(0xF33F + slot)) {
            Cpu k = *c;
            wram_write8(0x0202, slot);
            wram_write8(0x0303, bus_read8(0x0DFA15u + slot));
            k.d = 0;
            k.e = 0;
            k.ret = RT_NO_RET;
            f_0D_FA85(&k); /* redraws the item box and asks for its upload */
            return;
        }
    }
}

/* Cancel the bird trip: after playing the flute outdoors, the bird carries Link off and the game shows the map (module $0E, submodule $0A,
 * whose steps run through the table of 0A:B730 with $0200 as the index). Step 5 (0A:B78B) waits for a destination ($1AF0, 0 to 7) and any of
 * A, X, B or Y takes it; step 6 draws the map away, step 7 (0A:B8C5) calls 02:EC39 to place Link and the scroll at the destination from the
 * tables at 02:EAE5-02:EC17, loads the area and, after two more steps (0A:B964, 0A:B96C), the bird sets Link down.
 * alttp_bird_cancel, on entry to step 5, takes B as the cancel button: it removes A, X, B and Y from what the step sees, goes to step 6 itself
 * and remembers that the trip is cancelled. alttp_bird_land replaces 02:EC39: its table part is the same as the original and runs for a
 * destination, but for a cancelled trip it leaves Link, the scroll and the area as they were (the map restored them in step 6), so the rest of
 * the steps load the area Link was in and the bird sets him down where he took off. Link's position and the area are the same in both, so
 * the second part (sprites, Link's state) is the original code, called from here. On with `--game-opt bird_cancel=1`. */
static uint8_t bird_cancelled;

void alttp_bird_cancel(Cpu *c) {
    (void)c;
    if (!game_opt("bird_cancel", 0) || wram_read8(0xC8)) return;
    if (wram_read8(0xF4) & 0x80) {
        bird_cancelled = 1;
        wram_write8(0x0200, 6);
    }
    wram_write8(0xF0, wram_read8(0xF0) & 0x3F);
    wram_write8(0xF2, wram_read8(0xF2) & 0x3F);
}

static uint16_t tab(uint32_t base, uint8_t x) { return (uint16_t)bus_read16(0x020000u + base + x); }
static void put(uint32_t a, uint16_t v) { bus_write16(a, v); }

void alttp_bird_land(Cpu *c) {
    uint16_t s0, v;
    put(0x04AC, 0);
    rt_rep(c, 0x20);
    if (!bird_cancelled) {
        uint8_t x;
        v = (uint16_t)(bus_read16(0x1AF0) << 1);
        put(0x1AF0, v);
        x = (uint8_t)v;
        v = tab(0xEB29, x); put(0xE6, v); put(0xE8, v); put(0x0122, v); put(0x0124, v);
        v = tab(0xEB4B, x); put(0xE0, v); put(0xE2, v); put(0x011E, v); put(0x0120, v);
        put(0x20, tab(0xEB6D, x));
        put(0x22, tab(0xEB8F, x));
        v = tab(0xEBF5, x); put(0x0624, v); put(0x0626, (uint16_t)(0 - v));
        v = tab(0xEC17, x); put(0x0628, v); put(0x062A, (uint16_t)(0 - v));
        v = tab(0xEAE5, x); put(0x8A, v); put(0x040A, v);
        v = tab(0xEB07, x); put(0x84, v);
        v = (uint16_t)(((v - 0x0400) & 0x0F80) << 1);
        put(0x88, (uint16_t)(v >> 8 | v << 8));
        put(0x86, (uint16_t)(((bus_read16(0x84) - 0x0010) & 0x003E) >> 1));
        v = tab(0xEBB1, x); put(0x0618, v); put(0x061A, (uint16_t)(v - 2));
        v = tab(0xEBD3, x); put(0x061C, v); put(0x061E, (uint16_t)(v - 2));
    } else {
        v = (uint16_t)bus_read16(0xE6); put(0x0122, v); put(0x0124, v);
        v = (uint16_t)bus_read16(0xE0); put(0x011E, v); put(0x0120, v);
    }
    bird_cancelled = 0;
    put(0x0696, 0);
    put(0x0698, 0);
    s0 = c->s; rt_push16(c, 0xECCE); f_02_E58B(c); if (c->s != s0 || c->ret != 0xECCE) return;
    s0 = c->s; rt_push8(c, 0x02); rt_push16(c, 0xECD2); f_09_C44E(c); if (c->s != s0 || c->ret != 0xECD2) return;
    s0 = c->s; rt_push8(c, 0x02); rt_push16(c, 0xECD6); f_09_C499(c); if (c->s != s0 || c->ret != 0xECD6) return;
    bus_write8(0x6C, 0);
    s0 = c->s; rt_push16(c, 0xECDB); f_02_8B0C(c); if (c->s != s0 || c->ret != 0xECDB) return;
}
