# Makefile -- builds every test program twice:
#   build/rv32im/<prog>.mem   hardware MUL/DIV        (-march=rv32im)
#   build/rv32i/<prog>.mem    software mul/div (libgcc) (-march=rv32i)
# make            build all       make dump      disassemble rv32im builds
# make expected   run all programs on the PC and print the expected results
PROGS  = matmul gcd factorial fir primes
EXTRA  = isa_test        # hardware self-check, rv32im build only
CROSS ?= riscv64-unknown-elf-
CC     = $(CROSS)gcc
OBJCOPY= $(CROSS)objcopy
OBJDUMP= $(CROSS)objdump
CFLAGS = -mabi=ilp32 -O1 -ffreestanding -fno-jump-tables -fno-builtin \
         -nostdlib -nostartfiles -T link.ld

all: $(foreach a,rv32im rv32i,$(foreach p,$(PROGS),build/$(a)/$(p).mem)) $(foreach p,$(EXTRA),build/rv32im/$(p).mem)

build/%.mem: build/%.elf
	$(OBJCOPY) -O binary -j .text $< build/$*.bin
	python3 bin2mem.py build/$*.bin $@

build/rv32im/%.elf: %.c start.S rv32m_test.h link.ld
	@mkdir -p build/rv32im
	$(CC) -march=rv32im $(CFLAGS) start.S $< -lgcc -o $@

build/rv32i/%.elf: %.c start.S rv32m_test.h link.ld
	@mkdir -p build/rv32i
	$(CC) -march=rv32i $(CFLAGS) start.S $< -lgcc -o $@

dump: all
	@for p in $(PROGS) $(EXTRA); do $(OBJDUMP) -d build/rv32im/$$p.elf > build/rv32im/$$p.dis; done

expected:
	@for p in $(PROGS) $(EXTRA); do gcc -DHOST_RUN -O1 -o /tmp/$$p $$p.c && /tmp/$$p; done

clean:
	rm -rf build
.SECONDARY:
