#!/usr/bin/env python3
"""
iss.py -- tiny RV32IM instruction-set simulator (golden model for the C tests)

  python3 iss.py prog.mem [--led 0x2000] [--pass 0x2004]

Runs the program until it reaches the final `j .` loop, then prints the LED
value, the PASS flag, the instruction count and an ESTIMATED cycle count for
the 3-stage pipeline:  1 cycle/instr + 1 per load-use stall + 1 per taken
branch/jump + 1 extra per MUL* + 33 extra per DIV*/REM*.
The estimate is for the speed-up table only; real numbers come from your
simulation / performance counters.
Harvard model: instructions from the .mem file, data memory separate.
"""
import argparse

M32 = 0xFFFF_FFFF


def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def s32(v):
    return sx(v, 32)


def run(words, led_addr, pass_addr, max_steps=50_000_000):
    x = [0] * 32
    dmem = {}
    io = {}
    pc = 0
    instrs = cycles = 0
    prev_load_rd = 0
    while instrs < max_steps:
        ins = words[pc >> 2]
        op, rd = ins & 0x7F, (ins >> 7) & 31
        f3, rs1, rs2, f7 = (ins >> 12) & 7, (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        a, b = x[rs1], x[rs2]
        nxt = pc + 4
        res = None
        cycles += 1
        if prev_load_rd and prev_load_rd in (rs1, rs2) and op in (0x33, 0x13, 0x03, 0x23, 0x63, 0x67):
            cycles += 1                                   # load-use stall
        prev_load_rd = 0
        if op == 0x37:   res = ins & 0xFFFFF000                                  # LUI
        elif op == 0x17: res = (pc + (ins & 0xFFFFF000)) & M32                   # AUIPC
        elif op == 0x6F:                                                         # JAL
            imm = sx(((ins >> 31) << 20) | (((ins >> 12) & 0xFF) << 12) | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
            res, nxt = pc + 4, (pc + imm) & M32
            if imm == 0:                                                         # j .  -> halt
                break
            cycles += 1
        elif op == 0x67:                                                         # JALR
            res, nxt = pc + 4, (a + sx(ins >> 20, 12)) & ~1 & M32
            cycles += 1
        elif op == 0x63:                                                         # branches
            imm = sx(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) | (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
            take = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b), 6: a < b, 7: a >= b}[f3]
            if take:
                nxt = (pc + imm) & M32
                cycles += 1
        elif op == 0x03:                                                         # loads (word only used here)
            addr = (a + sx(ins >> 20, 12)) & M32
            w = dmem.get(addr & ~3, 0)
            sh = (addr & 3) * 8
            res = {0: sx(w >> sh, 8) & M32, 1: sx(w >> sh, 16) & M32, 2: w, 4: (w >> sh) & 0xFF, 5: (w >> sh) & 0xFFFF}[f3]
            prev_load_rd = rd
        elif op == 0x23:                                                         # stores
            addr = (a + sx(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)) & M32
            if addr in (led_addr, pass_addr):
                io[addr] = b
            else:
                old = dmem.get(addr & ~3, 0)
                sh = (addr & 3) * 8
                mask = {0: 0xFF, 1: 0xFFFF, 2: M32}[f3] << sh
                dmem[addr & ~3] = (old & ~mask | (b << sh) & mask) & M32
        elif op in (0x13, 0x33):
            if op == 0x33 and f7 == 1:                                           # RV32M
                if f3 < 4:
                    cycles += 1
                    p = {0: a * b, 1: s32(a) * s32(b), 2: s32(a) * b, 3: a * b}[f3]
                    res = (p if f3 == 0 else p >> 32) & M32
                else:
                    cycles += 33
                    sa, sb = s32(a), s32(b)
                    if f3 in (4, 6):
                        if sb == 0: q, r = -1, sa
                        elif sa == -2**31 and sb == -1: q, r = sa, 0
                        else:
                            q = abs(sa) // abs(sb) * (-1 if (sa < 0) != (sb < 0) else 1)
                            r = sa - q * sb
                    else:
                        q, r = (M32, a) if b == 0 else (a // b, a % b)
                    res = (q if f3 in (4, 5) else r) & M32
            else:
                imm = b if op == 0x33 else sx(ins >> 20, 12) & M32
                sh = imm & 31
                alt = op == 0x33 and f7 == 0x20 or op == 0x13 and f3 == 5 and f7 == 0x20
                res = {0: (a - imm) if (alt and f3 == 0) else (a + imm),
                       1: a << sh, 2: int(s32(a) < s32(imm)), 3: int(a < imm),
                       4: a ^ imm, 5: (s32(a) >> sh) if alt else (a >> sh),
                       6: a | imm, 7: a & imm}[f3] & M32
        else:
            raise RuntimeError(f"illegal instruction {ins:08x} at pc {pc:08x}")
        if res is not None and rd:
            x[rd] = res & M32
        pc = nxt
        instrs += 1
    return io.get(led_addr), io.get(pass_addr), instrs, cycles


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("mem")
    ap.add_argument("--led", type=lambda v: int(v, 0), default=0x2000)
    ap.add_argument("--pass", dest="pas", type=lambda v: int(v, 0), default=0x2004)
    args = ap.parse_args()
    words = [int(l, 16) for l in open(args.mem) if l.strip()]
    words += [0] * 4096
    led, ok, n, cyc = run(words, args.led, args.pas)
    print(f"{args.mem}: LED={led} PASS={ok} instructions={n} est_cycles={cyc}")
