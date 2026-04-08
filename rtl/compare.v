`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module compare (
    input  wire               clk,
    input  wire               rst_compare,
    input  wire               en_compare,
    input  wire [7:0]         words_to_compare,
    input  wire [`OP-1:0]     OP,
    output reg  [`ADDR-1:0]   raddr1_compare,
    output reg  [`ADDR-1:0]   raddr2_compare,
    input  wire [`DATA-1:0]   din1_compare,
    input  wire [`DATA-1:0]   din2_compare,
    output reg                done_compare,
    output reg                pass_fail_compare
);

    reg [7:0] words_compared;
    reg [2:0] CS, NS;
    reg       inc_raddr;
    reg       do_compare;

    localparam IDLE        = 3'd0,
               READ_FIRST  = 3'd1,
               READ_SECOND = 3'd2,
               COMPARE     = 3'd3,
               DONE        = 3'd4;

    wire word_match;
    assign word_match = (OP == `OP'd30 && do_compare) ?
                        ((din1_compare[7:0]   == din2_compare[7:0])  &&
                         (din1_compare[15:8]  == din2_compare[15:8]) &&
                         (din1_compare[23:16] == din2_compare[23:16]))
                        : 1'b0;

    // =========================================================
    // FSM state register
    // =========================================================
    always @(posedge clk) begin
        if (rst_compare)
            CS <= IDLE;
        else
            CS <= NS;
    end

    // =========================================================
    // Read address generation
    // =========================================================
    always @(posedge clk) begin
        if (rst_compare) begin
            raddr1_compare <= {`ADDR{1'b0}};
            raddr2_compare <= {`ADDR{1'b0}};
        end
        else if (CS == IDLE && en_compare) begin
            raddr1_compare <= {`ADDR{1'b0}};
            raddr2_compare <= {`ADDR{1'b0}};
        end
        else if (inc_raddr) begin
            raddr1_compare <= raddr1_compare + 1'b1;
            raddr2_compare <= raddr2_compare + 1'b1;
        end
    end

    // =========================================================
    // Compare / result logic
    // =========================================================
    always @(posedge clk) begin
        if (rst_compare) begin
            words_compared    <= 8'd0;
            done_compare      <= 1'b0;
            pass_fail_compare <= 1'b0;
        end
        else if (OP == `OP'd30) begin
            done_compare <= 1'b0;

            if (CS == IDLE && en_compare) begin
                words_compared    <= 8'd0;
                pass_fail_compare <= 1'b1;   // assume PASS unless mismatch occurs
            end
            else if (do_compare) begin
                words_compared <= words_compared + 1'b1;

                if (!word_match)
                    pass_fail_compare <= 1'b0;  // first mismatch => FAIL
            end
            else if (CS == DONE) begin
                done_compare <= 1'b1;
            end
        end
    end

    // =========================================================
    // Next-state logic
    // BRAM read latency = 2 cycles
    // =========================================================
    always @(*) begin
        NS         = CS;
        inc_raddr  = 1'b0;
        do_compare = 1'b0;

        case (CS)
            IDLE: begin
                if (en_compare && OP == `OP'd30)
                    NS = READ_FIRST;
                else
                    NS = IDLE;
            end

            READ_FIRST: begin
                inc_raddr = 1'b1;
                NS = READ_SECOND;
            end

            READ_SECOND: begin
                inc_raddr = 1'b1;
                NS = COMPARE;
            end

            COMPARE: begin
                do_compare = 1'b1;

                // stop immediately on first mismatch
                if (!word_match) begin
                    NS = DONE;
                end
                // all required words compared successfully
                else if (words_compared == (words_to_compare - 1'b1)) begin
                    NS = DONE;
                end
                // continue comparing
                else begin
                    inc_raddr = 1'b1;
                    NS = COMPARE;
                end
            end

            DONE: begin
                NS = DONE;
            end

            default: begin
                NS = IDLE;
            end
        endcase
    end

endmodule