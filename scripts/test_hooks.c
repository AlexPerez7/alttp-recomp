/* Prueba de la lógica de los ganchos de arreglos pequeños de quality.c (fix_moldorm_sound, fix_swamola_bank, fix_kiki_bomb, fix_bunny_palette):
 * el cuerpo se extrae de quality.c y se compila contra una WRAM de mentira y funciones del juego de mentira que solo anotan la llamada.
 * No prueba que el juego llegue a esas rutinas (eso exigiría partidas difíciles de provocar), solo lo que el gancho hace cuando llegan. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef struct Cpu { uint16_t a, x, y, s, d; uint8_t db, c, z, v, n, dec, irq, e, m, xf; uint32_t ret; } Cpu;
#define RT_NO_RET 0xFFFFFFFFu
static uint8_t wram[0x20000];
static const char *opt_on = "";
static int calls_d6c0, calls_d6dd;
static uint8_t wram_read8(uint32_t a) { return wram[a]; }
static void wram_write8(uint32_t a, uint8_t v) { wram[a] = v; }
static int game_opt(const char *k, int d) { (void)d; return strcmp(k, opt_on) == 0; }
static void f_0E_D6C0(Cpu *c) { (void)c; calls_d6c0++; }
static void f_0E_D6DD(Cpu *c) { (void)c; calls_d6dd++; }
static int calls_ed29;
static void f_1B_ED29(Cpu *c) { (void)c; calls_ed29++; }
#include BODY
static int bad;
#define CHECK(cond, msg) do { int ok_ = !!(cond); printf("  %-70s %s\n", msg, ok_ ? "ok" : "MAL"); if (!ok_) bad = 1; } while (0)
static void reset(const char *opt) { memset(wram, 0, sizeof wram); opt_on = opt; calls_d6c0 = calls_d6dd = calls_ed29 = 0; }
int main(void) {
    Cpu c;
    memset(&c, 0, sizeof c);
    /* Moldorm: el golpe pone $46 = $18 con solo el pan en $012F */
    reset("fix_moldorm_sound"); alttp_moldorm_enter(&c); wram[0x46] = 0x18; wram[0x012F] = 0x80; alttp_moldorm_leave(&c);
    CHECK(wram[0x012F] == 0xB2, "Moldorm: con la opcion el golpe suena ($80 -> $B2)");
    reset(""); alttp_moldorm_enter(&c); wram[0x46] = 0x18; wram[0x012F] = 0x80; alttp_moldorm_leave(&c);
    CHECK(wram[0x012F] == 0x80, "Moldorm: sin la opcion no cambia nada");
    reset("fix_moldorm_sound"); wram[0x46] = 0x10; alttp_moldorm_enter(&c); wram[0x46] = 0x0F; wram[0x012F] = 0x40; alttp_moldorm_leave(&c);
    CHECK(wram[0x012F] == 0x40, "Moldorm: sin golpe nuevo no toca el sonido");
    /* Swamola: banco $1D mientras corre y el de antes al salir */
    reset("fix_swamola_bank"); c.db = 0x7E; alttp_swamola_enter(&c); CHECK(c.db == 0x1D, "Swamola: con la opcion corre con DB = $1D");
    alttp_swamola_leave(&c); CHECK(c.db == 0x7E, "Swamola: al salir devuelve el banco de datos");
    reset(""); c.db = 0x7E; alttp_swamola_enter(&c); CHECK(c.db == 0x7E, "Swamola: sin la opcion no cambia el banco");
    alttp_swamola_leave(&c); CHECK(c.db == 0x7E, "Swamola: sin la opcion tampoco al salir");
    /* Kiki: pasa a seguir a Link ($F3CC = $0A) y se limpia $F3D3 */
    reset("fix_kiki_bomb"); wram[0xF3D3] = 1; alttp_kiki_enter(&c); wram[0xF3CC] = 0x0A; alttp_kiki_leave(&c);
    CHECK(wram[0xF3D3] == 0, "Kiki: con la opcion $F3D3 pasa a 0 al empezar a seguirle");
    reset("fix_kiki_bomb"); wram[0xF3D3] = 1; wram[0xF3CC] = 0x0A; alttp_kiki_enter(&c); alttp_kiki_leave(&c);
    CHECK(wram[0xF3D3] == 1, "Kiki: si ya le seguia no toca $F3D3");
    reset(""); wram[0xF3D3] = 1; alttp_kiki_enter(&c); wram[0xF3CC] = 0x0A; alttp_kiki_leave(&c);
    CHECK(wram[0xF3D3] == 1, "Kiki: sin la opcion no cambia nada");
    /* Conejo: paleta al desmayarse y al revivir de conejo permanente */
    reset("fix_bunny_palette"); alttp_faint_leave(&c); CHECK(calls_d6c0 == 1, "Conejo: con la opcion Death_PrepFaint carga la paleta de Link");
    reset(""); alttp_faint_leave(&c); CHECK(calls_d6c0 == 0, "Conejo: sin la opcion no la carga");
    reset("fix_bunny_palette"); wram[0x5D] = 0x17; wram[0x56] = 1; alttp_revival_leave(&c);
    CHECK(calls_d6dd == 1, "Conejo: revivir de conejo permanente carga la paleta de conejo");
    reset("fix_bunny_palette"); wram[0x5D] = 0x17; wram[0x56] = 1; wram[0x0345] = 1; alttp_revival_leave(&c);
    CHECK(calls_d6dd == 0, "Conejo: nadando no la carga");
    reset("fix_bunny_palette"); wram[0x5D] = 0; alttp_revival_leave(&c);
    CHECK(calls_d6dd == 0, "Conejo: revivir sin ser conejo no la carga");
    /* Bloqueo del menu tras un medallon, cornisa en una plataforma y paleta del escudo del Pikit */
    reset("fix_spell_lock"); wram[0x0112] = 1; alttp_spell_lock(&c); CHECK(wram[0x0112] == 0, "Hechizo: con la opcion $0112 vuelve a 0");
    reset(""); wram[0x0112] = 1; alttp_spell_lock(&c); CHECK(wram[0x0112] == 1, "Hechizo: sin la opcion no cambia nada");
    reset("fix_ledge_platform"); wram[0x047A] = 1; alttp_ledge_platform(&c); CHECK(wram[0x047A] == 0, "Cornisa: con la opcion $047A vuelve a 0");
    reset(""); wram[0x047A] = 1; alttp_ledge_platform(&c); CHECK(wram[0x047A] == 1, "Cornisa: sin la opcion no cambia nada");
    reset("fix_shield_palette"); wram[0xF35A] = 1; alttp_absorb_enter(&c); wram[0xF35A] = 2; alttp_absorb_leave(&c);
    CHECK(calls_ed29 == 1, "Escudo: con la opcion y otro escudo carga su paleta");
    reset("fix_shield_palette"); wram[0xF35A] = 1; alttp_absorb_enter(&c); alttp_absorb_leave(&c);
    CHECK(calls_ed29 == 0, "Escudo: sin cambio de escudo no la carga");
    reset(""); wram[0xF35A] = 1; alttp_absorb_enter(&c); wram[0xF35A] = 2; alttp_absorb_leave(&c);
    CHECK(calls_ed29 == 0, "Escudo: sin la opcion no la carga");
    /* Ganchos guarda (el motor los saca de la funcion o los salta si devuelven distinto de 0) */
    reset("fix_door_submodule"); wram[0x10] = 7; wram[0x11] = 0; CHECK(alttp_door_guard(&c) == 0, "Puertas: modulo 7 y submodulo 0 sigue");
    wram[0x10] = 14; CHECK(alttp_door_guard(&c) == 1, "Puertas: otro modulo sale (pocion)");
    wram[0x10] = 7; wram[0x11] = 2; CHECK(alttp_door_guard(&c) == 1, "Puertas: submodulo distinto de 0 sale");
    reset(""); wram[0x10] = 14; CHECK(alttp_door_guard(&c) == 0, "Puertas: sin la opcion nunca sale");
    reset("fix_stair_tags"); wram[0x11] = 0; CHECK(alttp_stair_tags_guard(&c) == 0, "Escaleras: submodulo 0 sigue con las etiquetas");
    wram[0x11] = 16; CHECK(alttp_stair_tags_guard(&c) == 1, "Escaleras: submodulo distinto de 0 sale");
    reset("fix_skullwoods_door"); wram[0x10] = 7; CHECK(alttp_skullwoods_guard(&c) == 0, "Skull Woods: modulo 7 sigue");
    wram[0x10] = 9; CHECK(alttp_skullwoods_guard(&c) == 1, "Skull Woods: otro modulo salta al final");
    reset("fix_mushroom_warp"); wram[0x11] = 0; CHECK(alttp_mushroom_guard(&c) == 0, "Seta: sin submodulo se puede coger");
    wram[0x11] = 35; CHECK(alttp_mushroom_guard(&c) == 1, "Seta: durante el warp del espejo no");
    reset("fix_double_absorb"); c.x = 3; wram[0x0DD0 + 3] = 0; CHECK(alttp_heart_guard(&c) == 1, "Corazon: ya absorbido sale");
    wram[0x0DD0 + 3] = 9; CHECK(alttp_heart_guard(&c) == 0, "Corazon: sin absorber sigue");
    reset(""); c.x = 3; wram[0x0DD0 + 3] = 0; CHECK(alttp_heart_guard(&c) == 0, "Corazon: sin la opcion sigue");
    reset("fix_hidden_hookshot"); c.x = 5; wram[0x0DA0 + 5] = 7; CHECK(alttp_hidden_hookshot_guard(&c) == 0 && wram[0x0DA0 + 5] == 0, "Gancho: el escondido se suelta y sigue");
    reset(""); c.x = 5; wram[0x0DA0 + 5] = 7; alttp_hidden_hookshot_guard(&c); CHECK(wram[0x0DA0 + 5] == 7, "Gancho: sin la opcion no cambia nada");
    reset("fix_camera_twice"); alttp_camera_frame(&c); CHECK(alttp_camera_guard(&c) == 0, "Camara: antes de aplicarla no salta la llamada");
    alttp_camera_applied(&c); CHECK(alttp_camera_guard(&c) == 1, "Camara: ya aplicada en el fotograma salta la segunda");
    alttp_camera_frame(&c); CHECK(alttp_camera_guard(&c) == 0, "Camara: el fotograma siguiente vuelve a empezar");
    reset(""); alttp_camera_applied(&c); CHECK(alttp_camera_guard(&c) == 0, "Camara: sin la opcion nunca salta");
    reset("fix_bunny_walk"); wram[0x5D] = 0x1C; c.a = 0x1C; CHECK(alttp_bunny_walk_guard(&c) == 1 && c.a == 0x17, "Conejo: el temporal usa la animacion del permanente");
    wram[0x5D] = 0x17; CHECK(alttp_bunny_walk_guard(&c) == 0, "Conejo: el permanente sigue por su camino");
    reset(""); wram[0x5D] = 0x1C; CHECK(alttp_bunny_walk_guard(&c) == 0, "Conejo: sin la opcion no cambia");
    return bad;
}
