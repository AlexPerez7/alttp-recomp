/* Prueba de alttp_magic_refund (quality.c) sola: el cuerpo de la funcion se extrae de quality.c y se compila contra una WRAM y un bus de
 * mentira (la tabla de costes se lee de la ROM; nada de ella se guarda). Uso: test_refund <rom.sfc> <cuerpo.c>.
 * Imprime "magia final sin la opcion, con ella" para varias magias de partida. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
typedef struct { uint16_t a, x, y, s, d; } Cpu;
static uint8_t wram[0x20000], *rom;
static int opt;
static uint8_t wram_read8(uint32_t a) { return wram[a]; }
static void wram_write8(uint32_t a, uint8_t v) { wram[a] = v; }
static uint8_t bus_read8(uint32_t a) { return rom[(a >> 16) * 0x8000 + (a & 0x7FFF)]; } /* LoROM */
static int game_opt(const char *k, int d) { (void)k; (void)d; return opt; }
#include BODY
int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb");
    static const int start[] = { 0, 100, 112, 120, 127, 128 };
    size_t n = 0, i;
    int x, bad = 0, over = 0;
    rom = malloc(0x200000);
    if (!f || !(n = fread(rom, 1, 0x200000, f))) return 2;
    if (n & 0x200) { rom += 0x200; } /* sin cabecera copier si la hubiera */
    for (x = 0; x <= 4; x += 4) for (i = 0; i < sizeof start / sizeof *start; i++) {
        int r[2], o;
        for (o = 0; o < 2; o++) {
            Cpu c = {0};
            opt = o; wram[0xF36E] = (uint8_t)start[i]; wram[0xF37B] = 0; c.x = (uint16_t)x;
            alttp_magic_refund(&c);
            r[o] = wram[0xF36E];
        }
        printf("X=%d magia %3d -> %3d sin la opcion, %3d con ella\n", x, start[i], r[0], r[1]);
        if (r[1] > 128) bad = 1;               /* con la opcion nunca pasa de 128 */
        if (r[0] > 128) over = 1;              /* sin ella si (el bug existe) */
        if (r[0] <= 128 && r[0] != r[1]) bad = 1; /* por debajo del tope no deben diferir */
    }
    if (!over) bad = 1;
    return bad;
}
