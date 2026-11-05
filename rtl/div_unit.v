`timescale 1ns/1ps
// =============================================================================
// div_unit.v  --  RV32M divider (DIV, DIVU, REM, REMU)
// Group 23 : Hardware RV32M Extension for a 3-stage RV32I processor (Nexys A7)
//
// Restoring divider on unsigned magnitudes, one quotient bit per cycle.
//
// Latency in EX (normal case) : 34 cycles
//   1  cycle  : start  - operands latched, signs stripped
//   32 cycles : RUN    - one restoring step per cycle
//   1  cycle  : DONE   - sign fix-up, result valid, done = 1
// Special cases finish early (2 cycles: start + DONE), results per RISC-V spec:
//   x / 0            : DIV/DIVU = all ones (-1 / 2^32-1),  REM/REMU = x
//   INT_MIN / -1     : DIV = INT_MIN,                       REM = 0
//
// funct3[1:0] : 00 DIV   01 DIVU   10 REM   11 REMU
// =============================================================================
module div_unit (
    input  wire        clk,
    input  wire        rst,        // synchronous, active high
    input  wire        start,      // pulse: begin a divide (ignored if busy)
    input  wire [1:0]  op,         // funct3[1:0]
    input  wire [31:0] a,          // rs1 = dividend
    input  wire [31:0] b,          // rs2 = divisor
    output wire        busy,       // unit occupied (RUN or DONE)
    output wire        done,       // result valid this cycle
    output reg  [31:0] result
);
    localparam IDLE = 2'd0, RUN = 2'd1, DONE = 2'd2;

    reg [1:0]  state;
    reg [5:0]  count;              // iterations left
    reg [32:0] rem;                // partial remainder (33 bits for compare)
    reg [31:0] quo;                // quotient bits shift in from the right
    reg [31:0] divisor;            // |b|
    reg        neg_q, neg_r;       // sign fix-up flags
    reg        want_rem;           // REM / REMU
    reg        special;            // div-by-zero or overflow
    reg [31:0] special_res;

    // ---- start-cycle decode -------------------------------------------------
    wire is_signed  = ~op[0];                       // DIV, REM
    wire a_neg      = is_signed & a[31];
    wire b_neg      = is_signed & b[31];
    wire [31:0] a_abs = a_neg ? (~a + 32'd1) : a;
    wire [31:0] b_abs = b_neg ? (~b + 32'd1) : b;
    wire div_zero   = (b == 32'd0);
    wire overflow   = is_signed & (a == 32'h8000_0000) & (b == 32'hFFFF_FFFF);

    // ---- one restoring step -------------------------------------------------
    wire [32:0] rem_shift = {rem[31:0], quo[31]};
    wire [32:0] diff      = rem_shift - {1'b0, divisor};
    wire        fits      = ~diff[32];              // no borrow -> subtract

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            count <= 6'd0;
            rem <= 33'd0; quo <= 32'd0; divisor <= 32'd0;
            neg_q <= 1'b0; neg_r <= 1'b0; want_rem <= 1'b0;
            special <= 1'b0; special_res <= 32'd0;
        end else begin
            case (state)
            IDLE: if (start) begin
                want_rem <= op[1];
                neg_q    <= a_neg ^ b_neg;
                neg_r    <= a_neg;                   // remainder takes dividend's sign
                divisor  <= b_abs;
                rem      <= 33'd0;
                quo      <= a_abs;                   // dividend shifts out of quo's MSB
                count    <= 6'd32;
                if (div_zero) begin
                    special     <= 1'b1;
                    special_res <= op[1] ? a : 32'hFFFF_FFFF;
                    state       <= DONE;
                end else if (overflow) begin
                    special     <= 1'b1;
                    special_res <= op[1] ? 32'd0 : 32'h8000_0000;
                    state       <= DONE;
                end else begin
                    special <= 1'b0;
                    state   <= RUN;
                end
            end
            RUN: begin
                rem   <= fits ? diff : rem_shift;
                quo   <= {quo[30:0], fits};
                count <= count - 6'd1;
                if (count == 6'd1) state <= DONE;
            end
            DONE: state <= IDLE;                      // result consumed this cycle
            default: state <= IDLE;
            endcase
        end
    end

    // ---- result (valid in DONE) ---------------------------------------------
    always @(*) begin
        if (special)       result = special_res;
        else if (want_rem) result = neg_r ? (~rem[31:0] + 32'd1) : rem[31:0];
        else               result = neg_q ? (~quo + 32'd1)       : quo;
    end

    assign busy = (state != IDLE);
    assign done = (state == DONE);
endmodule
