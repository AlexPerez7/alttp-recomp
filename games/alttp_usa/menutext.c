/* A Link to the Past (USA): the fixed text of the player select and name entry screens and of the actions in the pause menu, as a file the
 * player can read and edit.
 *
 * These screens do not use the message system. Their text is lists of records in bank 0C: VRAM address (2 bytes, big endian), length minus
 * one (2 bytes, big endian) and the tilemap words (tile, $18) of one row; every string is two records, the upper half of its letters and the
 * lower half ($10 tiles later). The code copies the lists to WRAM with a loop that reads the ROM, so replacing the bytes in memory
 * (rom_overlay) is all it takes: no hook per screen. The table below has every string: its key, where its two records are, and how many tiles
 * of the record are text (the rest are frame).
 *
 *  - `--game-opt dump_menu=1` writes every string to <ROM folder>/alttp_menu_<language>.txt and exits. The file comes from the player's own
 *    ROM: it stays next to it and is not for sharing.
 *  - With the option `language` = es, <game folder>/lang/es_menu.txt gives the strings it names; the others stay English. The file is read
 *    again whenever it changes, so it can be edited with the game running (the screen shows it the next time it opens).
 *
 * Format of the file: `key = TEXT`, one per line; lines that start with `#` are comments. The text goes after `= ` (one space), it is turned
 * into capitals, and what is left of the gap is filled with spaces. The font has A-Z, the space and ?; anything longer than the gap or
 * with another character is reported with its line and that string stays English. The letters and the name grid are not touched: the name
 * is saved in the SRAM as those tile codes.
 *
 * The pause menu names what the A button does (lift, read, talk, pull, run, swim) in boxes of five tiles side by side, in the letters of the message font
 * (tile $50 is A, $F5 a space, attribute $2D). Each is one row of five words in bank 0D that the menu copies to the tilemap, so they go
 * through the same file, with their own table (`actions` below): the text is centred in its tiles (four letters, the first tile of a box stays blank) and the lift boxes
 * keep their last tile (the glove level). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "snes_rt.h"

#define MAX_PLACES 3
#define MAX_TILES 24

typedef struct {
    uint16_t top, bottom; /* where the two records start in bank 0C */
    uint16_t vram;        /* VRAM word address of the upper row */
    uint8_t total;        /* tiles in the record */
    uint8_t first;        /* first tile of the gap inside the record */
} Place;

typedef struct {
    const char *key;
    int n;                /* tiles in the gap */
    Place at[MAX_PLACES];
    int ok;               /* the records are where and as long as expected */
    uint8_t keep[MAX_PLACES][2][MAX_TILES * 2]; /* the ROM bytes before any overlay */
} Slot;

#define S1(key, n, top, bot, vram, total, first) { key, n, { { top, bot, vram, total, first } }, 0, { { { 0 } } } }

static Slot slots[] = {
    S1("select.title",      14, 0xE2A8, 0xE2C8, 0x6065, 14, 0),
    S1("select.copy",       12, 0xE2E8, 0xE304, 0x62C6, 12, 0),
    S1("select.erase",      12, 0xE320, 0xE33C, 0x6306, 12, 0),
    S1("select.copy_ok",     7, 0xD246, 0xD258, 0x62C6,  7, 0),
    S1("select.erase_this", 17, 0xD436, 0xD45C, 0x62C6, 17, 0),
    S1("erase.title",       12, 0xE456, 0xE472, 0x6065, 12, 0),
    S1("erase.which",       24, 0xE48E, 0xE4C2, 0x6104, 24, 0),
    S1("erase.to_erase",    10, 0xE4F6, 0xE50E, 0x6144, 10, 0),
    S1("erase.quit",        4,  0xE526, 0xE532, 0x6306,  4, 0),
    S1("copy.title",        12, 0xE63C, 0xE658, 0x6065, 12, 0),
    S1("copy.quit",         4,  0xE674, 0xE680, 0x6306,  4, 0),
    S1("copy.which",        6,  0xE68D, 0xE6A7, 0x6104, 11, 1),
    S1("copy.to_which",     9,  0xE73A, 0xE754, 0x6151, 11, 1),
    S1("name.title",        22, 0xE9C1, 0xE9F1, 0x60A4, 22, 0),
    /* END is in three places: the name grid and twice in its second page */
    { "name.end", 3, { { 0xEB95, 0xEBAB, 0x62CC, 9, 6 }, { 0xED15, 0xED47, 0x66C4, 23, 6 }, { 0xED15, 0xED47, 0x66C4, 23, 20 } }, 0, { { { 0 } } } },
};
#define N_SLOTS ((int)(sizeof slots / sizeof slots[0]))

