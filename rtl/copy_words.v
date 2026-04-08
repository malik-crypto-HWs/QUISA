`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module copy_words (
    input  wire               clk,
    input  wire               rst_copy_words,
    input  wire               en_copy_words,
    input  wire [5:0]         t_in_words,
    input  wire [`OP-1:0]     OP,

    // data returned from BRAMs (2-cycle latency after raddr changes)
    input  wire [`DATA-1:0]   din_copy_words,

    // addresses driven to BRAMs
    output reg  [`ADDR-1:0]   raddr_copy_words,
    output reg  [`ADDR-1:0]   waddr_copy_words,
    output reg  [`DATA-1:0]   dout_copy_words,
    output reg                dout_v_copy_words,
    output reg                done_copy_words
);

    reg [1:0] count;
    reg [5:0] t_in_words_count;
    reg [2:0] CS, NS;
    reg       inc_raddr, inc_waddr;

    localparam IDLE             = 3'd0,
               READ_FIRST       = 3'd1,
               READ_SECOND      = 3'd2,
               READ_THIRD       = 3'd3,
               FEED_IN_OUT      = 3'd4,
               SECOND_LAST_OUT  = 3'd5,
               LAST_OUT         = 3'd6,
               DONE             = 3'd7;

    // =========================================================================
    // Output packing / copying
    // =========================================================================
    always @(posedge clk) begin
        dout_v_copy_words <= 1'b0;
        done_copy_words   <= 1'b0;

        if (rst_copy_words) begin
            dout_copy_words <= {`DWIDTH{1'b0}};
            count           <= 2'd0;
        end
        else if (CS == FEED_IN_OUT || CS == READ_THIRD) begin
            // OP=17: pack 3 bytes from LSB byte stream
            if (OP == `OP'd17) begin
                if (count == 2'd0) begin
                    dout_copy_words[7:0] <= din_copy_words[7:0];
                    count <= count + 1'b1;
                end
                else if (count == 2'd1) begin
                    dout_copy_words[15:8] <= din_copy_words[7:0];
                    count <= count + 1'b1;
                end
                else if (count == 2'd2) begin
                    dout_copy_words[23:16] <= din_copy_words[7:0];
                    dout_v_copy_words <= 1'b1;
                    count <= count + 1'b1;
                end
                else if (count == 2'd3) begin
                    count <= 2'd0;
                end
            end

            // OP=21: copy whole word
            else if (OP == `OP'd21 || OP==`OP'd22) begin
                dout_copy_words   <= din_copy_words;
                dout_v_copy_words <= 1'b1;
                count             <= count + 1'b1;
            end
        end
        else if (CS==SECOND_LAST_OUT || CS==LAST_OUT) begin
            if (OP == `OP'd21 || OP==`OP'd22) begin
                dout_copy_words   <= din_copy_words;
                dout_v_copy_words <= 1'b1;
                count             <= count + 1'b1;
            end
        end
        else if (CS == DONE) begin
            done_copy_words <= 1'b1;
        end
    end

    // =========================================================================
    // Word counter
    // =========================================================================
    always @(posedge clk) begin
        if (rst_copy_words) begin
            t_in_words_count <= 6'd0;
        end
        else if (OP == `OP'd17 && count == 2'd2) begin
            t_in_words_count <= t_in_words_count + 1'b1;
        end
        else if (OP == `OP'd21 || OP==`OP'd22) begin
            t_in_words_count <= t_in_words_count + 1'b1;
        end
    end

    // =========================================================================
    // Read address counter
    // =========================================================================
    always @(posedge clk) begin
        if (rst_copy_words) begin
            raddr_copy_words <= {`ADDR{1'b0}};
        end
        else if (inc_raddr) begin
            raddr_copy_words <= raddr_copy_words + 1'b1;
        end
    end

    // =========================================================================
    // Write address counter
    // =========================================================================
    always @(posedge clk) begin
        if (rst_copy_words) begin
            waddr_copy_words <= {`ADDR{1'b0}};
        end
        else if (inc_waddr) begin
            waddr_copy_words <= waddr_copy_words + 1'b1;
        end
    end

    // =========================================================================
    // State register
    // =========================================================================
    always @(posedge clk) begin
        if (rst_copy_words) begin
            CS <= IDLE;
        end
        else begin
            CS <= NS;
        end
    end

    // =========================================================================
    // Next-state logic
    // =========================================================================
    always @(*) begin
        inc_raddr = 1'b0;
        inc_waddr = 1'b0;
        NS        = CS;

        case (CS)
            IDLE: begin
                if (en_copy_words)
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
                NS = READ_THIRD;
            end

            READ_THIRD: begin
                inc_raddr = 1'b1;
                NS = FEED_IN_OUT;
            end

            FEED_IN_OUT: begin
                if (OP == `OP'd17) begin
                    if (count < 3) begin
                        NS = FEED_IN_OUT;
                    end
                    else if (count == 3) begin
                        inc_waddr = 1'b1;
                        if (t_in_words_count < t_in_words)
                            NS = READ_FIRST;
                        else
                            NS = DONE;
                    end
                end
                else if (OP == `OP'd21 || OP==`OP'd22) begin
                    inc_waddr = 1'b1;
                    inc_raddr = 1'b1;
                    if (t_in_words_count < t_in_words)
                        NS = FEED_IN_OUT;
                    else
                        NS = SECOND_LAST_OUT;
                end
            end
            
            SECOND_LAST_OUT: begin
                inc_waddr = 1'b1;
                NS = LAST_OUT;
            end
            
            LAST_OUT: begin
                inc_waddr = 1'b1;
                NS = DONE;
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