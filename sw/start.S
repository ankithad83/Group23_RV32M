# start.S -- minimal startup: set stack pointer, call main, then halt
    .section .text.start
    .globl _start
_start:
    la   sp, _stack_top
    call main
1:  j    1b                 # stay here; result is already on the LEDs
