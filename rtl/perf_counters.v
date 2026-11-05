`timescale 1ns/1ps
// =============================================================================
// perf_counters.v  --  performance counters (STRETCH-goal block)
// Count from reset until `run` drops (the SoC drops it when the program writes
// the PASS register), so the final values stay readable on the display.
//   cycles  : clock cycles          instret : instructions retired
//   stalls  : cycles Stage 1 was held (load-use + M-unit busy)
// =============================================================================
module perf_counters (
    input  wire        clk,
    input  wire        rst,
    input  wire        run,
    input  wire        retire,
    input  wire        stall,
    output reg  [31:0] cycles,
    output reg  [31:0] instret,
    output reg  [31:0] stalls
);
    always @(posedge clk) begin
        if (rst) begin
            cycles <= 32'd0; instret <= 32'd0; stalls <= 32'd0;
        end else if (run) begin
            cycles <= cycles + 32'd1;
            if (retire) instret <= instret + 32'd1;
            if (stall)  stalls  <= stalls  + 32'd1;
        end
    end
endmodule
