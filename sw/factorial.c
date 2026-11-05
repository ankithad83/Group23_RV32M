/* factorial.c -- 12! (largest factorial that fits in 32 bits) and the
 * sum 1! + 2! + ... + 12!                                                 */
#include "rv32m_test.h"
#define EXPECTED 61297177u   /* from: make expected (host run) */

int main(void) {
    unsigned n = (unsigned)SEED() + 9u;      /* 12 */
    unsigned f = 1, sum = 0;
    for (unsigned i = 1; i <= n; i++) { f *= i; sum += f; }
    REPORT(f ^ sum, EXPECTED);              /* depends on both values   */
}
