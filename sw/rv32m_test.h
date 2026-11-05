/* rv32m_test.h -- shared helpers for the Group 23 RV32M test programs
 *
 * These match the memory map in rtl/soc.v (address decode in Stage 3).
 * If you change the map there, change it here and rebuild with `make`.
 */
#ifndef RV32M_TEST_H
#define RV32M_TEST_H

#define LED_ADDR   0x00002000u   /* LED / result register                    */
#define PASS_ADDR  0x00002004u   /* PASS register (write = program finished) */

#ifdef HOST_RUN                   /* build on a PC to get the expected value  */
#include <stdio.h>
#define REPORT(r, exp) do { printf("%s result = %u (0x%08x)\n", __FILE__, \
                            (unsigned)(r), (unsigned)(r)); return 0; } while (0)
#else
#define REPORT(r, exp) do {                                               \
        *(volatile unsigned *)LED_ADDR  = (unsigned)(r);                  \
        *(volatile unsigned *)PASS_ADDR = ((unsigned)(r) == (exp));       \
        return 0; } while (0)
#endif

/* Inputs are built from a volatile seed at run time, so the compiler cannot
 * pre-compute the answer, and no .data / .rodata section is needed
 * (instruction memory and data memory are separate). */
#define SEED() ({ volatile int s_ = 3; s_; })

#endif
