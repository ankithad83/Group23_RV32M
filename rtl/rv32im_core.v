`timescale 1ns/1ps
// =============================================================================
// rv32im_core.v  --  3-stage RV32IM processor (Group 23)
//
//   STAGE 1 : IF + ID   PC, instruction memory read, decode, register read
//   ---- ID/EX register ----
//   STAGE 2 : EX        forwarding muxes, ALU, m_unit (mul_unit + div_unit),
//                       branch compare, EX result mux
//   ---- EX/MEM register ----
//   STAGE 3 : MEM + WB  data-memory access (via the dmem_* port), load align,
//                       write-back mux, register-file write
//
// Instruction memory is asynchronous-read (combinational from pc), so Stage 1
// has no register of its own: "holding Stage 1" means holding the PC.
//
// Timing behaviour (matches the timing diagram in the presentation):
//   * load-use stall  : 1 cycle        * taken branch / jump : 1 cycle flush
//   * MUL holds EX 2 cycles            * DIV holds EX ~34 cycles
//
// Data port (word based, the SoC does address decode and the memory itself):
//   dmem_addr  byte address, dmem_wdata already lane-shifted, dmem_be byte
//   enables, dmem_we write strobe, dmem_rdata raw 32-bit word at dmem_addr.
// =============================================================================
module rv32im_core (
    input  wire        clk,
    input  wire        rst,                 // synchronous, active high
    // instruction port
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,
    // data port
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_be,
    output wire        dmem_we,
    input  wire [31:0] dmem_rdata,
    // for the performance counters
    output wire        retire,              // a real instruction leaves Stage 3
    output wire        stall_hold           // Stage 1 held (load-use or M stall)
);
    // ------------------------------------------------------------------ STAGE 1
    reg  [31:0] pc;
    wire [31:0] id_instr = imem_data;
    assign imem_addr = pc;

    wire [4:0] id_rs1 = id_instr[19:15];
    wire [4:0] id_rs2 = id_instr[24:20];
    wire [4:0] id_rd  = id_instr[11:7];

    wire [31:0] id_imm;
    wire [3:0]  id_alu_op;
    wire [1:0]  id_a_sel;
    wire        id_b_sel, id_reg_write, id_mem_read, id_mem_write;
    wire        id_is_branch, id_is_jal, id_is_jalr, id_uses_rs1, id_uses_rs2;

    decoder u_dec (
        .instr(id_instr), .imm(id_imm), .alu_op(id_alu_op), .a_sel(id_a_sel),
        .b_sel(id_b_sel), .reg_write(id_reg_write), .mem_read(id_mem_read),
        .mem_write(id_mem_write), .is_branch(id_is_branch), .is_jal(id_is_jal),
        .is_jalr(id_is_jalr), .uses_rs1(id_uses_rs1), .uses_rs2(id_uses_rs2)
    );

    // register file: read here, written from Stage 3
    wire        wb_we;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;
    wire [31:0] id_rs1_val, id_rs2_val;

    regfile u_rf (
        .clk(clk), .we(wb_we), .waddr(wb_rd), .wdata(wb_data),
        .raddr1(id_rs1), .raddr2(id_rs2), .rdata1(id_rs1_val), .rdata2(id_rs2_val)
    );

    // ------------------------------------------------- ID/EX pipeline register
    reg         idex_valid;
    reg  [31:0] idex_pc, idex_instr, idex_rs1_val, idex_rs2_val, idex_imm;
    reg  [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg  [3:0]  idex_alu_op;
    reg  [1:0]  idex_a_sel;
    reg         idex_b_sel, idex_reg_write, idex_mem_read, idex_mem_write;
    reg         idex_is_branch, idex_is_jal, idex_is_jalr;

    // ------------------------------------------------------------------ STAGE 2
    wire        fwd_a_en, fwd_b_en;
    reg  [31:0] exmem_result;                       // declared here, driven below
    reg         exmem_reg_write;
    reg  [4:0]  exmem_rd;

    forward_unit u_fwd (
        .exmem_reg_write(exmem_reg_write), .exmem_rd(exmem_rd),
        .idex_rs1(idex_rs1), .idex_rs2(idex_rs2), .fwd_a(fwd_a_en), .fwd_b(fwd_b_en)
    );

    wire [31:0] fwd_a = fwd_a_en ? exmem_result : idex_rs1_val;   // forwarding muxes
    wire [31:0] fwd_b = fwd_b_en ? exmem_result : idex_rs2_val;

    // ALU
    wire [31:0] alu_a = (idex_a_sel == 2'd1) ? idex_pc :
                        (idex_a_sel == 2'd2) ? 32'd0   : fwd_a;
    wire [31:0] alu_b = idex_b_sel ? idex_imm : fwd_b;
    wire [31:0] alu_out;
    alu u_alu (.op(idex_alu_op), .a(alu_a), .b(alu_b), .y(alu_out));

    // M extension (mul_unit + div_unit) beside the ALU
    wire        m_is_m, m_stall;
    wire [31:0] m_result;
    m_unit u_m (
        .clk(clk), .rst(rst), .ex_valid(idex_valid), .ex_instr(idex_instr),
        .rs1(fwd_a), .rs2(fwd_b),
        .is_m(m_is_m), .stall_req(m_stall), .m_result(m_result)
    );

    // branch / jump resolution in EX
    wire [2:0] ex_f3 = idex_instr[14:12];
    wire       eq  = (fwd_a == fwd_b);
    wire       lt  = ($signed(fwd_a) < $signed(fwd_b));
    wire       ltu = (fwd_a < fwd_b);
    reg        br_take;
    always @(*) begin
        case (ex_f3)
            3'b000:  br_take = eq;
            3'b001:  br_take = ~eq;
            3'b100:  br_take = lt;
            3'b101:  br_take = ~lt;
            3'b110:  br_take = ltu;
            3'b111:  br_take = ~ltu;
            default: br_take = 1'b0;
        endcase
    end
    wire        ex_redirect = idex_valid & ((idex_is_branch & br_take) | idex_is_jal | idex_is_jalr);
    wire [31:0] br_target   = idex_pc + idex_imm;
    wire [31:0] jalr_target = (fwd_a + idex_imm) & 32'hFFFF_FFFE;
    wire [31:0] ex_target   = idex_is_jalr ? jalr_target : br_target;
    wire [31:0] link        = idex_pc + 32'd4;

    // EX result mux: ALU / M unit / link address
    wire [31:0] ex_result = (idex_is_jal | idex_is_jalr) ? link :
                            m_is_m                       ? m_result : alu_out;

    // ------------------------------------------------------------ hazard unit
    wire pc_en, idex_hold, idex_bubble, exmem_bubble;
    hazard_unit u_haz (
        .idex_valid(idex_valid), .idex_mem_read(idex_mem_read), .idex_rd(idex_rd),
        .id_rs1(id_rs1), .id_rs2(id_rs2),
        .id_uses_rs1(id_uses_rs1), .id_uses_rs2(id_uses_rs2),
        .m_stall(m_stall), .ex_redirect(ex_redirect),
        .pc_en(pc_en), .idex_hold(idex_hold), .idex_bubble(idex_bubble),
        .exmem_bubble(exmem_bubble)
    );
    assign stall_hold = ~pc_en;

    // PC
    always @(posedge clk) begin
        if (rst)        pc <= 32'd0;
        else if (pc_en) pc <= ex_redirect ? ex_target : (pc + 32'd4);
    end

    // ID/EX update
    always @(posedge clk) begin
        if (rst) begin
            idex_valid <= 1'b0;
        end else if (idex_hold) begin
            // keep the M instruction in EX
        end else if (idex_bubble) begin
            idex_valid <= 1'b0;
        end else begin
            idex_valid     <= 1'b1;
            idex_pc        <= pc;
            idex_instr     <= id_instr;
            idex_rs1_val   <= id_rs1_val;
            idex_rs2_val   <= id_rs2_val;
            idex_imm       <= id_imm;
            idex_rs1       <= id_rs1;
            idex_rs2       <= id_rs2;
            idex_rd        <= id_rd;
            idex_alu_op    <= id_alu_op;
            idex_a_sel     <= id_a_sel;
            idex_b_sel     <= id_b_sel;
            idex_reg_write <= id_reg_write;
            idex_mem_read  <= id_mem_read;
            idex_mem_write <= id_mem_write;
            idex_is_branch <= id_is_branch;
            idex_is_jal    <= id_is_jal;
            idex_is_jalr   <= id_is_jalr;
        end
    end

    // ------------------------------------------------ EX/MEM pipeline register
    reg         exmem_valid, exmem_mem_read, exmem_mem_write;
    reg  [31:0] exmem_store_data;
    reg  [2:0]  exmem_f3;

    always @(posedge clk) begin
        if (rst || exmem_bubble) begin
            exmem_valid     <= 1'b0;
            exmem_reg_write <= 1'b0;
            exmem_mem_read  <= 1'b0;
            exmem_mem_write <= 1'b0;
        end else begin
            exmem_valid      <= idex_valid;
            exmem_reg_write  <= idex_valid & idex_reg_write;
            exmem_mem_read   <= idex_valid & idex_mem_read;
            exmem_mem_write  <= idex_valid & idex_mem_write;
            exmem_result     <= ex_result;
            exmem_store_data <= fwd_b;
            exmem_rd         <= idex_rd;
            exmem_f3         <= ex_f3;
        end
    end

    // ------------------------------------------------------------------ STAGE 3
    assign dmem_addr = exmem_result;
    assign dmem_we   = exmem_mem_write;

    // store lane alignment
    reg [31:0] st_data;
    reg [3:0]  st_be;
    always @(*) begin
        case (exmem_f3[1:0])
            2'b00:   begin st_data = {4{exmem_store_data[7:0]}};
                           st_be   = 4'b0001 << exmem_result[1:0]; end
            2'b01:   begin st_data = {2{exmem_store_data[15:0]}};
                           st_be   = exmem_result[1] ? 4'b1100 : 4'b0011; end
            default: begin st_data = exmem_store_data;
                           st_be   = 4'b1111; end
        endcase
    end
    assign dmem_wdata = st_data;
    assign dmem_be    = st_be;

    // load alignment + sign extension
    wire [31:0] ld_shift = dmem_rdata >> {exmem_result[1:0], 3'b000};
    reg  [31:0] load_data;
    always @(*) begin
        case (exmem_f3)
            3'b000:  load_data = {{24{ld_shift[7]}},  ld_shift[7:0]};    // LB
            3'b001:  load_data = {{16{ld_shift[15]}}, ld_shift[15:0]};   // LH
            3'b100:  load_data = {24'b0, ld_shift[7:0]};                 // LBU
            3'b101:  load_data = {16'b0, ld_shift[15:0]};                // LHU
            default: load_data = dmem_rdata;                             // LW
        endcase
    end

    // write-back mux and register-file write
    assign wb_data = exmem_mem_read ? load_data : exmem_result;
    assign wb_rd   = exmem_rd;
    assign wb_we   = exmem_reg_write;

    assign retire  = exmem_valid;
endmodule
