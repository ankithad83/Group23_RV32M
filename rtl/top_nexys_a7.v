`timescale 1ns/1ps
// =============================================================================
// top_nexys_a7.v  --  board wrapper for the Digilent Nexys A7 (set as Vivado TOP)
//
//   CPU_RESETN (red button)  restart the program (also latches SW[15:12])
//   SW[15:12]  program select, read when the reset button is pressed
//                0..4  matmul, gcd, factorial, fir, primes   (hardware MUL/DIV)
//                5..9  the same five with SOFTWARE mul/div   (baseline)
//                10    isa_test (self-check of loads/stores/shifts/all M ops)
//   SW[1:0]    7-segment shows:  00 result   01 cycles   10 instructions
//                                11 stall cycles          (hex, 8 digits)
//   LED[15]    PASS  (program finished and its result was correct)
//   LED[14]    DONE  (program finished; PASS=0 means wrong result)
//   LED[13:0]  low 14 bits of the program's result
//
// Procedure: set SW[15:12] -> press CPU_RESETN -> wait for LED[14] -> read the
// cycle count with SW[1:0] = 01. Compare program n with program n+5 for the
// hardware-vs-software speed-up.
// =============================================================================
module top_nexys_a7 (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire [15:0] SW,
    output wire [15:0] LED,
    output wire [6:0]  SEG,        // SEG[0] = CA ... SEG[6] = CG, active low
    output wire        DP,
    output wire [7:0]  AN          // active low
);
    // reset synchroniser (also holds reset for a few cycles after power-up)
    reg [3:0] rst_sync = 4'b1111;
    always @(posedge CLK100MHZ) rst_sync <= {rst_sync[2:0], ~CPU_RESETN};
    wire rst = rst_sync[3];

    wire [31:0] result, cycles, instret, stalls;
    wire        pass, done;

    soc u_soc (
        .clk(CLK100MHZ), .rst(rst), .prog_sel(SW[15:12]),
        .result(result), .pass(pass), .done(done),
        .cycles(cycles), .instret(instret), .stalls(stalls)
    );

    assign LED = {pass & done, done, result[13:0]};

    // value shown on the 7-segment display
    reg [31:0] shown;
    always @(*) begin
        case (SW[1:0])
            2'd0:    shown = result;
            2'd1:    shown = cycles;
            2'd2:    shown = instret;
            default: shown = stalls;
        endcase
    end

    // 8-digit multiplexed display (~95 Hz refresh per digit set)
    reg [19:0] refresh = 20'd0;
    always @(posedge CLK100MHZ) refresh <= refresh + 20'd1;
    wire [2:0] digit = refresh[19:17];

    reg [3:0] nibble;
    always @(*) begin
        case (digit)
            3'd0: nibble = shown[3:0];
            3'd1: nibble = shown[7:4];
            3'd2: nibble = shown[11:8];
            3'd3: nibble = shown[15:12];
            3'd4: nibble = shown[19:16];
            3'd5: nibble = shown[23:20];
            3'd6: nibble = shown[27:24];
            default: nibble = shown[31:28];
        endcase
    end

    reg [6:0] seg_r;                       // {g,f,e,d,c,b,a}, active low
    always @(*) begin
        case (nibble)
            4'h0: seg_r = 7'b1000000;  4'h1: seg_r = 7'b1111001;
            4'h2: seg_r = 7'b0100100;  4'h3: seg_r = 7'b0110000;
            4'h4: seg_r = 7'b0011001;  4'h5: seg_r = 7'b0010010;
            4'h6: seg_r = 7'b0000010;  4'h7: seg_r = 7'b1111000;
            4'h8: seg_r = 7'b0000000;  4'h9: seg_r = 7'b0010000;
            4'hA: seg_r = 7'b0001000;  4'hB: seg_r = 7'b0000011;
            4'hC: seg_r = 7'b1000110;  4'hD: seg_r = 7'b0100001;
            4'hE: seg_r = 7'b0000110;  default: seg_r = 7'b0001110;
        endcase
    end
    assign SEG = seg_r;
    assign DP  = 1'b1;                     // decimal point off
    assign AN  = ~(8'b00000001 << digit);
endmodule
