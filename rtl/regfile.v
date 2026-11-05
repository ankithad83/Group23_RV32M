`timescale 1ns/1ps
// =============================================================================
// regfile.v  --  32 x 32 register file (existing block, Stage 1)
// Two asynchronous read ports, one synchronous write port (written from
// Stage 3). Write-through: a read in the same cycle as a write to the same
// register returns the NEW value (this is what makes a 1-cycle load-use stall
// enough, and covers the "producer in Stage 3, consumer in Stage 1" case).
// =============================================================================
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
    reg [31:0] regs [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;

    always @(posedge clk)
        if (we && waddr != 5'd0) regs[waddr] <= wdata;

    assign rdata1 = (raddr1 == 5'd0)           ? 32'd0 :
                    (we && waddr == raddr1)    ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0)           ? 32'd0 :
                    (we && waddr == raddr2)    ? wdata : regs[raddr2];
endmodule