/* ---- the font: tile of the upper half; the lower half is 0x10 later ---- */

static int tile_of(char ch) {
    if (ch == 'I') return 0xAF; /* the game draws its narrow I from here, not from tile 08 */
    if (ch >= 'A' && ch <= 'P') return ch - 'A';
    if (ch >= 'Q' && ch <= 'Z') return 0x20 + (ch - 'Q');
    if (ch == ' ') return 0xA9;
    if (ch == '?') return 0x6F;
    return -1;
}

static char char_of(int tile) {
    int c;
    for (c = ' '; c <= 'Z'; c++) if (tile_of((char)c) == tile) return (char)c;
    return '#'; /* not a letter: never in a gap, but the dump must not fail on it */
}

static uint32_t rom24(uint16_t a) { return 0x0C0000u | a; }

/* ---- checking the ROM, and writing a string into every place of its slot ---- */

static int record_ok(uint16_t rec, uint16_t vram, int total) {
    return bus_read8(rom24(rec)) == (vram >> 8) && bus_read8(rom24(rec) + 1) == (vram & 0xFF) && bus_read8(rom24(rec) + 2) == 0 &&
           bus_read8(rom24(rec) + 3) == 2 * total - 1;
}

static void check_slots(void) {
    int s, p, i;
    for (s = 0; s < N_SLOTS; s++) {
        Slot *sl = &slots[s];
        sl->ok = 1;
        for (p = 0; p < MAX_PLACES && sl->at[p].top; p++) {
            const Place *pl = &sl->at[p];
            if (!record_ok(pl->top, pl->vram, pl->total) || !record_ok(pl->bottom, (uint16_t)(pl->vram + 0x20), pl->total)) sl->ok = 0;
        }
        if (!sl->ok) {
            fprintf(stderr, "menu text: %s is not where this ROM has it: left alone\n", sl->key);
            continue;
        }
        for (p = 0; p < MAX_PLACES && sl->at[p].top; p++)
            for (i = 0; i < sl->n * 2; i++) {
                sl->keep[p][0][i] = bus_read8(rom24(sl->at[p].top) + 4 + (uint32_t)sl->at[p].first * 2 + (uint32_t)i);
                sl->keep[p][1][i] = bus_read8(rom24(sl->at[p].bottom) + 4 + (uint32_t)sl->at[p].first * 2 + (uint32_t)i);
            }
    }
}

static void put_rows(Slot *sl, const char *text) { /* text == NULL: the original bytes */
    int p, i;
    for (p = 0; p < MAX_PLACES && sl->at[p].top; p++) {
        uint8_t up[MAX_TILES * 2], low[MAX_TILES * 2];
        if (text) {
            int len = (int)strlen(text);
            for (i = 0; i < sl->n; i++) {
                int t = tile_of(i < len ? text[i] : ' ');
                up[2 * i] = (uint8_t)t;
                low[2 * i] = (uint8_t)(t + 0x10);
                up[2 * i + 1] = low[2 * i + 1] = 0x18;
            }
        } else {
            memcpy(up, sl->keep[p][0], (size_t)sl->n * 2);
            memcpy(low, sl->keep[p][1], (size_t)sl->n * 2);
        }
        rom_overlay(rom24(sl->at[p].top) + 4 + (uint32_t)sl->at[p].first * 2, up, (size_t)sl->n * 2);
        rom_overlay(rom24(sl->at[p].bottom) + 4 + (uint32_t)sl->at[p].first * 2, low, (size_t)sl->n * 2);
    }
}

/* ---- the actions of the pause menu ---- */

#define MAX_ACTION 5

typedef struct {
    const char *key;
    uint16_t at;           /* where the row of tiles starts in bank 0D */
    int n;                 /* tiles that are text */
    const char *orig;      /* what the ROM has there (n letters; a space is a blank tile) */
    int ok;
    uint8_t keep[MAX_ACTION * 2];
} Action;

static Action actions[] = {
    /* the boxes sit side by side and the game leaves the first tile of each blank (the lift ones are full: their last tile is the glove level), so
     * four letters is what a word can have; "run" has a blank at both ends in the ROM and takes five */
    { "pause.lift1", 0xF93B, 4, "LIFT", 0, { 0 } },
    { "pause.lift2", 0xF94F, 4, "LIFT", 0, { 0 } },
    { "pause.lift3", 0xF963, 4, "LIFT", 0, { 0 } },
    { "pause.read",  0xF979, 4, "READ", 0, { 0 } },
    { "pause.talk",  0xF98D, 4, "TALK", 0, { 0 } },
    { "pause.pull",  0xF9B3, 4, "PULL", 0, { 0 } },
    { "pause.run",   0xF9C7, 5, " RUN ", 0, { 0 } },
    { "pause.swim",  0xF9DD, 4, "SWIM", 0, { 0 } },
};
#define N_ACTIONS ((int)(sizeof actions / sizeof actions[0]))

