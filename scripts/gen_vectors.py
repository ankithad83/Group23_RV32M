#!/usr/bin/env python3
"""
gen_vectors.py -- golden I/O vectors for mul_unit and div_unit (RISC-V M spec)

Writes:
  mul_vectors.hex   one vector per line: op  a  b  expected   (32-bit hex words)
  div_vectors.hex   same format
op = funct3[1:0]   mul: 0 MUL 1 MULH 2 MULHSU 3 MULHU
                   div: 0 DIV 1 DIVU 2 REM  3 REMU

Usage:  python3 gen_vectors.py [num_random_per_op] [seed]
"""
import random
import sys

MASK = 0xFFFF_FFFF
INT_MIN = 0x8000_0000


def s32(x):
    """unsigned 32-bit -> signed Python int"""
    return x - (1 << 32) if x & 0x8000_0000 else x


def ref_mul(op, a, b):
    if op == 0:                                   # MUL
        return (a * b) & MASK
    if op == 1:                                   # MULH  (s x s)
        return ((s32(a) * s32(b)) >> 32) & MASK
    if op == 2:                                   # MULHSU (s x u)
        return ((s32(a) * b) >> 32) & MASK
    return ((a * b) >> 32) & MASK                 # MULHU (u x u)


def trunc_div(n, d):
    """division rounding toward zero (C / RISC-V semantics)"""
    q = abs(n) // abs(d)
    return -q if (n < 0) != (d < 0) else q


def ref_div(op, a, b):
    if op in (0, 2):                              # signed DIV / REM
        n, d = s32(a), s32(b)
        if d == 0:
            return MASK if op == 0 else a
        if n == -(1 << 31) and d == -1:           # overflow
            return INT_MIN if op == 0 else 0
        q = trunc_div(n, d)
        r = n - q * d
        return (q if op == 0 else r) & MASK
    # unsigned DIVU / REMU
    if b == 0:
        return MASK if op == 1 else a
    return (a // b) & MASK if op == 1 else (a % b) & MASK


EDGE = [0, 1, 2, 3, 7, 10, 0x7FFF_FFFF, 0x8000_0000, 0x8000_0001,
        0xFFFF_FFFF, 0xFFFF_FFFE, 0x0000_FFFF, 0xFFFF_0000, 0x1234_5678,
        0xDEAD_BEEF, 0x5555_5555, 0xAAAA_AAAA]


def build(ref, n_rand, rng):
    vecs = []
    for op in range(4):
        for a in EDGE:                            # every edge pair
            for b in EDGE:
                vecs.append((op, a, b, ref(op, a, b)))
        for _ in range(n_rand):                   # random, incl. small values
            a = rng.getrandbits(32) if rng.random() < 0.7 else rng.randrange(-300, 300) & MASK
            b = rng.getrandbits(32) if rng.random() < 0.7 else rng.randrange(-300, 300) & MASK
            vecs.append((op, a, b, ref(op, a, b)))
    return vecs


def write(path, vecs):
    with open(path, "w") as f:
        for op, a, b, e in vecs:
            f.write(f"{op:08x} {a:08x} {b:08x} {e:08x}\n")
    print(f"{path}: {len(vecs)} vectors")


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 23
    rng = random.Random(seed)
    write("mul_vectors.hex", build(ref_mul, n, rng))
    write("div_vectors.hex", build(ref_div, n, rng))
