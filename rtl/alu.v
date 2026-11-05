`timescale 1ns/1ps
// =============================================================================
// alu.v  --  RV32I integer ALU (existing block, Stage 2 / EX)
// =============================================================================
module alu (
    input  wire [3:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);
    localparam ADD = 4'd0, SUB = 4'd1, SLL = 4'd2, SLT = 4'd3, SLTU = 4'd4,
               XOR_ = 4'd5, SRL = 4'd6, SRA = 4'd7, OR_ = 4'd8, AND_ = 4'd9;
    wire [4:0] sh = b[4:0];
    always @(*) begin
        case (op)
            ADD:     y = a + b;
            SUB:     y = a - b;
            SLL:     y = a << sh;
            SLT:     y = {31'b0, ($signed(a) < $signed(b))};
            SLTU:    y = {31'b0, (a < b)};
            XOR_:    y = a ^ b;
            SRL:     y = a >> sh;
            SRA:     y = $signed(a) >>> sh;
            OR_:     y = a | b;
            AND_:    y = a & b;
            default: y = 32'd0;
        endcase
    end
endmodule
