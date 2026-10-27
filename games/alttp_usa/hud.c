/* A Link to the Past (USA): the "LIFE" label of the status bar says "VIDA" with language = es.
 *
 * The label is two tiles of the BG3 sheet, two letters each ("LI" and "FE": tiles $AB and $AC from word $7000 of the VRAM), which come
 * from compressed graphics, so they are changed in the VRAM and not in the ROM. alttp_wide_fill (widefill.c, the hook at 00:80B5, once
 * per frame) calls alttp_hud_poll: where the two tiles are
 * the ones of "LI" and "FE" (drawn here from the shape of their letters, not read from the game) they are replaced by "VI" and "DA";
 * on any other screen the tiles hold something else and nothing is touched. */
#include "snes_rt.h"

#define TILE_LI 0x7558u /* word address of tile $AB of the sheet at $7000 */
#define TILE_FE 0x7560u /* tile $AC */

/* Letters of 6 rows by 3 columns at most; the status bar font gives each body pixel a shadow to its right and below. */
typedef struct { char ch; const char *rows[6]; } Letter;
static const Letter letters[] = {
    { 'L', { "o..", "o..", "o..", "o..", "o..", "ooo" } }, { 'I', { "o", "o", "o", "o", "o", "o" } },
    { 'F', { "ooo", "o..", "ooo", "o..", "o..", "o.." } }, { 'E', { "ooo", "o..", "ooo", "o..", "o..", "ooo" } },
    { 'V', { "o.o", "o.o", "o.o", "o.o", ".o.", ".o." } }, { 'D', { "oo.", "o.o", "o.o", "o.o", "o.o", "oo." } },
    { 'A', { ".o.", "o.o", "o.o", "ooo", "o.o", "o.o" } },
};

/* The 8 rows (two bitplanes each) of a tile with letter `a` at column `ca` and letter `b` at column `cb`, body in colour 2, shadow in 3. */
static void draw(char a, int ca, char b, int cb, uint16_t out[8]) {
    int grid[9][9] = { { 0 } }, n, r, c, k;
    char which[2] = { a, b };
    int col[2] = { ca, cb };
    for (k = 0; k < 2; k++)
        for (n = 0; n < (int)(sizeof letters / sizeof letters[0]); n++) {
            if (letters[n].ch != which[k]) continue;
            for (r = 0; r < 6; r++)
                for (c = 0; letters[n].rows[r][c]; c++)
                    if (letters[n].rows[r][c] == 'o') grid[r][col[k] + c] = 2;
        }
    for (r = 0; r < 8; r++)
        for (c = 0; c < 8; c++)
            if (grid[r][c] == 2) {
                if (!grid[r][c + 1]) grid[r][c + 1] = 3;
                if (!grid[r + 1][c]) grid[r + 1][c] = 3;
                if (!grid[r + 1][c + 1]) grid[r + 1][c + 1] = 3;
            }
    for (r = 0; r < 8; r++) {
        unsigned lo = 0, hi = 0;
        for (c = 0; c < 8; c++) {
            lo |= (unsigned)(grid[r][c] & 1) << (7 - c);
            hi |= (unsigned)(grid[r][c] >> 1) << (7 - c);
        }
        out[r] = (uint16_t)(lo | hi << 8);
    }
}

static int is_tile(uint32_t at, const uint16_t want[8]) {
    int r;
    for (r = 0; r < 8; r++) if (ppu_vram_read16((uint16_t)(at + (uint32_t)r)) != want[r]) return 0;
    return 1;
}

void alttp_hud_poll(void) {
    uint16_t li[8], fe[8], vi[8], da[8];
    int r;
    if (game_opt("language", 0) != 1 || !game_opt("hud_text", 1)) return; /* hud_text=0: the tests that compare pictures keep the label as it is */
    draw('L', 1, 'I', 5, li);
    draw('F', 0, 'E', 4, fe);
    if (!is_tile(TILE_LI, li) || !is_tile(TILE_FE, fe)) return;
    draw('V', 1, 'I', 5, vi);
    draw('D', 0, 'A', 4, da);
    for (r = 0; r < 8; r++) {
        ppu_vram_write16((uint16_t)(TILE_LI + (uint32_t)r), vi[r]);
        ppu_vram_write16((uint16_t)(TILE_FE + (uint32_t)r), da[r]);
    }
}
