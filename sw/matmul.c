/* matmul.c -- 8x8 integer matrix multiply (multiply-heavy: 512 MULs)
 * C = A * B,  result = weighted checksum of C                              */
#include "rv32m_test.h"
#define N 8
#define EXPECTED 573248u   /* from: make expected (host run) */

int main(void) {
    int s = SEED();
    int A[N][N], B[N][N], C[N][N];
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            A[i][j] = i * 3 + j - s;          /* includes negative values */
            B[i][j] = i - 2 * j + s * 5;
        }
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int acc = 0;
            for (int k = 0; k < N; k++) acc += A[i][k] * B[k][j];
            C[i][j] = acc;
        }
    unsigned sum = 0;
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) sum += (unsigned)C[i][j] * (unsigned)(i + j + 1);
    REPORT(sum, EXPECTED);
}
