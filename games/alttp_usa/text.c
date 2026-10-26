/* A Link to the Past (USA): the text of the messages, as a file the player can read and edit.
 *
 * Every message box starts at 0E:C4E2, which expands message number $1CF0 into the buffer at $7F1200 (letters, commands, ends in $7F). Two hooks
 * work on that buffer:
 *
 *  - `--game-opt dump_text=1` writes all the messages in the buffer's form to <ROM folder>/alttp_messages_en.txt (after 0E:D3EB builds the table
 *    of pointers) and exits. The file comes from the player's own ROM: it stays next to it and is not for sharing. With language=es the
 *    messages are those the game would show in Spanish and the file is alttp_messages_es.txt (this is how the translation is checked).
 *  - With the option `language` = es, each box looks its message up in <game folder>/lang/es.txt and, if the file has it, puts that text in the
 *    buffer in place of the English one. The file is read again whenever it changes, so it can be edited with the game running; a message the
 *    file does not have stays English.
 *
 * Format of the file: a line `@NNN` (decimal) opens message NNN and the text after it goes on until the next `@`; lines that start with `#` are
 * comments; line breaks (and carriage returns) are not part of the text. A letter, a digit, a space or one of ! ? . , ' is that character; any
 * other byte of the buffer is written in hexadecimal between braces: {73} is one byte, {6B01} is a command with its parameter. The final $7F is
 * not written. A character or a brace that cannot be read is reported with its line and that message is left out. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "snes_rt.h"
#include "snes_funcs.h"

#define BUF 0x7F1200u        /* where the loader leaves the message */
#define BUF_MAX 3500         /* the bytes after $7F1200 that nothing else uses, with the terminator */
#define MSG_MAX 1024         /* message numbers go below this */
#define CMD_LEN_TABLE 0x0ED36Bu /* length of each command (bytes $67-$7F), as the table builder reads it */
#define SPACE 0x59

static const char *const punct = "!?.,'";
static const uint8_t punct_code[] = { 0x3E, 0x3F, 0x41, 0x42, 0x51 };

/* ---- characters ---- */

static int code_of(char ch) {
    const char *p;
    if (ch >= 'A' && ch <= 'Z') return ch - 'A';
    if (ch >= 'a' && ch <= 'z') return 0x1A + (ch - 'a');
    if (ch >= '0' && ch <= '9') return 0x34 + (ch - '0');
    if (ch == ' ') return SPACE;
    if (ch && (p = strchr(punct, ch)) != NULL) return punct_code[p - punct];
    return -1;
}

static int char_of(uint8_t b) {
    size_t i;
    if (b <= 0x19) return 'A' + b;
    if (b >= 0x1A && b <= 0x33) return 'a' + (b - 0x1A);
    if (b >= 0x34 && b <= 0x3D) return '0' + (b - 0x34);
    if (b == SPACE) return ' ';
    for (i = 0; i < sizeof punct_code; i++) if (punct_code[i] == b) return punct[i];
    return -1;
}

static int command_len(uint8_t b) {
    int n;
    if (b < 0x67 || b >= 0x7F) return 1;
    n = bus_read8(CMD_LEN_TABLE + b);
    return n < 1 ? 1 : n;
}

/* ---- dump ---- */

static void dump_message(FILE *f, int id) {
    uint32_t p = BUF;
    fprintf(f, "@%03d\n", id);
    for (;;) {
        uint8_t b = bus_read8(p);
        int ch, len, i;
        if (b == 0x7F || p >= BUF + BUF_MAX) break;
        ch = char_of(b);
        if (ch >= 0) {
            fputc(ch, f);
            p++;
            continue;
        }
        len = command_len(b);
        fputc('{', f);
        for (i = 0; i < len; i++) fprintf(f, "%02X", bus_read8(p + (uint32_t)i));
        fputc('}', f);
        p += (uint32_t)len;
        if (b == 0x73 || b == 0x75 || b == 0x76) fputc('\n', f);
    }
    fputc('\n', f);
}

/* After the table of pointers is built (0E:D3EB): loads every message with the game's own loader and writes it. */
void alttp_text_dump(Cpu *c) {
    char path[1100];
    FILE *f;
    int id;
    if (!game_opt("dump_text", 0)) return;
    snprintf(path, sizeof path, "%salttp_messages_%s.txt", rom_dir(), game_opt("language", 0) == 1 ? "es" : "en");
    f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "error: cannot write %s\n", path);
        exit(2);
    }
    fprintf(f, "# Text of the messages as the game keeps it. It comes from your copy of the game: do not share it.\n");
    for (id = 0; id < MSG_MAX; id++) {
        uint32_t t = 0x7F71C0u + 3u * (uint32_t)id;
        uint32_t ptr = (uint32_t)bus_read8(t) | (uint32_t)bus_read8(t + 1) << 8 | (uint32_t)bus_read8(t + 2) << 16;
        Cpu k = *c;
        if (bus_read8(ptr) == 0xFF) break; /* the table ends where the messages do */
        k.d = 0;
        k.db = 0x0E; /* the message module runs with its own bank as data bank: the dictionary is read through it */
        k.e = 0;
        k.ret = RT_NO_RET;
        wram_write8(0x1CF0, (uint8_t)id);
        wram_write8(0x1CF1, (uint8_t)(id >> 8));
        f_0E_C4E2(&k);
        dump_message(f, id);
    }
    fclose(f);
    fprintf(stderr, "wrote %d messages to %s\n", id, path);
    exit(0);
}

