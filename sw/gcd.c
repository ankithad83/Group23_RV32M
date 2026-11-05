/* gcd.c -- Euclid's GCD using REM (%) on 20 number pairs                  */
#include "rv32m_test.h"
#define EXPECTED 360u   /* from: make expected (host run) */

static unsigned gcd(unsigned a, unsigned b) {
    while (b != 0) { unsigned t = a % b; a = b; b = t; }
    return a;
}

int main(void) {
    unsigned s = (unsigned)SEED();
    unsigned sum = 0;
    for (unsigned k = 1; k <= 20; k++) {
        unsigned a = k * 1260u * s;           /* 3780, 7560, ...        */
        unsigned b = (k + 7u) * 462u + s * 11u;
        sum += gcd(a, b);
    }
    REPORT(sum, EXPECTED);
}
