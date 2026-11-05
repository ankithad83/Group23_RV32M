// =============================================================================
// tb_m_unit.v  --  checks m_unit decode + stall_req behaviour
// Models the EX stage of the pipeline: the instruction in EX advances only when
// stall_req is 0 (exactly what the hazard unit will do). Checks:
//   * RV32I instructions (ADD, SUB with funct7=0100000) are NOT taken as M ops
//   * every M op gives the right result, and holds EX for 2 (MUL*) / 34 (DIV*)
//   * back-to-back M ops (MUL,MUL / MUL,DIV / DIV,DIV) restart correctly
// Run: iverilog -o sim tb_m_unit.v ../rtl/m_unit.v ../rtl/mul_unit.v ../rtl/div_unit.v && vvp sim
// =============================================================================
`timescale 1ns/1ps
module tb_m_unit;
    reg clk = 0, rst = 1;
    reg         ex_valid;
    reg  [31:0] ex_instr, rs1, rs2;
    wire        is_m, stall_req;
    wire [31:0] m_result;

    m_unit dut (.clk(clk), .rst(rst), .ex_valid(ex_valid), .ex_instr(ex_instr),
                .rs1(rs1), .rs2(rs2), .is_m(is_m), .stall_req(stall_req), .m_result(m_result));

    always #5 clk = ~clk;

    // R-type encoder: funct7 rs2 rs1 funct3 rd opcode
    function [31:0] rtype(input [6:0] f7, input [2:0] f3);
        rtype = {f7, 5'd2, 5'd1, f3, 5'd3, 7'b0110011};
    endfunction

    // program: instr, rs1, rs2, expected result, expected EX cycles, expect M?
    localparam N = 14;
    reg [31:0] p_ins [0:N-1], p_a [0:N-1], p_b [0:N-1], p_exp [0:N-1];
    integer    p_cyc [0:N-1];
    reg        p_m   [0:N-1];
    integer i, cyc, errors;

    task set(input integer k, input [6:0] f7, input [2:0] f3, input [31:0] a, input [31:0] b,
             input [31:0] e, input integer c, input m);
        begin p_ins[k]=rtype(f7,f3); p_a[k]=a; p_b[k]=b; p_exp[k]=e; p_cyc[k]=c; p_m[k]=m; end
    endtask

    initial begin
        //        f7          f3      rs1           rs2           expected      cyc M?
        set( 0, 7'b0000000, 3'b000, 32'd5,        32'd7,        32'd0,        1, 0); // ADD
        set( 1, 7'b0100000, 3'b000, 32'd5,        32'd7,        32'd0,        1, 0); // SUB
        set( 2, 7'b0000001, 3'b000, 32'd6,        32'd7,        32'd42,       2, 1); // MUL
        set( 3, 7'b0000001, 3'b000, 32'hFFFFFFFD, 32'd4,        32'hFFFFFFF4, 2, 1); // MUL -3*4
        set( 4, 7'b0000001, 3'b001, 32'h80000000, 32'h80000000, 32'h40000000, 2, 1); // MULH
        set( 5, 7'b0000001, 3'b010, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 2, 1); // MULHSU
        set( 6, 7'b0000001, 3'b011, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, 2, 1); // MULHU
        set( 7, 7'b0000001, 3'b100, 32'hFFFFFF9C, 32'd7,        32'hFFFFFFF2, 34,1); // DIV -100/7=-14
        set( 8, 7'b0000001, 3'b110, 32'hFFFFFF9C, 32'd7,        32'hFFFFFFFE, 34,1); // REM  -> -2
        set( 9, 7'b0000001, 3'b101, 32'd100,      32'd0,        32'hFFFFFFFF, 2, 1); // DIVU /0
        set(10, 7'b0000001, 3'b111, 32'd100,      32'd0,        32'd100,      2, 1); // REMU /0
        set(11, 7'b0000001, 3'b100, 32'h80000000, 32'hFFFFFFFF, 32'h80000000, 2, 1); // DIV ovf
        set(12, 7'b0000001, 3'b101, 32'd1000,     32'd3,        32'd333,      34,1); // DIVU
        set(13, 7'b0000000, 3'b111, 32'hF0,       32'h3C,       32'd0,        1, 0); // AND
    end

    initial begin
        errors = 0; ex_valid = 0; ex_instr = 0; rs1 = 0; rs2 = 0;
        repeat (3) @(posedge clk); rst <= 0; @(posedge clk); #1;
        for (i = 0; i < N; i = i + 1) begin
            ex_valid = 1; ex_instr = p_ins[i]; rs1 = p_a[i]; rs2 = p_b[i];
            cyc = 1;
            #1;
            if (is_m !== p_m[i]) begin errors = errors + 1; $display("instr %0d: is_m=%b, expected %b", i, is_m, p_m[i]); end
            while (stall_req) begin
                @(posedge clk); #1; cyc = cyc + 1;
                rs1 = 32'hDEADBEEF; rs2 = 32'hDEADBEEF;   // forwarded values go stale
            end
            if (p_m[i] && m_result !== p_exp[i]) begin
                errors = errors + 1; $display("instr %0d: result %h, expected %h", i, m_result, p_exp[i]);
            end
            if (cyc != p_cyc[i]) begin
                errors = errors + 1; $display("instr %0d: held EX %0d cycles, expected %0d", i, cyc, p_cyc[i]);
            end
            @(posedge clk); #1;                            // instruction leaves EX
        end
        ex_valid = 0;
        $display("m_unit: %0d instructions, %0d errors", N, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
