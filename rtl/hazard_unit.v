`timescale 1ns/1ps
// =============================================================================
// hazard_unit.v  --  Hazard / Stall Unit (MODIFIED block, Stage 1)
//
//   m_stall      from m_unit : the M instruction must stay in EX
//   ex_redirect  from EX     : taken branch / jump -> flush the Stage-1 instr
//   load-use     detected here: instr in ID uses the result of a load in EX
//
// Outputs (the red "stall control" wires of the architecture diagram):
//   pc_en         PC is allowed to update (also the instruction in Stage 1 is
//                 held, because Stage 1 has no register of its own)
//   idex_hold     ID/EX keeps its contents (M instruction stays in EX)
//   idex_bubble   ID/EX gets a bubble (flush or load-use)
//   exmem_bubble  EX/MEM gets a bubble while the M instruction is busy
// Priority: m_stall > redirect > load-use.
// =============================================================================
module hazard_unit (
    input  wire       idex_valid,
    input  wire       idex_mem_read,
    input  wire [4:0] idex_rd,
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire       id_uses_rs1,
    input  wire       id_uses_rs2,
    input  wire       m_stall,
    input  wire       ex_redirect,
    output wire       pc_en,
    output wire       idex_hold,
    output wire       idex_bubble,
    output wire       exmem_bubble
);
    wire load_use = idex_valid & idex_mem_read & (idex_rd != 5'd0) &
                    ((id_uses_rs1 & (idex_rd == id_rs1)) |
                     (id_uses_rs2 & (idex_rd == id_rs2)));

    assign pc_en        = ~m_stall & ~load_use;
    assign idex_hold    = m_stall;
    assign idex_bubble  = ~m_stall & (ex_redirect | load_use);
    assign exmem_bubble = m_stall;
endmodule
