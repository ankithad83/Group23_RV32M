`timescale 1ns/1ps
// =============================================================================
// data_mem.v  --  4 KB data memory (existing "Data Memory" block, Stage 3)
// Asynchronous read (maps to distributed RAM), synchronous write with byte
// enables. Contents start at zero.
// =============================================================================
module data_mem (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  be,
    input  wire [9:0]  waddr,       // word address
    input  wire [31:0] wdata,
    input  wire [9:0]  raddr,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:1023];
    integer i;
    initial for (i = 0; i < 1024; i = i + 1) mem[i] = 32'd0;

    always @(posedge clk) begin
        if (we) begin
            if (be[0]) mem[waddr][7:0]   <= wdata[7:0];
            if (be[1]) mem[waddr][15:8]  <= wdata[15:8];
            if (be[2]) mem[waddr][23:16] <= wdata[23:16];
            if (be[3]) mem[waddr][31:24] <= wdata[31:24];
        end
    end
    assign rdata = mem[raddr];
endmodule
