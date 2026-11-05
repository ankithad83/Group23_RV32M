/* isa_test.c -- extra self-check: byte/half loads+stores (sign and zero
 * extension), shifts, compares, logic, and every RV32M operation.
 * (Division by zero and INT_MIN / -1 are covered by the unit testbench.)    */
#include "rv32m_test.h"
#define EXPECTED 3643198493u   /* from: make expected (host run) */

int main(void) {
    int s = SEED();
    signed char    sc[16];
    unsigned char  uc[16];
    short          ss[8];
    unsigned short us[8];
    for (int i = 0; i < 16; i++) { sc[i] = (signed char)(i * 37 + s * 50); uc[i] = (unsigned char)(i * 91 + s); }
    for (int i = 0; i < 8;  i++) { ss[i] = (short)(i * 9001 - s * 20000);  us[i] = (unsigned short)(i * 7919 + s * 11111); }

    unsigned h = 0;
    for (int i = 0; i < 16; i++) { h = h * 33u + (unsigned)(int)sc[i]; h = h * 33u + uc[i]; }
    for (int i = 0; i < 8;  i++) { h = h * 33u + (unsigned)(int)ss[i]; h = h * 33u + us[i]; }

    int      a  = -123456 * s + 77;
    unsigned ua = 0xF0F0A5A5u ^ (unsigned)s;
    h ^= (unsigned)(a >> 3) ^ (ua >> 5) ^ (ua << 7) ^ (unsigned)(a < (int)ua) ^ ((unsigned)(ua < 0x80000000u) << 3);
    h += (ua & 0xFF00FF00u) | (ua ^ 0x0F0F0F0Fu);

    int b = a * s + 12345;                                              /* MUL           */
    long long p = (long long)a * b;                                     /* MUL + MULH    */
    h ^= (unsigned)(p >> 32) + (unsigned)p;
    unsigned long long up = (unsigned long long)ua * (unsigned)b;       /* MULHU         */
    h += (unsigned)(up >> 32);
    long long mixed = (long long)a * (unsigned long long)ua;            /* MULHSU-style  */
    h ^= (unsigned)(mixed >> 32);
    h += (unsigned)(a / (s + 4)) + (unsigned)(a % (s + 4))              /* DIV, REM      */
       + ua / (unsigned)(s + 9) + ua % (unsigned)(s + 9);               /* DIVU, REMU    */
    REPORT(h, EXPECTED);
}
