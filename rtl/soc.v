`timescale 1ns/1ps
// =============================================================================
// soc.v  --  core + program ROM + data memory + address decode + LED/PASS
//            registers + performance counters   (Stage 3 "Address decode")
//
// Memory map (data side)                       sw/rv32m_test.h uses these
//   0x0000_0000 - 0x0000_0FFF  data memory (4 KB, stack at the top)
//   0x0000_2000  LED / result register (R/W)       LED_ADDR
//   0x0000_2004  PASS register (W: bit0 = pass, any write = program finished)
//   0x0000_2008  cycle counter     (R)
//   0x0000_200C  instructions retired (R)
//   0x0000_2010  stall cycles      (R)
// Instruction side: program_rom, 256 words per program, address = pc[9:2].
// prog_sel is sampled while rst = 1, so change it, then reset.
// =============================================================================
module soc (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  prog_sel,
    output wire [31:0] result,        // value the program wrote to LED_ADDR
    output wire        pass,          // PASS register
    output wire        done,          // program wrote PASS (finished)
    output wire [31:0] cycles,
    output wire [31:0] instret,
    output wire [31:0] stalls
);
    reg [3:0] sel_r;
    always @(posedge clk) if (rst) sel_r <= prog_sel;

    wire [31:0] imem_addr, imem_data;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_be;
    wire        dmem_we, retire, stall_hold;

    rv32im_core u_core (
        .clk(clk), .rst(rst),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_be(dmem_be),
        .dmem_we(dmem_we), .dmem_rdata(dmem_rdata),
        .retire(retire), .stall_hold(stall_hold)
    );

    program_rom u_rom (.sel(sel_r), .addr(imem_addr[9:2]), .data(imem_data));

    // address decode
    wire dmem_sel = (dmem_addr[31:12] == 20'h00000);
    wire io_sel   = (dmem_addr[31:12] == 20'h00002);

    wire [31:0] mem_rdata;
    data_mem u_dmem (
        .clk(clk), .we(dmem_we & dmem_sel), .be(dmem_be),
        .waddr(dmem_addr[11:2]), .wdata(dmem_wdata),
        .raddr(dmem_addr[11:2]), .rdata(mem_rdata)
    );

    reg [31:0] led_reg;
    reg        pass_reg, done_reg;
    wire io_we = dmem_we & io_sel;
    always @(posedge clk) begin
        if (rst) begin
            led_reg <= 32'd0; pass_reg <= 1'b0; done_reg <= 1'b0;
        end else if (io_we) begin
            case (dmem_addr[4:2])
                3'd0: led_reg <= dmem_wdata;
                3'd1: begin pass_reg <= dmem_wdata[0]; done_reg <= 1'b1; end
                default: ;
            endcase
        end
    end

    perf_counters u_perf (
        .clk(clk), .rst(rst), .run(~done_reg), .retire(retire), .stall(stall_hold),
        .cycles(cycles), .instret(instret), .stalls(stalls)
    );

    reg [31:0] io_rdata;
    always @(*) begin
        case (dmem_addr[4:2])
            3'd0:    io_rdata = led_reg;
            3'd1:    io_rdata = {31'b0, pass_reg};
            3'd2:    io_rdata = cycles;
            3'd3:    io_rdata = instret;
            3'd4:    io_rdata = stalls;
            default: io_rdata = 32'd0;
        endcase
    end
    assign dmem_rdata = io_sel ? io_rdata : mem_rdata;

    assign result = led_reg;
    assign pass   = pass_reg;
    assign done   = done_reg;
endmodule
