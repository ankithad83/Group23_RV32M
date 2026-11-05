`timescale 1ns/1ps
// =============================================================================
// decoder.v  --  Decode / Control (MODIFIED block, Stage 1)
// RV32I decode plus the M-extension: an OP (0110011) instruction with
// funct7 = 0000001 is a valid register-writing R-type. The ALU op it gets is
// irrelevant, because the EX result mux selects the m_unit result for it.
// =============================================================================
module decoder (
    input  wire [31:0] instr,
    output reg  [31:0] imm,
    output reg  [3:0]  alu_op,
    output reg  [1:0]  a_sel,        // 0 = rs1, 1 = pc, 2 = zero
    output reg         b_sel,        // 0 = rs2, 1 = imm
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output reg         uses_rs1,
    output reg         uses_rs2
);
    localparam ADD = 4'd0, SUB = 4'd1, SLL = 4'd2, SLT = 4'd3, SLTU = 4'd4,
               XOR_ = 4'd5, SRL = 4'd6, SRA = 4'd7, OR_ = 4'd8, AND_ = 4'd9;

    wire [6:0] opcode = instr[6:0];
    wire [2:0] f3     = instr[14:12];
    wire       f7b5   = instr[30];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    reg [3:0] alu_r;     // ALU op for OP (register-register)
    reg [3:0] alu_i;     // ALU op for OP-IMM
    always @(*) begin
        case (f3)
            3'b000: begin alu_r = f7b5 ? SUB : ADD; alu_i = ADD; end
            3'b001: begin alu_r = SLL;  alu_i = SLL;  end
            3'b010: begin alu_r = SLT;  alu_i = SLT;  end
            3'b011: begin alu_r = SLTU; alu_i = SLTU; end
            3'b100: begin alu_r = XOR_; alu_i = XOR_; end
            3'b101: begin alu_r = f7b5 ? SRA : SRL; alu_i = f7b5 ? SRA : SRL; end
            3'b110: begin alu_r = OR_;  alu_i = OR_;  end
            default: begin alu_r = AND_; alu_i = AND_; end
        endcase
    end

    always @(*) begin
        imm = 32'd0; alu_op = ADD; a_sel = 2'd0; b_sel = 1'b0;
        reg_write = 1'b0; mem_read = 1'b0; mem_write = 1'b0;
        is_branch = 1'b0; is_jal = 1'b0; is_jalr = 1'b0;
        uses_rs1 = 1'b0; uses_rs2 = 1'b0;
        case (opcode)
            7'b0110111: begin imm = imm_u; a_sel = 2'd2; b_sel = 1'b1; reg_write = 1'b1; end   // LUI
            7'b0010111: begin imm = imm_u; a_sel = 2'd1; b_sel = 1'b1; reg_write = 1'b1; end   // AUIPC
            7'b1101111: begin imm = imm_j; is_jal = 1'b1; reg_write = 1'b1; end                // JAL
            7'b1100111: begin imm = imm_i; is_jalr = 1'b1; reg_write = 1'b1; uses_rs1 = 1'b1; end // JALR
            7'b1100011: begin imm = imm_b; is_branch = 1'b1; uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // BRANCH
            7'b0000011: begin imm = imm_i; b_sel = 1'b1; mem_read = 1'b1; reg_write = 1'b1; uses_rs1 = 1'b1; end // LOAD
            7'b0100011: begin imm = imm_s; b_sel = 1'b1; mem_write = 1'b1; uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // STORE
            7'b0010011: begin imm = imm_i; b_sel = 1'b1; reg_write = 1'b1; uses_rs1 = 1'b1; alu_op = alu_i; end // OP-IMM
            7'b0110011: begin reg_write = 1'b1; uses_rs1 = 1'b1; uses_rs2 = 1'b1; alu_op = alu_r; end         // OP + RV32M
            default: ;   // FENCE / SYSTEM / unknown: treated as NOP
        endcase
    end
endmodule
