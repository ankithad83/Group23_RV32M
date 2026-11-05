/* fir.c -- 8-tap FIR filter over 64 signed samples (multiply-accumulate) */
#include "rv32m_test.h"
#define TAPS 8
#define LEN  64
#define EXPECTED 80600956u   /* from: make expected (host run) */

int main(void) {
    int s = SEED();
    int h[TAPS], x[LEN];
    for (int k = 0; k < TAPS; k++) h[k] = (k & 1) ? -(k + s) : (k * 2 + 1);
    for (int n = 0; n < LEN; n++) x[n] = (n * 37 + s) % 101 - 50;   /* signed REM */
    unsigned check = 0;
    for (int n = TAPS - 1; n < LEN; n++) {
        int y = 0;
        for (int k = 0; k < TAPS; k++) y += h[k] * x[n - k];
        check = check * 31u + (unsigned)y;
    }
    REPORT(check, EXPECTED);
}
