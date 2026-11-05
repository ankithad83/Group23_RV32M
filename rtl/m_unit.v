`timescale 1ns/1ps
// =============================================================================
// m_unit.v  --  RV32M wrapper: decode + mul_unit + div_unit + stall request
// Group 23 : Hardware RV32M Extension for a 3-stage RV32I processor (Nexys A7)
//
// Drop this into the EX stage beside the ALU.
//
//   ex_valid   : a real (non-bubble, non-flushed) instruction is in EX
//   ex_instr   : that instruction (only opcode / funct3 / funct7 are used)
//   rs1 / rs2  : forwarded operand values (same ones the ALU gets)
//
//   is_m       : instruction in EX is an RV32M op -> pick m_result in the
//                EX result mux instead of the ALU result
//   stall_req  : 1 while the M instruction must stay in EX. Feed this into the
//                hazard / stall unit: hold PC, hold IF/ID and ID/EX, and send a
//                bubble into EX/MEM (stage 3) while it is high.
//   m_result   : valid in the cycle where stall_req drops (done = 1)
//
// Timeline for one MUL : cycle 1 start (stall_req=1), cycle 2 done (stall_req=0)
// Timeline for one DIV : cycle 1 start, 32 RUN cycles, cycle 34 done
// Operands are latched in the start cycle, so forwarded values only need to be
// correct in the first EX cycle.
// =============================================================================
module m_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        ex_valid,
    input  wire [31:0] ex_instr,
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    output wire        is_m,
    output wire        stall_req,
    output wire [31:0] m_result
);
    // RV32M encoding: opcode = OP (0110011), funct7 = 0000001
    wire [6:0] opcode = ex_instr[6:0];
    wire [2:0] funct3 = ex_instr[14:12];
    wire [6:0] funct7 = ex_instr[31:25];

    assign is_m       = ex_valid && (opcode == 7'b0110011) && (funct7 == 7'b0000001);
    wire   is_mul     = is_m && (funct3[2] == 1'b0);   // MUL, MULH, MULHSU, MULHU
    wire   is_div     = is_m && (funct3[2] == 1'b1);   // DIV, DIVU, REM, REMU

    wire mul_busy, mul_done, div_busy, div_done;
    wire [31:0] mul_res, div_res;

    // start only when the unit is idle, so the held instruction does not restart it
    wire mul_start = is_mul & ~mul_busy;
    wire div_start = is_div & ~div_busy;

    mul_unit u_mul (
        .clk(clk), .rst(rst), .start(mul_start), .op(funct3[1:0]),
        .a(rs1), .b(rs2), .busy(mul_busy), .done(mul_done), .result(mul_res)
    );

    div_unit u_div (
        .clk(clk), .rst(rst), .start(div_start), .op(funct3[1:0]),
        .a(rs1), .b(rs2), .busy(div_busy), .done(div_done), .result(div_res)
    );

    assign stall_req = (is_mul & ~mul_done) | (is_div & ~div_done);
    assign m_result  = is_div ? div_res : mul_res;
endmodule
