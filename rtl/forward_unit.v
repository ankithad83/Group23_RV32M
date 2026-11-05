`timescale 1ns/1ps
// =============================================================================
// forward_unit.v  --  select signals for the EX forwarding muxes (existing)
// Producer in Stage 3 (EX/MEM register) -> consumer in EX.
// A load in Stage 3 is never forwarded: the hazard unit has already made the
// consumer wait one cycle and it reads the loaded value through the register
// file's write-through path instead.
// =============================================================================
module forward_unit (
    input  wire       exmem_reg_write,   // already gated by exmem_valid
    input  wire [4:0] exmem_rd,
    input  wire [4:0] idex_rs1,
    input  wire [4:0] idex_rs2,
    output wire       fwd_a,
    output wire       fwd_b
);
    assign fwd_a = exmem_reg_write & (exmem_rd != 5'd0) & (exmem_rd == idex_rs1);
    assign fwd_b = exmem_reg_write & (exmem_rd != 5'd0) & (exmem_rd == idex_rs2);
endmodule
