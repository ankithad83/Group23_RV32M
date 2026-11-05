// =============================================================================
// tb_top_nexys_a7.v  --  testbench for the BOARD wrapper (top_nexys_a7)
// Plays the role of the board: 100 MHz clock, reset button, switches.
// Set this as the simulation top if you want to see LED / SEG / AN waveforms.
// Change PROG (0..10) and VIEW (0 result, 1 cycles, 2 instructions, 3 stalls).
// =============================================================================
`timescale 1ns/1ps
module tb_top_nexys_a7;
    parameter [3:0] PROG = 4'd0;
    parameter [1:0] VIEW = 2'd0;

    reg         CLK100MHZ = 0;
    reg         CPU_RESETN = 0;            // button pressed (active low)
    reg  [15:0] SW = 16'd0;
    wire [15:0] LED;
    wire [6:0]  SEG;
    wire        DP;
    wire [7:0]  AN;

    top_nexys_a7 dut (.CLK100MHZ(CLK100MHZ), .CPU_RESETN(CPU_RESETN), .SW(SW),
                      .LED(LED), .SEG(SEG), .DP(DP), .AN(AN));

    always #5 CLK100MHZ = ~CLK100MHZ;      // 100 MHz

    initial begin
        SW = {PROG, 10'd0, VIEW};
        #200 CPU_RESETN = 1;               // release the button
        wait (LED[14]);                    // DONE
        #100;
        $display("DONE at %0t ns: LED = %h  (LED15 = PASS, LED14 = DONE, LED13..0 = result low bits)", $time/1000, LED);
        $display("display value = %h", dut.shown);
        #3000000;                          // let the display multiplex through all digits
        $finish;
    end
endmodule
