#!/bin/sh
# run_tests.sh -- run every testbench (needs iverilog + python3)
#   unit tests : mul_unit, div_unit (golden vectors), m_unit (decode + stall)
#   core tests : pipeline timing vs the slide-3 diagram, then all 11 C programs
#                on the complete processor (takes about a minute)
set -e
cd "$(dirname "$0")"
mkdir -p sim && cd sim
R=../rtl
python3 ../scripts/gen_vectors.py
iverilog -g2005 -Wall -o tb_mul ../tb/tb_mul_unit.v $R/mul_unit.v 2>/dev/null && vvp -n tb_mul | grep -E "mul_unit|PASS|FAIL"
iverilog -g2005 -Wall -o tb_div ../tb/tb_div_unit.v $R/div_unit.v 2>/dev/null && vvp -n tb_div | grep -E "div_unit|PASS|FAIL"
iverilog -g2005 -Wall -o tb_m ../tb/tb_m_unit.v $R/m_unit.v $R/mul_unit.v $R/div_unit.v 2>/dev/null && vvp -n tb_m | grep -E "m_unit|PASS|FAIL"
iverilog -g2005 -o tb_pipeline ../tb/tb_pipeline.v $R/rv32im_core.v $R/alu.v $R/regfile.v $R/decoder.v \
    $R/hazard_unit.v $R/forward_unit.v $R/m_unit.v $R/mul_unit.v $R/div_unit.v && vvp -n tb_pipeline | grep -v finish
iverilog -g2005 -o tb_soc ../tb/tb_soc.v $R/*.v 2>/dev/null && vvp -n tb_soc | grep -v finish