static uint32_t rom24d(uint16_t a) { return 0x0D0000u | a; }

static int a_tile(char ch) {
    if (ch >= 'A' && ch <= 'Z') return 0x50 + (ch - 'A');
    if (ch == ' ') return 0xF5;
    return -1;
}

static char a_char(int tile) { return tile >= 0x50 && tile <= 0x69 ? (char)('A' + tile - 0x50) : ' '; }

static void check_actions(void) {
    int a, i;
    for (a = 0; a < N_ACTIONS; a++) {
        Action *ac = &actions[a];
        ac->ok = 1;
        for (i = 0; i < ac->n; i++) {
            uint8_t tile = bus_read8(rom24d(ac->at) + (uint32_t)i * 2), attr = bus_read8(rom24d(ac->at) + (uint32_t)i * 2 + 1);
            if (tile != (uint8_t)a_tile(ac->orig[i]) || attr != (ac->orig[i] == ' ' ? 0x2C : 0x2D)) ac->ok = 0;
        }
        if (!ac->ok) {
            fprintf(stderr, "menu text: %s is not where this ROM has it: left alone\n", ac->key);
            continue;
        }
        for (i = 0; i < ac->n * 2; i++) ac->keep[i] = bus_read8(rom24d(ac->at) + (uint32_t)i);
    }
}

static void put_action(Action *ac, const char *text) { /* text == NULL: the original bytes */
    uint8_t row[MAX_ACTION * 2];
    int i;
    if (text) {
        int len = (int)strlen(text), left = (ac->n - len + 1) / 2;
        for (i = 0; i < ac->n; i++) {
            int k = i - left;
            char ch = k >= 0 && k < len ? text[k] : ' ';
            row[2 * i] = (uint8_t)a_tile(ch);
            row[2 * i + 1] = ch == ' ' ? 0x2C : 0x2D;
        }
    } else memcpy(row, ac->keep, (size_t)ac->n * 2);
    rom_overlay(rom24d(ac->at), row, (size_t)ac->n * 2);
}

/* A line `key = text` of the file when the key is an action: 1 if it was (whatever came of the text), 0 if the key is not an action. */
static int action_line(const char *path, int line, const char *key, char *val) {
    int a, k;
    for (a = 0; a < N_ACTIONS && strcmp(actions[a].key, key); a++) {}
    if (a == N_ACTIONS) return 0;
    if (!actions[a].ok) return 1;
    for (k = 0; val[k]; k++) {
        if (val[k] >= 'a' && val[k] <= 'z') val[k] = (char)(val[k] - 'a' + 'A');
        if (a_tile(val[k]) < 0) {
            fprintf(stderr, "%s:%d: %s: the font has no \"%c\" (A-Z and space): left in English\n", path, line, key, (unsigned char)val[k] < 0x80 ? val[k] : '?');
            return 1;
        }
    }
    if (k > actions[a].n) {
        fprintf(stderr, "%s:%d: %s is too long (%d letters, at most %d): left in English\n", path, line, key, k, actions[a].n);
        return 1;
    }
    put_action(&actions[a], val);
    return 1;
}

/* ---- the dump ---- */

static void dump_menu(void) {
    char path[1100];
    FILE *f;
    int s, i;
    snprintf(path, sizeof path, "%salttp_menu_%s.txt", rom_dir(), game_opt("language", 0) == 1 ? "es" : "en");
    f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "error: cannot write %s\n", path);
        exit(2);
    }
    fprintf(f, "# Fixed text of the player select, name entry and pause menu action boxes as the game keeps it. It comes from your copy of the game: do not share it.\n");
    fprintf(f, "# A text can have as many letters as its gap (A-Z, space and ?); a shorter one is filled with spaces.\n");
    for (s = 0; s < N_SLOTS; s++) {
        const Slot *sl = &slots[s];
        if (!sl->ok) continue;
        fprintf(f, "# %s: up to %d letters\n%s = ", sl->key, sl->n, sl->key);
        for (i = 0; i < sl->n; i++) fputc(char_of(bus_read8(rom24(sl->at[0].top) + 4 + (uint32_t)(sl->at[0].first + i) * 2)), f);
        fputc('\n', f);
    }
    for (s = 0; s < N_ACTIONS; s++) {
        const Action *ac = &actions[s];
        if (!ac->ok) continue;
        fprintf(f, "# %s: up to %d letters (A-Z and space), centred\n%s = ", ac->key, ac->n, ac->key);
        for (i = 0; i < ac->n; i++) fputc(a_char(bus_read8(rom24d(ac->at) + (uint32_t)i * 2)), f);
        fputc('\n', f);
    }
    fclose(f);
    fprintf(stderr, "wrote the menu text to %s\n", path);
    exit(0);
}

