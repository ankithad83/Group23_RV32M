/* link.ld -- Harvard layout: code in the program ROM, stack in data memory.
 * DMEM matches rtl/data_mem.v (4 KB at 0). The ROM holds 256 words/program.  */
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 1K
    DMEM (rw) : ORIGIN = 0x00000000, LENGTH = 4K
}
SECTIONS {
    .text : { *(.text.start) *(.text*) } > IMEM
    /* programs are written so these stay empty; the check below fails the link if not */
    .rodata : { *(.rodata*) *(.srodata*) } > DMEM
    .data   : { *(.data*) *(.sdata*) *(.bss*) *(.sbss*) } > DMEM
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
    ASSERT(SIZEOF(.rodata) == 0 && SIZEOF(.data) == 0, "program needs .data/.rodata - DMEM is not initialised")
}
