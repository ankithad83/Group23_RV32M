# Group 23 — Hardware RV32M Extension, complete 3-stage RV32IM processor (Nexys A7)

Everything Vivado needs is plain Verilog (`.v`). The only non-Verilog file is
`constraints/nexys_a7.xdc` (FPGA pin names, needed only for the board).

## Files

```
rtl/   top_nexys_a7.v   board wrapper: reset, switches, LEDs, 8-digit 7-segment  (SYNTHESIS TOP)
       soc.v            core + program ROM + data memory + address decode + LED/PASS regs + counters
       rv32im_core.v    the 3-stage pipeline (Stage 1 IF+ID | Stage 2 EX | Stage 3 MEM+WB)
       decoder.v        decode / control, with the M-extension decode            (modified block)
       hazard_unit.v    stall / flush control: M-busy, load-use, branch flush    (modified block)
       forward_unit.v   EX forwarding select
       regfile.v  alu.v data_mem.v                                               (existing blocks)
       m_unit.v         M decode + start/busy/done + stall request               (NEW)
       mul_unit.v       MUL, MULH, MULHSU, MULHU, 2 cycles, DSP48                (NEW)
       div_unit.v       DIV, DIVU, REM, REMU, 34 cycles, restoring FSM           (NEW)
       perf_counters.v  cycles / instructions retired / stall cycles             (stretch block)
       program_rom.v    GENERATED: all test programs as a Verilog ROM
constraints/nexys_a7.xdc
tb/    tb_soc.v         runs all 11 C programs on the full processor, prints cycles + speed-up
       tb_pipeline.v    directed test = the slide-3 timing diagram, cycle by cycle
       tb_mul_unit.v tb_div_unit.v tb_m_unit.v   unit tests (golden vectors need vectors/*.hex)
       pipeline_test.S  source of tb_pipeline.v
sw/    matmul.c gcd.c factorial.c fir.c primes.c isa_test.c + Makefile (rebuild the programs)
scripts/ gen_vectors.py  gen_program_rom.py  gen_pipeline_tb.py  iss.py  create_vivado_project.tcl
vectors/ mul_vectors.hex div_vectors.hex      (only the two unit testbenches read these)
run_tests.sh            run every testbench with iverilog
```

## Mapping to the architecture diagram

| Diagram block | File |
|---|---|
| PC + Instr. Memory | `rv32im_core.v` (pc), `program_rom.v` |
| Register File | `regfile.v` (write-through: a read in the cycle of a write returns the new value) |
| Decode / Control + M-ext decode | `decoder.v`, `m_unit.v` |
| Hazard / Stall Unit | `hazard_unit.v` |
| Forwarding muxes | `forward_unit.v` + muxes in `rv32im_core.v` |
| ALU, mul_unit, div_unit, EX result mux | `alu.v`, `mul_unit.v`, `div_unit.v`, `rv32im_core.v` |
| Address decode, Data Memory, LED output | `soc.v`, `data_mem.v` |
| perf_counters (stretch) | `perf_counters.v` |
| 2-bit BHT (stretch) | **not implemented** (branches use a fixed 1-cycle taken penalty) |

Memory map (data side): `0x0000-0x0FFF` data memory · `0x2000` LED/result · `0x2004` PASS
(any write = program finished) · `0x2008` cycles · `0x200C` instructions · `0x2010` stalls.

## Run the simulations

**iverilog (Linux / WSL / Mac):** `./run_tests.sh` — expect `PASS` six times (about a minute).

**Vivado, one command:** open Vivado, *Tools > Run Tcl Script*, choose
`scripts/create_vivado_project.tcl` (set `PART` inside for your board first).
Or by hand: *Create Project > RTL Project*, add every `rtl/*.v` as **design sources**,
`tb/tb_soc.v` and `tb/tb_pipeline.v` as **simulation sources** (no .hex files are needed for
these two), then *Run Simulation > Run Behavioral Simulation* and `run all`.
Right-click a testbench > *Set as Top* to switch between `tb_pipeline` and `tb_soc`.
`tb_soc` simulates about 0.9 ms (several minutes in xsim); to go faster set `LAST = 3`
at the top of `tb_soc.v`.

## Run on the board

1. Vivado: set `top_nexys_a7` as the design top, add `constraints/nexys_a7.xdc`, then
   *Run Synthesis → Run Implementation → Generate Bitstream → Hardware Manager → Program Device*.
2. Set SW[15:12] to the program, press the red **CPU_RESET** button.

| SW[15:12] | program | | SW[1:0] | 7-segment shows |
|---|---|---|---|---|
| 0–4 | matmul, gcd, factorial, fir, primes — hardware MUL/DIV | | 00 | result (hex) |
| 5–9 | same five, software mul/div (baseline) | | 01 | cycles |
| 10 | isa_test (self-check) | | 10 | instructions retired |
| | | | 11 | stall cycles |

LED[15] = PASS · LED[14] = DONE · LED[13:0] = low bits of the result.
Read the cycles for program *n*, then for *n+5*: that is your measured speed-up.

## Verified results (RTL simulation, 100 MHz clock)

All 11 programs return the expected value and PASS. Measured cycles:

| Program | rv32i (software) | rv32im (hardware) | speed-up |
|---|---:|---:|---:|
| matmul 8x8 | 26,592 | 6,849 | 3.88x |
| gcd | 7,579 | 5,629 | 1.34x |
| factorial | 408 | 96 | 4.25x |
| fir | 68,044 | 7,756 | 8.77x |
| primes | 588,493 | 180,880 | 3.25x |

`tb_pipeline` shows the slide-3 timing on the real RTL: load-use stall 1 cycle, taken
branch flushes 1 instruction, MUL holds EX 2 cycles, DIV holds EX 34 cycles
(cycles 10–43), forwarding with no extra stall.

## Rebuild the programs (only if you edit the C code)

```
cd sw && make && cd .. && python3 scripts/gen_program_rom.py
```
Needs `riscv64-unknown-elf-gcc`. The programs build their input at run time and need no
data section; the linker fails if one ever does (data memory starts at zero).

## Known limits

- Timing at 100 MHz has not been checked in Vivado. The 33x33 multiply is the likely
  critical path. If *Report Timing Summary* shows a violation there, add one output
  register in `mul_unit.v` (MUL becomes 3 cycles; update `tb_mul_unit.v` and slides 1–3).
- Synthesis was sanity-checked with Yosys only (no latches, 4 DSP48E1, small LUT count).
- Verify the pin names in the XDC against Digilent's master XDC for your board revision.
- JAL/JALR and branches all resolve in EX (1-cycle penalty); there is no branch predictor.
