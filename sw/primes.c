/* primes.c -- division-heavy: count primes below 1000 by trial division
 * (REM) and the digit sum of 2^31-1 (DIV / REM by 10).
 * result = prime_count * 100 + digit_sum                                  */
#include "rv32m_test.h"
#define EXPECTED 16846u   /* from: make expected (host run) */

int main(void) {
    unsigned limit = (unsigned)SEED() * 333u + 1u;     /* 1000 */
    unsigned count = 0;
    for (unsigned n = 2; n < limit; n++) {
        unsigned prime = 1;
        for (unsigned d = 2; d * d <= n; d++)
            if (n % d == 0) { prime = 0; break; }
        count += prime;
    }
    int v = 0x7FFFFFFF - (SEED() - 3);                  /* 2147483647 */
    int digits = 0;
    while (v > 0) { digits += v % 10; v /= 10; }
    REPORT(count * 100u + (unsigned)digits, EXPECTED);
}
