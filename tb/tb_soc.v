// =============================================================================
// tb_soc.v  --  runs every C program on the full processor (RTL simulation)
// For each prog_sel: reset, run until the program writes the PASS register,
// then check result == expected, PASS == 1, and print the measured counters.
// Run:  cd sim && iverilog -g2005 -o tb_soc ../tb/tb_soc.v ../rtl/*.v && vvp tb_soc
// (in Vivado: add all rtl/*.v as design sources, tb_soc.v as simulation top)
// =============================================================================
`timescale 1ns/1ps
module tb_soc;
    // run programs FIRST..LAST (0..10). Use e.g. FIRST=0, LAST=3 for a quick run in Vivado;
    // the speed-up column needs both a hardware program (0..4) and its software twin (5..9).
    parameter FIRST = 0;
    parameter LAST  = 10;
    reg         clk = 0, rst = 1;
    reg  [3:0]  prog_sel = 0;
    wire [31:0] result, cycles, instret, stalls;
    wire        pass, done;

    soc dut (.clk(clk), .rst(rst), .prog_sel(prog_sel), .result(result),
             .pass(pass), .done(done), .cycles(cycles), .instret(instret), .stalls(stalls));

    always #5 clk = ~clk;                       // 100 MHz

    reg [31:0] expected [0:10];
    reg [8*10-1:0] name [0:10];
    integer k, t, errors;
    reg [31:0] cyc_im [0:4];
    reg        have_im [0:4];

    initial begin
        expected[0]  = 32'd573248;      name[0]  = "matmul   ";
        expected[1]  = 32'd360;         name[1]  = "gcd      ";
        expected[2]  = 32'd61297177;    name[2]  = "factorial";
        expected[3]  = 32'd80600956;    name[3]  = "fir      ";
        expected[4]  = 32'd16846;       name[4]  = "primes   ";
        expected[5]  = 32'd573248;      name[5]  = "matmul   ";
        expected[6]  = 32'd360;         name[6]  = "gcd      ";
        expected[7]  = 32'd61297177;    name[7]  = "factorial";
        expected[8]  = 32'd80600956;    name[8]  = "fir      ";
        expected[9]  = 32'd16846;       name[9]  = "primes   ";
        expected[10] = 32'd3643198493;  name[10] = "isa_test ";
        errors = 0;
        for (k = 0; k < 5; k = k + 1) have_im[k] = 0;
        $display("sel program    build   result      PASS  cycles    instret   stalls   speed-up");
        for (k = FIRST; k <= LAST; k = k + 1) begin
            prog_sel = k; rst = 1;
            repeat (4) @(posedge clk);
            #1 rst = 0;
            t = 0;
            while (!done && t < 3000000) begin @(posedge clk); t = t + 1; end
            #1;
            if (!done) begin
                errors = errors + 1;
                $display("%0d  %0s TIMEOUT (pc stuck?)", k, name[k]);
            end else begin
                if (result !== expected[k] || pass !== 1'b1) errors = errors + 1;
                if (k < 5) begin cyc_im[k] = cycles; have_im[k] = 1; end
                $write("%2d  %0s %0s %10d  %0d     %8d  %8d  %8d", k, name[k],
                       (k < 5 || k == 10) ? "rv32im" : "rv32i ", result, pass, cycles, instret, stalls);
                if (k >= 5 && k < 10 && have_im[k-5]) $write("   %0d.%02dx", cycles / cyc_im[k-5],
                                              ((cycles * 100) / cyc_im[k-5]) % 100);
                if (result !== expected[k] || pass !== 1'b1) $write("   <-- FAIL (expected %0d)", expected[k]);
                $write("\n");
            end
        end
        if (errors == 0) $display("PASS: programs %0d..%0d correct on the RTL", FIRST, LAST);
        else             $display("FAIL: %0d program(s) wrong", errors);
        $finish;
    end
endmodule