/* ---- the translation file ---- */

static uint8_t *msg_data[MSG_MAX];
static int msg_len[MSG_MAX];
static long file_stamp = -1, file_size = -1; /* modification time and size of the file that was read; -1: none */
static int warned_missing;

static void forget_messages(void) {
    int i;
    for (i = 0; i < MSG_MAX; i++) {
        free(msg_data[i]);
        msg_data[i] = NULL;
        msg_len[i] = 0;
    }
}

static int hex_digit(char ch) {
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
    if (ch >= 'a' && ch <= 'f') return ch - 'a' + 10;
    return -1;
}

/* One message under construction. */
typedef struct { int id; int line; uint8_t buf[BUF_MAX]; int n; int bad; } Cur;
static Cur cur;

static void close_message(const char *name) {
    if (cur.id < 0) return;
    if (!cur.bad && cur.n + 1 > BUF_MAX) {
        fprintf(stderr, "%s:%d: message %d is too long (%d bytes, at most %d): left in English\n", name, cur.line, cur.id, cur.n + 1, BUF_MAX);
        cur.bad = 1;
    }
    if (!cur.bad) {
        free(msg_data[cur.id]);
        msg_data[cur.id] = (uint8_t *)malloc((size_t)cur.n + 1);
        if (msg_data[cur.id]) {
            memcpy(msg_data[cur.id], cur.buf, (size_t)cur.n);
            msg_data[cur.id][cur.n] = 0x7F;
            msg_len[cur.id] = cur.n + 1;
        }
    }
    cur.id = -1;
}

static void bad_text(const char *name, int line, const char *what) {
    fprintf(stderr, "%s:%d: %s: message %d left in English\n", name, line, what, cur.id);
    cur.bad = 1;
}

static void parse_file(const char *name, const char *s, size_t n) {
    size_t i = 0;
    int line = 1, at_start = 1;
    cur.id = -1;
    while (i < n) {
        char ch = s[i];
        if (ch == '\r') { i++; continue; }
        if (ch == '\n') { i++; line++; at_start = 1; continue; }
        if (at_start && ch == '#') {
            while (i < n && s[i] != '\n') i++;
            continue;
        }
        if (at_start && ch == '@') {
            int id = 0, digits = 0;
            close_message(name);
            i++;
            while (i < n && s[i] >= '0' && s[i] <= '9') { id = id * 10 + (s[i] - '0'); i++; digits++; if (id >= MSG_MAX) id = MSG_MAX; }
            while (i < n && s[i] != '\n') i++;
            cur.id = -1;
            if (!digits || id >= MSG_MAX) {
                fprintf(stderr, "%s:%d: bad message number\n", name, line);
                cur.id = -1;
                cur.bad = 1;
            } else {
                cur.id = id;
                cur.line = line;
                cur.n = 0;
                cur.bad = 0;
            }
            continue;
        }
        at_start = 0;
        if (cur.id < 0) {
            if (!cur.bad) { fprintf(stderr, "%s:%d: text before the first @NNN\n", name, line); cur.bad = 1; }
            while (i < n && s[i] != '\n') i++;
            continue;
        }
        if (cur.bad) { i++; continue; }
        if (ch == '{') {
            int nibbles = 0, v;
            uint8_t hi = 0;
            i++;
            while (i < n && s[i] != '}' && s[i] != '\n') {
                v = hex_digit(s[i]);
                if (v < 0) { bad_text(name, line, "not a hexadecimal digit between braces"); break; }
                if (nibbles & 1) {
                    if (cur.n >= BUF_MAX) { bad_text(name, line, "message too long"); break; }
                    cur.buf[cur.n++] = (uint8_t)(hi << 4 | v);
                } else {
                    hi = (uint8_t)v;
                }
                nibbles++;
                i++;
            }
            if (cur.bad) continue;
            if (i >= n || s[i] != '}' || nibbles == 0 || (nibbles & 1)) { bad_text(name, line, "unclosed or odd {...}"); continue; }
            i++;
            continue;
        }
        {
            int code = code_of(ch);
            if (code < 0) {
                bad_text(name, line, "character not in the alphabet of the game (use {hh} for a byte)");
                continue;
            }
            if (cur.n >= BUF_MAX) { bad_text(name, line, "message too long"); continue; }
            cur.buf[cur.n++] = (uint8_t)code;
            i++;
        }
    }
    close_message(name);
}

static const char *lang_path(void) {
    static char path[1100];
    snprintf(path, sizeof path, "%slang/es.txt", game_dir());
    return path;
}

/* Reads the file again when its time or size changed. A failure keeps what was read before. */
static void reload_if_changed(void) {
    const char *path = lang_path();
    struct stat st;
    FILE *f;
    char *text;
    size_t n;
    if (stat(path, &st) != 0) {
        if (!warned_missing) fprintf(stderr, "language=es: cannot find %s: the messages stay in English\n", path);
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
    forget_messages();
    parse_file(path, text, n);
    free(text);
}

/* After the loader (0E:C4E2): puts the translated text in the buffer in place of the English one. */
void alttp_text_translate(Cpu *c) {
    int id, i;
    (void)c;
    if (game_opt("language", 0) != 1) return;
    reload_if_changed();
    id = wram_read8(0x1CF0) | wram_read8(0x1CF1) << 8;
    if (id < 0 || id >= MSG_MAX || !msg_data[id]) return;
    for (i = 0; i < msg_len[id]; i++) bus_write8(BUF + (uint32_t)i, msg_data[id][i]);
}
