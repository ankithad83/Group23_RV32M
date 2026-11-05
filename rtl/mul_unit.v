`timescale 1ns/1ps
// =============================================================================
// mul_unit.v  --  RV32M multiplier (MUL, MULH, MULHSU, MULHU)
// Group 23 : Hardware RV32M Extension for a 3-stage RV32I processor (Nexys A7)
//
// Latency : 2 cycles in EX
//   cycle 1 (start) : operands are sign/zero-extended to 33 bits and registered
//   cycle 2 (done)  : 33x33 signed multiply (maps to DSP48E1 blocks),
//                     result selected and driven out, done = 1
//
// Handshake : start (1-cycle pulse, only accepted when idle) -> busy -> done
//
// funct3[1:0]  op       a        b         result
//   00         MUL      x        x         product[31:0]
//   01         MULH     signed   signed    product[63:32]
//   10         MULHSU   signed   unsigned  product[63:32]
//   11         MULHU    unsigned unsigned  product[63:32]
// =============================================================================
module mul_unit (
    input  wire        clk,
    input  wire        rst,        // synchronous, active high
    input  wire        start,      // pulse: begin a multiply
    input  wire [1:0]  op,         // funct3[1:0]
    input  wire [31:0] a,          // rs1
    input  wire [31:0] b,          // rs2
    output wire        busy,       // operands latched, result not yet out
    output wire        done,       // result valid this cycle
    output reg  [31:0] result
);
    reg               state;       // 0 = idle, 1 = result cycle
    reg signed [32:0] a_ext, b_ext;
    reg               high;        // 1 = return upper 32 bits

    // operand extension: the extra MSB is the sign bit for signed operands,
    // 0 for unsigned ones, so one signed 33x33 multiply covers all 4 ops.
    wire a_signed = (op == 2'b01) || (op == 2'b10);   // MULH, MULHSU
    wire b_signed = (op == 2'b01);                    // MULH

    always @(posedge clk) begin
        if (rst) begin
            state <= 1'b0;
            a_ext <= 33'sd0;
            b_ext <= 33'sd0;
            high  <= 1'b0;
        end else if (state == 1'b0) begin
            if (start) begin
                a_ext <= {a_signed & a[31], a};
                b_ext <= {b_signed & b[31], b};
                high  <= (op != 2'b00);
                state <= 1'b1;
            end
        end else begin
            state <= 1'b0;                // result consumed this cycle
        end
    end

    // 33 x 33 signed -> 66 bit; bits [63:0] are the RISC-V 64-bit product.
    // Vivado maps this multiply onto DSP48E1 blocks automatically.
    wire signed [65:0] product = a_ext * b_ext;

    always @(*) begin
        result = high ? product[63:32] : product[31:0];
    end

    assign busy = (state == 1'b1);
    assign done = (state == 1'b1);
endmodule
