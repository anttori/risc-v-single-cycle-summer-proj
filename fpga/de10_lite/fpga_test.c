/*
 * DE10-Lite self-checking bare-metal test for the RV32I single-cycle core.
 *
 *  Phase 1: running-LED animation on LEDR[9:0]  (verifies clock + MMIO writes)
 *  Phase 2: XTEA encrypt/decrypt self-check      (verifies the core + stack in DMEM)
 *  Phase 3: interactive display loop driven by SW[1:0]
 *
 * Constraints imposed by the hardware (see de10_lite_top.sv):
 *  - IMEM and DMEM are separate memories (Harvard), so the program must not
 *    use .data/.rodata/.bss. All variables live on the stack in DMEM and all
 *    constants are encoded as immediates. fpga_link.ld enforces this.
 *  - RV32I only (no M extension): no multiplication, division or libgcc calls.
 */

#include <stdint.h>

/* MMIO map */
#define MMIO_LEDR       (*(volatile uint32_t *)0x00001000u)  /* W: LEDR[9:0], active-high     */
#define MMIO_HEX        (*(volatile uint32_t *)0x00001004u)  /* W: 24-bit value on HEX5..HEX0 */
#define MMIO_HEX_BLANK  (*(volatile uint32_t *)0x00001008u)  /* W: HEX_BLANK[5:0], 1 = off    */
#define MMIO_SW         (*(volatile uint32_t *)0x0000100Cu)  /* R: SW[9:0]                    */

/*
 * Delay per LED step. The core runs at 25 MHz with CPI = 1 and the delay loop
 * is two instructions (addi + bnez), i.e. 2 cycles per iteration:
 * 1875000 * 2 / 25e6 = 150 ms per step, 10 steps = ~1.5 s.
 * Override with -DANIM_STEP_ITERS=<n> to speed up simulation.
 */
#ifndef ANIM_STEP_ITERS
#define ANIM_STEP_ITERS 1875000u
#endif

#define XTEA_ROUNDS     32u
#define XTEA_DELTA      0x9E3779B9u
#define XTEA_SUM_END    0xC6EF3720u   /* XTEA_DELTA * XTEA_ROUNDS (mod 2^32), avoids a multiply */

/* Test vector (same plaintext/key as sw/xtea/xtea_rk.c) */
#define PLAIN_V0        0x00C0FFEEu
#define PLAIN_V1        0xFEE1600Du
#define CIPHER_V0       0xC9E8D495u   /* golden XTEA-32 ciphertext */
#define CIPHER_V1       0x19F7042Eu

static void delay_iters(uint32_t n)
{
    while (n--)
        __asm__ volatile ("");
}

static void xtea_encrypt(volatile uint32_t v[2], const volatile uint32_t key[4])
{
    uint32_t v0 = v[0], v1 = v[1], sum = 0;

    for (uint32_t i = 0; i < XTEA_ROUNDS; i++) {
        v0 += (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
        sum += XTEA_DELTA;
        v1 += (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum >> 11) & 3]);
    }
    v[0] = v0;
    v[1] = v1;
}

static void xtea_decrypt(volatile uint32_t v[2], const volatile uint32_t key[4])
{
    uint32_t v0 = v[0], v1 = v[1], sum = XTEA_SUM_END;

    for (uint32_t i = 0; i < XTEA_ROUNDS; i++) {
        v1 -= (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum >> 11) & 3]);
        sum -= XTEA_DELTA;
        v0 -= (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
    }
    v[0] = v0;
    v[1] = v1;
}

int main(void)
{
    volatile uint32_t v[2];
    volatile uint32_t key[4];
    uint32_t pass;

    /* Phase 1: running LED, one LED per step */
    MMIO_HEX_BLANK = 0x3Fu;
    for (uint32_t i = 0; i < 10; i++) {
        MMIO_LEDR = 1u << i;
        delay_iters(ANIM_STEP_ITERS);
    }
    MMIO_LEDR = 0;

    /* Phase 2: XTEA self-check. The key is built on the stack to avoid .rodata. */
    key[0] = 0x20261021u;
    key[1] = 0x524F4D41u;
    key[2] = 0x33334444u;
    key[3] = 0x55556666u;
    v[0] = PLAIN_V0;
    v[1] = PLAIN_V1;

    xtea_encrypt(v, key);
    pass = (v[0] == CIPHER_V0) && (v[1] == CIPHER_V1);

    xtea_decrypt(v, key);
    pass = pass && (v[0] == PLAIN_V0) && (v[1] == PLAIN_V1);

    /* Phase 3: interactive display loop (v[] holds the decrypted words) */
    for (;;) {
        uint32_t sw   = MMIO_SW;
        uint32_t sel  = (sw >> 1) & 1u;      /* SW[1]: 0 -> v[0], 1 -> v[1] */
        uint32_t word = v[sel];

        MMIO_LEDR = (pass << 9) | (sel << 8) | (word >> 24);

        if (sw & 1u) {                       /* SW[0] = 1: upper byte on HEX1..HEX0 */
            MMIO_HEX_BLANK = 0x3Cu;          /* blank HEX5..HEX2 */
            MMIO_HEX       = word >> 24;
        } else {                             /* SW[0] = 0: lower 24 bits on HEX5..HEX0 */
            MMIO_HEX_BLANK = 0x00u;
            MMIO_HEX       = word & 0x00FFFFFFu;
        }
    }
}
