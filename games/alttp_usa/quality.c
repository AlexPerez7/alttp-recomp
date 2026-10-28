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
static void sword_pots(Cpu *c);
static void rupees_enter(void);
static void rupees_leave(void);

void alttp_hud_beep_enter(Cpu *c) {
    item_switch(c);
    sword_pots(c);
    rupees_enter();
    sfx_on_entry = wram_read8(0x012E);
}

void alttp_hud_beep_leave(Cpu *c) {
    (void)c;
    rupees_leave();
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

static uint16_t rupees_shown(void);
static uint16_t rupees_max(void);
static void rupee_digits(void);

void alttp_hud_max_yellow(Cpu *c) {
    (void)c;
    rupee_digits();
    if (!game_opt("max_yellow", 0)) return;
    if (rupees_shown() == rupees_max()) paint(rupees_shown() > 999 ? 0xC74E : 0xC750, rupees_shown() > 999 ? 4 : 3);
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
 * alttp_bird_cancel, on entry to step 5, takes B as the cancel button: it removes A, X, B and Y from what the step sees and goes to step 6
 * itself; alttp_bird_cancelled, on its return, marks the trip as cancelled with bit 7 of $1AF0 (the step masks the destination with 7 on its
 * own, so the mark has to go after it). That is in WRAM, so a saved state keeps it; the one static, `cancelling`, lives only from the entry
 * to the return of one call. alttp_bird_land replaces 02:EC39: its table part is the same as the original and runs for a destination, but
 * for a cancelled trip it leaves Link, the scroll and the area as they were (the map restored them in step 6), so the rest of the steps load
 * the area Link was in and the bird sets him down where he took off. Link's position and the area are the same in both, so the second part
 * (sprites, Link's state) is the original code, called from here. On with `--game-opt bird_cancel=1`. */
#define BIRD_CANCEL_MARK 0x80
static uint8_t cancelling;

void alttp_bird_cancel(Cpu *c) {
    (void)c;
    cancelling = 0;
    if (!game_opt("bird_cancel", 0) || wram_read8(0xC8)) return;
    if (wram_read8(0xF4) & 0x80) {
        cancelling = 1;
        wram_write8(0x0200, 6);
    }
    wram_write8(0xF0, wram_read8(0xF0) & 0x3F);
    wram_write8(0xF2, wram_read8(0xF2) & 0x3F);
}

void alttp_bird_cancelled(Cpu *c) {
    (void)c;
    if (!cancelling) return;
    cancelling = 0;
    wram_write8(0x1AF0, wram_read8(0x1AF0) | BIRD_CANCEL_MARK);
}

static uint16_t tab(uint32_t base, uint8_t x) { return (uint16_t)bus_read16(0x020000u + base + x); }
static void put(uint32_t a, uint16_t v) { bus_write16(a, v); }

void alttp_bird_land(Cpu *c) {
    uint16_t s0, v;
    uint8_t cancelled;
    put(0x04AC, 0);
    rt_rep(c, 0x20);
    cancelled = wram_read8(0x1AF0) & BIRD_CANCEL_MARK;
    if (!cancelled) {
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
        wram_write8(0x1AF0, 0);
        v = (uint16_t)bus_read16(0xE6); put(0x0122, v); put(0x0124, v);
        v = (uint16_t)bus_read16(0xE0); put(0x011E, v); put(0x0120, v);
    }
    put(0x0696, 0);
    put(0x0698, 0);
    s0 = c->s; rt_push16(c, 0xECCE); f_02_E58B(c); if (c->s != s0 || c->ret != 0xECCE) return;
    s0 = c->s; rt_push8(c, 0x02); rt_push16(c, 0xECD2); f_09_C44E(c); if (c->s != s0 || c->ret != 0xECD2) return;
    s0 = c->s; rt_push8(c, 0x02); rt_push16(c, 0xECD6); f_09_C499(c); if (c->s != s0 || c->ret != 0xECD6) return;
    bus_write8(0x6C, 0);
    s0 = c->s; rt_push16(c, 0xECDB); f_02_8B0C(c); if (c->s != s0 || c->ret != 0xECDB) return;
}

/* Up to 9999 rupees: $F360 holds the amount the player has and $F362 the one the status bar shows, that follows it one rupee per frame. The
 * routine of the status bar (0D:DB75), once per frame, makes the shown one equal to the real one and caps both at 999 (0D:DBEB-0D:DBF3), and
 * 0D:FC09 draws the three digits of the shown one at $C750-$C754. rupees_enter, on entry, does the counting itself with a cap of 9999 (one
 * rupee per frame, more when the difference is large: 1 + difference / 50) and the same coin sound, and gives the original routine the
 * shown amount capped at 999 in both, so it finds them equal and leaves them alone; rupees_leave puts the real ones back before each return.
 * The digits of the real amount are drawn by rupee_digits at the end of 0D:FC09: from 1000 on four, at $C74E-$C754 (the tile at $C74E is
 * otherwise the one of the template at 0D:FE77), tile $90 + digit with palette 1. The real values live in WRAM; the statics here only live
 * from the entry to the return of that routine. With a count that does not fit (more than $7FFF, from a subtraction below zero) the
 * original runs untouched. On with `--game-opt rupees_9999=1`. */
#define RUPEE_CAP 9999
#define RUPEE_TEMPLATE 0x0DFE77u
#define RUPEE_DIGIT_TILE 0x2490u
static uint16_t rup_real_target, rup_real_shown;
static uint8_t rup_active;

static uint16_t rd16(uint32_t a) { return (uint16_t)(wram_read8(a) | wram_read8(a + 1) << 8); }
static void wr16(uint32_t a, uint16_t v) { wram_write8(a, v & 0xFF); wram_write8(a + 1, v >> 8); }

static void rupees_enter(void) {
    uint16_t t, d, p;
    rup_active = 0;
    if (!game_opt("rupees_9999", 0) || wram_read8(0x0200)) return;
    t = rd16(0xF360);
    d = rd16(0xF362);
    if (t > 0x7FFF || d > RUPEE_CAP) return;
    if (t > RUPEE_CAP) t = RUPEE_CAP;
    if (t <= 999 && d <= 999) return;
    if (d == t || wram_read8(0x012E)) {
        wram_write8(0x0CFD, 0);
    } else {
        uint8_t n = wram_read8(0x0CFD);
        wram_write8(0x0CFD, (uint8_t)(n + 1));
        if (!(n & 7)) wram_write8(0x012E, 0x29);
    }
    if (d != t) {
        uint16_t diff = t > d ? (uint16_t)(t - d) : (uint16_t)(d - t), step = (uint16_t)(1 + diff / 50);
        if (step > diff) step = diff;
        d = t > d ? (uint16_t)(d + step) : (uint16_t)(d - step);
    }
    p = d > 999 ? 999 : d;
    wr16(0xF360, p);
    wr16(0xF362, p);
    rup_real_target = t;
    rup_real_shown = d;
    rup_active = 1;
}

static void rupees_leave(void) {
    if (!rup_active) return;
    wr16(0xF360, rup_real_target);
    wr16(0xF362, rup_real_shown);
    rup_active = 0;
}

static uint16_t rupees_shown(void) { return rup_active ? rup_real_shown : rd16(0xF362); }
static uint16_t rupees_max(void) { return game_opt("rupees_9999", 0) ? RUPEE_CAP : 999; }

static void rupee_digits(void) {
    uint16_t d;
    int i;
    if (!game_opt("rupees_9999", 0)) return;
    d = rupees_shown();
    if (d < 1000 || d > RUPEE_CAP) {
        wr16(0xC74E, (uint16_t)bus_read16(RUPEE_TEMPLATE + 0x4E));
        return;
    }
    for (i = 3; i >= 0; i--) {
        wr16(0xC74E + 2 * i, (uint16_t)(RUPEE_DIGIT_TILE + d % 10));
        d = (uint16_t)(d / 10);
    }
}

/* Collect items with the sword: the item sprites (rupees, hearts, magic, bombs, arrows, keys...; types $D8-$E2) check in 06:D116, once per
 * frame, whether Link touches them: 06:F14A tests his body and, with carry set, 06:D125 gives the item. alttp_item_touch replaces 06:D116
 * with the same two steps and, when the body does not touch it, a third one with the sword: the hitbox that sprites use to be hurt by it
 * (06:F5E0 sets Link's weapon box at $00-$03 and $08, 06:F7EF the sprite's at $04-$07 and $0A-$0B, 06:F836 compares them as 06:F2C8 does)
 * while Link is swinging the sword ($3C not 0, no other item in use in $0301 or $037A) and on the same layer ($EE, $0F20,X). Spin attacks
 * count too. The sprite is picked up the same way as by touch, so nothing else changes. On with `--game-opt sword_pickup=1`. */
#define CALL_RTS(fn, back) do { uint16_t s0_ = c->s; rt_push16(c, back); fn(c); if (c->s != s0_ || c->ret != (back)) return; } while (0)

static void item_give(Cpu *c) {
    uint16_t s0 = c->s;
    rt_push8(c, 0x06);
    rt_push16(c, 0xD124);
    f_06_D125(c);
    if (c->s != s0 || c->ret != 0xD124) return;
}

void alttp_item_touch(Cpu *c) {
    uint8_t x = (uint8_t)c->x;
    if (wram_read8(0x0F10 + x)) return;
    CALL_RTS(f_06_F14A, 0xD11E);
    if (c->c) { item_give(c); return; }
    if (!game_opt("sword_pickup", 0) || !wram_read8(0x0DD0 + x) || !wram_read8(0x3C)) return;
    if (wram_read8(0x0301) || (wram_read8(0x037A) & 0x10) || wram_read8(0x0372)) return;
    if (wram_read8(0xEE) != wram_read8(0x0F20 + x)) return;
    c->x = x;
    CALL_RTS(f_06_F5E0, 0xF5E1);
    CALL_RTS(f_06_F7EF, 0xF7F0);
    CALL_RTS(f_06_F836, 0xF837);
    if (c->c) item_give(c);
}

/* Break pots with the sword: in the underworld the hammer smashes a pot (tile attribute $7x in $7F:2000) through 1B:BD7A, which indoors jumps to
 * 01:DABB: with bit 1 of $0301 set (the hammer) it takes the tile row from $00 (pixel y; the row is ($00 & $1F8) / 8) and the column from $02
 * (tile x, 0-63), looks the pot up in the objects at $0500, removes its tiles, shatters it (06:812D) and reveals what was under it
 * (09:91C3), all with the game's own code. sword_pots, once per frame (called from the status bar hook), does that for the tile under the
 * centre of the box the sword hits sprites with (06:F5E0, set at $00-$03 and $08) while Link swings it indoors ($3C not 0, $1B not 0, free
 * to move in module 7, no other item in use in $0301 or $037A): it puts the tile in $00 and $02, sets the bit of the hammer for the call and
 * takes it away afterwards. Where there is no pot, or no secret to reveal, 01:DABB leaves things as they were. The scratch bytes $00-$0F are
 * restored. On with `--game-opt sword_pots=1`. */
static void sword_pots(Cpu *c) {
    Cpu k;
    uint8_t save[16], n, hit;
    uint16_t s0, x, y;
    if (!game_opt("sword_pots", 0) || !wram_read8(0x1B) || !wram_read8(0x3C)) return;
    if (wram_read8(0x10) != 7 || wram_read8(0x11) || wram_read8(0x0301) || (wram_read8(0x037A) & 0x10) || wram_read8(0x0372)) return;
    for (n = 0; n < 16; n++) save[n] = wram_read8(n);
    k = *c;
    k.d = 0; k.e = 0; k.m = 1; k.xf = 1; k.db = 0x06;
    k.ret = RT_NO_RET;
    s0 = k.s;
    rt_push16(&k, 0xF5E1);
    f_06_F5E0(&k);
    hit = (k.s == s0 && k.ret == 0xF5E1 && wram_read8(0x08) != 0x80);
    if (hit) {
        x = (uint16_t)((wram_read8(0x00) | wram_read8(0x08) << 8) + wram_read8(0x02) / 2);
        y = (uint16_t)((wram_read8(0x01) | wram_read8(0x09) << 8) + wram_read8(0x03) / 2);
        wr16(0x00, (uint16_t)(y & 0x1FF));
        wr16(0x02, (uint16_t)((x >> 3) & 0x3F));
        wram_write8(0x0301, 2);
        k.db = 0x07;
        s0 = k.s;
        rt_push8(&k, 0x07);
        rt_push16(&k, 0xDC4D);
        f_1B_BD7A(&k);
        wram_write8(0x0301, 0);
    }
    for (n = 0; n < 16; n++) wram_write8(n, save[n]);
}
