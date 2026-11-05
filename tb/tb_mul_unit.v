// =============================================================================
// tb_mul_unit.v  --  self-checking testbench for mul_unit (MUL/MULH/MULHSU/MULHU)
// Reads golden vectors from mul_vectors.hex (made by scripts/gen_vectors.py),
// checks every result and the latency: 2 cycles
// counted from the start cycle to the done cycle, inclusive.
// Run:  iverilog -o sim tb_mul_unit.v ../rtl/mul_unit.v && vvp sim
// =============================================================================
`timescale 1ns/1ps
module tb_mul_unit;
    localparam MAXV = 20000;
    reg clk = 0, rst = 1, start = 0;
    reg  [1:0]  op;
    reg  [31:0] a, b;
    wire        busy, done;
    wire [31:0] result;

    mul_unit dut (.clk(clk), .rst(rst), .start(start), .op(op), .a(a), .b(b),
                  .busy(busy), .done(done), .result(result));

    always #5 clk = ~clk;                      // 100 MHz

    reg [31:0] vec [0:4*MAXV-1];
    integer i, n, errors, lat, exp_lat, lat_errors;
    reg [31:0] expected;

    initial begin
        $readmemh("mul_vectors.hex", vec);
        errors = 0; lat_errors = 0; n = 0;
        op = 0; a = 0; b = 0;
        repeat (3) @(posedge clk);
        rst <= 0;
        @(posedge clk);
        for (i = 0; i < MAXV && (^vec[4*i] !== 1'bx); i = i + 1) begin
            op = vec[4*i][1:0]; a = vec[4*i+1]; b = vec[4*i+2]; expected = vec[4*i+3];
            exp_lat = 2;
            // start cycle
            start = 1; lat = 1;
            @(posedge clk); #1;
            start = 0; lat = 2;           // now in the 2nd EX cycle
            // garble inputs: the unit must have latched them
            a = 32'hA5A5A5A5; b = 32'h0BADF00D; op = ~op;
            while (!done) begin
                @(posedge clk); #1; lat = lat + 1;
                if (lat > 100) begin $display("TIMEOUT on vector %0d", i); $finish; end
            end
            if (result !== expected) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL #%0d op=%0d a=%h b=%h got=%h exp=%h",
                             i, vec[4*i][1:0], vec[4*i+1], vec[4*i+2], result, expected);
            end
            if (lat != exp_lat) begin
                lat_errors = lat_errors + 1;
                if (lat_errors <= 5) $display("LATENCY #%0d: %0d cycles, expected %0d", i, lat, exp_lat);
            end
            @(posedge clk); #1;               // done cycle ends, unit back to idle
            if (busy) begin $display("busy stuck high after vector %0d", i); errors = errors + 1; end
            n = n + 1;
        end
        $display("mul_unit: %0d vectors, %0d result errors, %0d latency errors", n, errors, lat_errors);
        if (errors == 0 && lat_errors == 0 && n > 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
