`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module op_format_block_rejsamp (
    input clk,
    input rst_expand,
    input en_expand,
    input  [7:0]  V,           // vinegar vars (same as v)
    input  [5:0]  M,           // number of equations (same as m)
    input  [3:0]  l,           // extension degree 
    input  [6:0]  q,           // modulus q
    input  [`OP-1:0] OP,       // operation to perform
    input  [3:0] SECAP,
    input din_v_expand,
    input done_rejsamp_for_expand,
    input [8*168-1:0] din_expand,   // 168 bytes from RejSamp
    input [16:0] length_rejsamp,   // Total valid bytes
    input [7:0] v_bytes_from_rejsamp, // Not used
    output [`DATA-1:0] dout_expand_1,     // 3-byte field element
    output [`DATA-1:0] dout_expand_2,
    output reg dout_v_expand,
    output reg [`ADDR-1:0] waddr_expand,
    output reg done_expand
);

    // === Internal Byte Buffer ===
    reg [7:0]  buffer [0:173];  // 168 + 6 = 174 bytes max
    reg [3:0]  leftover_bytes, prev_leftover_bytes;
    reg [6:0]  count_cols, count_rows;
    reg [15:0] COUNT_TOTAL_BYTES;
    reg [7:0]  count_proc_bytes_from_168;
    wire       not_iteration1;
    reg [8:0]  buffer_idx;
    integer    i;
    
    // FSM
    reg [2:0] CS, NS;
    localparam IDLE         = 3'd0,
               FEED_IN      = 3'd1,
               FEED_OUT     = 3'd2,
               SHIFT_BUFF   = 3'd3,
               WAIT         = 3'd4,
               DONE         = 3'd5;   
    
    assign not_iteration1 = (COUNT_TOTAL_BYTES > 0) ? 1 : 0;
    
    always @ (posedge clk) begin
        if(rst_expand)
            leftover_bytes <= 0;
        else if ((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14|| OP==`OP'd15) && (CS==FEED_IN))
            leftover_bytes <= (v_bytes_from_rejsamp + leftover_bytes) % 6;
    end
    
    always @ (posedge clk) begin
        if(rst_expand)
            prev_leftover_bytes <= 0;
        else if ((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10|| OP==`OP'd13 || OP==`OP'd14|| OP==`OP'd15) && (CS==WAIT))
            prev_leftover_bytes <= leftover_bytes;
    end
    
    always @ (posedge clk) begin
        if(rst_expand || count_cols == M)
            count_cols <= 0;
        else if ((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10) && (dout_v_expand))
            count_cols <= count_cols + 2;
    end
    
    always @ (posedge clk) begin
        if(rst_expand || count_rows == V)
            count_rows <= 0;
        else if ((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10) && (dout_v_expand))
            count_rows <= count_rows + 1;
    end
    
    always @ (posedge clk) begin
        if(rst_expand || count_proc_bytes_from_168 == ((v_bytes_from_rejsamp - leftover_bytes) + prev_leftover_bytes)-6)
            count_proc_bytes_from_168 <= 0;
        else if ((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10|| OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) && dout_v_expand)
            count_proc_bytes_from_168 <= count_proc_bytes_from_168 + 6;
    end
    
    always @ (posedge clk) begin
        if(rst_expand)
            COUNT_TOTAL_BYTES <= 0;
        else if (dout_v_expand)
            COUNT_TOTAL_BYTES <= COUNT_TOTAL_BYTES + 6;
    end
    
    always @(posedge clk) begin
        if (rst_expand)
            waddr_expand <= 0;
        else if (dout_v_expand)
            waddr_expand <= waddr_expand + 2;
    end
    
    always @(posedge clk) begin
        if (rst_expand)
            buffer_idx <= 0;
        else if (not_iteration1 && din_v_expand)
            buffer_idx <= prev_leftover_bytes;
    end
    
    always @(posedge clk) begin
        if (rst_expand) begin
            for (i = 0; i < 174; i = i + 1) begin
                buffer[i] <= 0; 
            end
        end else if (CS==FEED_IN) begin
            if(OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) begin
                if(!not_iteration1)begin
                    for (i = 0; i < 168; i = i + 1) begin
                        buffer[i] <= din_expand[i*8 +: 8];
                    end
                end else begin
                    for (i = 0; i < 168; i = i + 1)
                        buffer[i+buffer_idx] <= din_expand[i*8 +: 8];
                end
            end 
        end else if (CS==FEED_OUT) begin
            if((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) && dout_v_expand) begin // (count_proc_bytes_from_168 == (v_bytes_from_rejsamp + leftover_bytes)-6)
                // Step 1: Shift
                for (i = 0; i < (174 - 6); i = i + 1) begin
                    buffer[i] <= buffer[(i + 6)];
                end
                // Step 2: Fill the upper bytes (MSB) with zeros
                for (i = (174 - 6); i < 174; i = i + 1) begin
                    buffer[i] <= 8'd0;
                end
            end 
        end
    end
    
    // FSM state update
    always @(posedge clk) begin
        if (rst_expand)
            CS <= IDLE;
        else
            CS <= NS;
    end
        
    always @(*) begin
        done_expand   = 0;
        dout_v_expand = 0;
        case (CS)
            IDLE: begin
                if (en_expand && din_v_expand) 
                    NS = FEED_IN;
                else 
                    NS = IDLE;
            end
            FEED_IN: begin
                NS = FEED_OUT;
            end
            FEED_OUT: begin
                if(COUNT_TOTAL_BYTES >= length_rejsamp) begin
                    NS = DONE;
                end else if ((OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14|| OP==`OP'd15) && count_proc_bytes_from_168 == ((v_bytes_from_rejsamp - leftover_bytes) + prev_leftover_bytes)-6) begin
                    dout_v_expand = 1;
                    NS = WAIT;
                end else begin
                    dout_v_expand = 1;
                    NS = FEED_OUT; 
                end
            end
            WAIT: begin
                if(din_v_expand)
                    NS = FEED_IN;
                 else begin
                    if(done_rejsamp_for_expand)
                        NS = FEED_OUT;
                    else 
                        NS = WAIT;
                end
            end
            DONE: begin
                done_expand = 1;
            end
        endcase
    end
    
    //assign dout_v_expand = (CS==IDLE || CS==FEED_IN ||CS==SHIFT_BUFF || CS==WAIT || CS==DONE) ? 0 : 1;
    
    assign dout_expand_1 = { buffer[2], buffer[1], buffer[0]};
    assign dout_expand_2 = { buffer[5], buffer[4], buffer[3]};
    
endmodule
