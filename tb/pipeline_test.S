# pipeline_test.S -- directed hazard test; same sequence as the slide-3 timing diagram
# (assembled into tb/tb_pipeline.v by scripts/gen_pipeline_tb.py)
    .globl _start
_start:
    addi x10, x0, 0x100     # data pointer (mem[0x100] = 5 is preset by the testbench)
    addi x7,  x0, 7
    addi x9,  x0, 6
    addi x12, x0, 5
    addi x14, x0, 99        # must stay 99 (wrong-path sub is flushed)
    nop
    nop
    nop
seq:
    lw   x5, 0(x10)         # cycle 1 IF, 2 EX, 3 WB
    add  x6, x5, x7         # load-use: 1 stall, EX at cycle 4        x6 = 12
    bne  x6, x0, L          # taken, resolves in EX at cycle 5
    sub  x14, x6, x6        # wrong path: flushed
    nop
    nop
L:  mul  x8, x6, x9         # EX start 7, done 8                      x8 = 72
    add  x10, x8, x8        # waits for MUL, forwarded, EX at 9       x10 = 144
    div  x11, x10, x12      # EX 10 .. 43                             x11 = 28
    addi x13, x11, 1        # waits for DIV, EX at 44                 x13 = 29
    addi x1, x0, 1          # back-to-back forwarding chain
    addi x2, x1, 1
    add  x3, x2, x1
    add  x4, x3, x2         # x4 = 5
    sw   x4, 4(x0)          # store then load it back
    lw   x15, 4(x0)
    addi x16, x15, 1        # load-use again -> x16 = 6
    mul  x17, x16, x16      # MUL right behind ALU result: 36
    mul  x18, x17, x16      # back-to-back MUL (dependent): 216
    divu x19, x18, x16      # 36
    rem  x20, x18, x7       # 216 % 7 = 6
end:
    j    end