/* ---- the translation file ---- */

static long file_stamp = -1, file_size = -1; /* modification time and size of the file that was read; -1: none */
static int warned_missing;

static const char *lang_path(void) {
    static char path[1100];
    snprintf(path, sizeof path, "%slang/es_menu.txt", game_dir());
    return path;
}

static void parse_file(const char *path, char *text, size_t n) {
    size_t pos = 0;
    int line = 0, s;
    for (s = 0; s < N_SLOTS; s++) if (slots[s].ok) put_rows(&slots[s], NULL);
    for (s = 0; s < N_ACTIONS; s++) if (actions[s].ok) put_action(&actions[s], NULL);
    text[n] = 0;
    while (pos < n) {
        char *ln = text + pos, *eq, *val;
        size_t len = strcspn(ln, "\r\n");
        int k, bad = 0;
        pos += len;
        while (pos < n && (text[pos] == '\r' || text[pos] == '\n')) text[pos++] = 0;
        ln[len] = 0;
        line++;
        if (ln[0] == '#' || ln[0] == 0) continue;
        eq = strchr(ln, '=');
        if (!eq) { fprintf(stderr, "%s:%d: expected key = text\n", path, line); continue; }
        *eq = 0;
        for (val = eq - 1; val >= ln && *val == ' '; val--) *val = 0;
        val = eq + 1;
        if (*val == ' ') val++;
        for (s = 0; s < N_SLOTS && strcmp(slots[s].key, ln); s++) {}
        if (s == N_SLOTS) {
            if (!action_line(path, line, ln, val)) fprintf(stderr, "%s:%d: no string called %s\n", path, line, ln);
            continue;
        }
        if (!slots[s].ok) continue;
        for (k = 0; val[k]; k++) {
            if (val[k] >= 'a' && val[k] <= 'z') val[k] = (char)(val[k] - 'a' + 'A');
            if (tile_of(val[k]) < 0) {
                if ((unsigned char)val[k] < 0x80) fprintf(stderr, "%s:%d: %s: the font has no \"%c\" (A-Z, space and ?): left in English\n", path, line, slots[s].key, val[k]);
                else fprintf(stderr, "%s:%d: %s: the font has no accented letters or enye (A-Z, space and ?): left in English\n", path, line, slots[s].key);
                bad = 1;
                break;
            }
        }
        if (bad) continue;
        if (k > slots[s].n) {
            fprintf(stderr, "%s:%d: %s is too long (%d letters, at most %d): left in English\n", path, line, slots[s].key, k, slots[s].n);
            continue;
        }
        put_rows(&slots[s], val);
    }
}

/* Reads the file again when its time or size changed. A failure keeps what was read before. */
static void reload_if_changed(void) {
    const char *path = lang_path();
    struct stat st;
    FILE *f;
    char *text;
    size_t n;
    if (stat(path, &st) != 0) {
        if (!warned_missing) fprintf(stderr, "language=es: cannot find %s: the menus stay in English\n", path);
        warned_missing = 1;
        return;
    }
    warned_missing = 0;
    if ((long)st.st_mtime == file_stamp && (long)st.st_size == file_size) return;
    f = fopen(path, "rb");
    if (!f) return;
    text = (char *)malloc((size_t)st.st_size + 1);
    if (!text) { fclose(f); return; }
    n = fread(text, 1, (size_t)st.st_size, f);
    fclose(f);
    file_stamp = (long)st.st_mtime;
    file_size = (long)st.st_size;
    parse_file(path, text, n);
    free(text);
}

/* Once per frame, before the NMI work (00:80B5): checks the ROM once, then follows the file. */
void alttp_menu_poll(Cpu *c) {
    static int started, frames;
    (void)c;
    if (!started) {
        check_slots();
        check_actions();
        started = 1;
    }
    if (game_opt("language", 0) == 1 && frames++ % 30 == 0) reload_if_changed();
    if (game_opt("dump_menu", 0)) dump_menu();
}
