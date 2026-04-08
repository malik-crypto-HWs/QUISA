`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module ByteStream (
    input  wire               clk,
    input  wire               rst_byte_stream,
    input  wire               en_byte_stream,
    input  wire [`OP-1:0]     OP,
    input  wire [1:0]         SL_byte_stream,
    // data returned from BRAMs (2-cycle latency after raddr changes)
    input  wire [`DATA-1:0]   din1_byte_stream,
    input  wire [`DATA-1:0]   din2_byte_stream,
    // addresses driven to BRAMs
    output reg  [`ADDR-1:0]   raddr1_byte_stream,
    output reg  [`ADDR-1:0]   raddr2_byte_stream,
    output reg  [`DWIDTH-1:0] dout_byte_stream,
    output reg                done_byte_stream
);

    // 168-byte buffer (SHAKE128 rate)
    reg [7:0] buffer [0:167];

    reg [7:0] wr_idx;
    reg [7:0] seg_loaded;

    wire [7:0] seg_len = (SL_byte_stream == 2'd1 && (OP == `OP'd15 || OP == `OP'd16)) ? 8'd80 : // dealing SL-I
                         (SL_byte_stream == 2'd2 && (OP == `OP'd15 || OP == `OP'd16)) ? 8'd88 : // dealing SL-III
                         (SL_byte_stream == 2'd3 && (OP == `OP'd15 || OP == `OP'd16)) ? 8'd96 : // dealing SL-V
                         8'd0;

    wire [7:0] remain = (seg_len > seg_loaded) ? (seg_len - seg_loaded) : 8'd0;

    wire [2:0] push_n = (remain >= 8'd6) ? 3'd6 :
                        (remain == 8'd5) ? 3'd5 :
                        (remain == 8'd4) ? 3'd4 :
                        (remain == 8'd3) ? 3'd3 :
                        (remain == 8'd2) ? 3'd2 :
                        (remain == 8'd1) ? 3'd1 : 3'd0;

    reg [`OP-1:0] OP_prev;

    // BRAM latency pipeline
    reg en_d1, en_d2;
    reg [23:0] din1_q, din2_q;
    wire bram_data_valid = en_d2;

    // Skip first write beat after start
    reg first_write_skip;

    // Stop issuing new addresses, ignore 2 tail returns
    reg       stop_reads;
    reg [1:0] tail_ignore;

    reg [2:0] push_n_d1, push_n_d2;

    reg [2:0] eff_push;
    integer i;

    // ------------------------------------------------------------
    // Request / pipeline stage
    // NOTE: does NOT write done_byte_stream anymore (single driver fix)
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_byte_stream) begin
            raddr1_byte_stream <= `ADDR'd0;
            raddr2_byte_stream <= `ADDR'd1;

            wr_idx     <= 8'd0;
            seg_loaded <= 8'd0;
            OP_prev    <= {`OP{1'b0}};

            en_d1  <= 1'b0;
            en_d2  <= 1'b0;
            din1_q <= 24'd0;
            din2_q <= 24'd0;

            first_write_skip <= 1'b1;

            stop_reads  <= 1'b0;
            tail_ignore <= 2'd0;

            push_n_d1 <= 3'd0;
            push_n_d2 <= 3'd0;

            for (i = 0; i < 168; i = i + 1)
                buffer[i] <= 8'd0;

        end else begin
            // OP change / start
            if (OP != OP_prev) begin
                seg_loaded <= 8'd0;

                if (OP == `OP'd16) begin
                    wr_idx <= 8'd0;
                    raddr1_byte_stream <= `ADDR'd0;
                    raddr2_byte_stream <= `ADDR'd1;
                end

                // flush pipeline
                en_d1 <= 1'b0;
                en_d2 <= 1'b0;

                first_write_skip <= 1'b1;

                stop_reads  <= 1'b0;
                tail_ignore <= 2'd0;

                push_n_d1 <= 3'd0;
                push_n_d2 <= 3'd0;

                OP_prev <= OP;
            end

            // Issue reads while bytes still needed
            if (en_byte_stream &&
                !stop_reads &&
                (OP == `OP'd16) &&
                (push_n != 3'd0)) begin

                raddr1_byte_stream <= raddr1_byte_stream + 2;
                raddr2_byte_stream <= raddr2_byte_stream + 2;
                en_d1 <= 1'b1;

            end else begin
                en_d1 <= 1'b0;
            end

            // BRAM 2-cycle valid pipeline
            en_d2  <= en_d1;

            // capture BRAM outputs
            din1_q <= din1_byte_stream;
            din2_q <= din2_byte_stream;

            // pipeline push_n (aligned with en_d2)
            if (en_byte_stream && !stop_reads && (OP == `OP'd16) && (push_n != 3'd0))
                push_n_d1 <= push_n;
            else
                push_n_d1 <= 3'd0;

            push_n_d2 <= push_n_d1;
        end
    end

    // ------------------------------------------------------------
    // Write stage
    // Owns done_byte_stream (single driver) and pulses it for 1 cycle
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_byte_stream) begin
            done_byte_stream <= 1'b0;
        end else begin
            done_byte_stream <= 1'b0; // default 1-cycle pulse

            if (bram_data_valid && (push_n_d2 != 3'd0)) begin

                // ignore tail returns after stop
                if (tail_ignore != 2'd0) begin
                    tail_ignore <= tail_ignore - 1'b1;

                end else if (first_write_skip) begin
                    first_write_skip <= 1'b0;

                end else begin
                    // keep your VERIFIED blocking behavior here
                    eff_push = push_n_d2;

                    if ((seg_loaded < 8'd64) && ((seg_loaded + push_n_d2) > 8'd64)) begin
                        eff_push = 8'd64 - seg_loaded;
                    end

                    // write bytes in order: din1 b0,b1,b2 then din2 b0,b1,b2
                    if (eff_push >= 3'd1) buffer[wr_idx + 0] <= din1_q[7:0];
                    if (eff_push >= 3'd2) buffer[wr_idx + 1] <= din1_q[15:8];
                    if (eff_push >= 3'd3) buffer[wr_idx + 2] <= din1_q[23:16];
                    if (eff_push >= 3'd4) buffer[wr_idx + 3] <= din2_q[7:0];
                    if (eff_push >= 3'd5) buffer[wr_idx + 4] <= din2_q[15:8];
                    if (eff_push >= 3'd6) buffer[wr_idx + 5] <= din2_q[23:16];

                    // advance pointers/counters by VALID bytes written
                    wr_idx     <= wr_idx + eff_push;
                    seg_loaded <= seg_loaded + eff_push;

                    // done when we reach seg_len valid bytes:
                    if ((seg_len != 8'd0) && (seg_loaded + eff_push >= seg_len)) begin
                        done_byte_stream <= 1'b1;
                        stop_reads       <= 1'b1;
                        tail_ignore      <= 2'd2;
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Buffer output
    // ------------------------------------------------------------
    reg [7:0]  count_buffer_out;
    reg [63:0] dout_byte_stream_reg;

    always @(posedge clk) begin
        if (rst_byte_stream) begin
            dout_byte_stream <= {`DWIDTH{1'b0}};
        end else begin
            dout_byte_stream <= dout_byte_stream_reg;
        end
    end

    always @(posedge clk) begin
        if (rst_byte_stream) begin
            dout_byte_stream_reg <= 64'd0;
            count_buffer_out     <= 8'd0;
        end else if (OP == `OP'd15) begin
            dout_byte_stream_reg[63:0] <= {
                buffer[7 + count_buffer_out],
                buffer[6 + count_buffer_out],
                buffer[5 + count_buffer_out],
                buffer[4 + count_buffer_out],
                buffer[3 + count_buffer_out],
                buffer[2 + count_buffer_out],
                buffer[1 + count_buffer_out],
                buffer[0 + count_buffer_out]
            };

            if (count_buffer_out < seg_len)
                count_buffer_out <= count_buffer_out + 8'd8;
        end
    end

endmodule