`timescale 1ns / 1ps
`include "signal_sizes.vh"
`define RATE_SHAKE128       8'd21    // 168 bytes = 1344 bits / 8
`define RATE_SHAKE128_BYTES 8'd168    // 168 bytes
`define RATE_SHAKE256       8'd17     // 136 bytes = 1088 bits / 8
`define RATE_SHAKE256_BYTES 8'd136    // 136 bytes

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran 
//////////////////////////////////////////////////////////////////////////////////

module rejsamp(
    input clk,
    input rst_rejsamp,
    input en_rejsamp,
    input [6:0] q,
    input [3:0] SECAP,
    input [1:0] rate_type,
    input [`OP-1:0] OP,
    input [`OLEN-1:0] OLEN,
    input din_v_rejsamp,
    input [`DWIDTH-1:0] din_rejsamp,
    output [8*`RATE_SHAKE128_BYTES-1:0] dout_rejsamp,
    input [16:0] length_rejsamp,
    output [7:0] v_bytes_for_expand,
    output reg dout_v_rejsamp,
    output reg done_rejsamp
);

    wire [`DWIDTH-1:0] reduced_bytes;
    wire [`DWIDTH-1:0] dout_inst;
    reg [16:0] count_bytes_requested;
    
    reg  [8*`RATE_SHAKE128_BYTES-1:0] buffer_in;
    reg  [7:0] buffer_in_count;
    wire [3:0] v_bytes_in_word;
    reg  [7:0] t_v_bytes_c_stage;
    wire [7:0] valid_flags_in_word;
    integer i;
    wire not_iteration1;
    
    // FSM States
    reg [2:0] CS, NS;
    localparam IDLE           = 3'd0,
               FEED_IN        = 3'd1,
               PREPARE_BUFF   = 3'd2,
               PREPARE_BUFF_2 = 3'd3,
               FEED_OUT       = 3'd4,
               DONE           = 3'd5;
    
    assign not_iteration1 = (count_bytes_requested > 0) ? 1 : 0;
    wire [7:0] rate_constant = (rate_type == 2'd2) ? `RATE_SHAKE128_BYTES : 
                               (rate_type == 2'd3) ? `RATE_SHAKE256_BYTES : 
                               0;

    //======================================================
    // logic for C/C++ function (rejsamp_and_q) 
    // Actually, this is a reduction without the uniformity
    //======================================================
    rejsamp_and_q rejsamp_and_q_uut (
        .din         (din_rejsamp),
        .Q           (q),
        .dout        (reduced_bytes)
    );

    eight_bytes_reordering eight_bytes_reordering_uut (
        .din         (reduced_bytes),
        .Q           (q),
        .dout        (dout_inst),
        .valid_count (v_bytes_in_word),
        .valid_flags (valid_flags_in_word)
    );
    
    always @(posedge clk) begin
        if (rst_rejsamp) begin
            buffer_in <= 0;
        end else if ((OP==`OP'd13 || OP==`OP'd14) && din_v_rejsamp && CS == FEED_IN) begin // this accumulates the hashed bytes before the rejection
            buffer_in <= {din_rejsamp, buffer_in[8*`RATE_SHAKE128_BYTES-1:64]};
        end else if (din_v_rejsamp && CS == FEED_IN) begin // this accumulates the hashed bytes after the rejection
            case (v_bytes_in_word)
                4'd0: buffer_in <= buffer_in;
                4'd1: buffer_in <= {dout_inst[ 7:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1:  8]};
                4'd2: buffer_in <= {dout_inst[15:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 16]};
                4'd3: buffer_in <= {dout_inst[23:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 24]};
                4'd4: buffer_in <= {dout_inst[31:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 32]};
                4'd5: buffer_in <= {dout_inst[39:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 40]};
                4'd6: buffer_in <= {dout_inst[47:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 48]};
                4'd7: buffer_in <= {dout_inst[55:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 56]};
                4'd8: buffer_in <= {dout_inst[63:0],  buffer_in[8*`RATE_SHAKE128_BYTES-1: 64]};
                default: buffer_in <= buffer_in;
            endcase
            //end
        end else if (CS == PREPARE_BUFF) begin
            if(SECAP==4'd1)    
                buffer_in <= buffer_in >> 8*(168 - t_v_bytes_c_stage);
            else if (SECAP==4'd5 || SECAP==4'd9)
                buffer_in <= buffer_in >> 8*(168 - t_v_bytes_c_stage);
        end else if (CS == PREPARE_BUFF_2) begin
            if(SECAP==4'd1)
                buffer_in <= buffer_in; 
            else if (SECAP==4'd5 || SECAP==4'd9) begin
                buffer_in[1087:0]       <= buffer_in[1087:0]; 
                //buffer_in[1344:1088]    <= 0;
            end
        end
    end
    
    /*always @(posedge clk) begin
        if (rst_rejsamp || CS == FEED_OUT)
            buffer_in_count <= 0;
        else if (din_v_rejsamp && CS == FEED_IN)
            buffer_in_count <= buffer_in_count + 8;
        //else if (OP==`OP'd10 && (SECAP == 4'd5 || SECAP == 4'd9) && CS == FEED_IN && (buffer_in_count <= `RATE_SHAKE256_BYTES))
            //buffer_in_count <= buffer_in_count + 8;
    end*/
    
    always @(posedge clk) begin
        if (rst_rejsamp || CS == FEED_OUT)
            buffer_in_count <= 0;
        else if (din_v_rejsamp && CS == FEED_IN)
            buffer_in_count <= buffer_in_count + 8;
        else if (CS == FEED_IN && (OP==`OP'd10) && (SECAP == 4'd5 || SECAP == 4'd9) && !din_v_rejsamp && (buffer_in_count != 0) &&
                 (buffer_in_count < rate_constant))
            buffer_in_count <= rate_constant;
    end
    
    always @(posedge clk) begin
        if (rst_rejsamp || CS == FEED_OUT)
            t_v_bytes_c_stage <= 0;
        else if ((OP==`OP'd13 || OP==`OP'd14) && din_v_rejsamp && CS==FEED_IN)
            t_v_bytes_c_stage <= t_v_bytes_c_stage + 8;      // raw 8 bytes per beat
        else if (SECAP == 4'd1 && din_v_rejsamp && CS == FEED_IN)
            t_v_bytes_c_stage <= t_v_bytes_c_stage + v_bytes_in_word;
        else if ((SECAP == 4'd5 || SECAP == 4'd9) && din_v_rejsamp && CS == FEED_IN && (buffer_in_count <= `RATE_SHAKE256_BYTES-8))
            t_v_bytes_c_stage <= t_v_bytes_c_stage + v_bytes_in_word;
    end
    
    always @(posedge clk) begin
        if (rst_rejsamp)
            count_bytes_requested <= 0;
        else if ((OP==`OP'd13 || OP==`OP'd14) && CS==PREPARE_BUFF)
            count_bytes_requested <= count_bytes_requested + buffer_in_count; 
        else if ((OP!=`OP'd13 || OP!=`OP'd14) && CS==FEED_OUT)
            count_bytes_requested <= count_bytes_requested + v_bytes_for_expand;
    end
    
    always @(posedge clk) begin
        if (rst_rejsamp) begin
            CS <= IDLE;
        end else if (((OP!=`OP'd13 || OP!=`OP'd14) && count_bytes_requested >= length_rejsamp)) begin
            CS <= DONE;
        end else begin
            CS <= NS;
        end
    end
    
    /*always @(posedge clk) begin
        if (rst_rejsamp) begin
            CS <= IDLE;
        end else if (count_bytes_requested >= length_rejsamp)
            CS <= DONE;
        else
            CS <= NS;
    end*/
    
    always @(*) begin
    NS = CS;
    dout_v_rejsamp = 0;
    done_rejsamp   = 0;
    case (CS)
        IDLE: if (en_rejsamp) NS = FEED_IN;
        FEED_IN: begin 
            if((OP==`OP'd13 || OP==`OP'd14)) begin
                if(OLEN > rate_constant) begin
                    if (buffer_in_count >= rate_constant)
                        NS = PREPARE_BUFF;          
                    else
                        NS = FEED_IN;
                end else begin
                    if (buffer_in_count >= OLEN)
                        NS = PREPARE_BUFF;          
                    else
                        NS = FEED_IN;
                end
//                if (buffer_in_count >= rate_constant)
//                    NS = FEED_OUT;          // skip PREPARE for bypass
//                else
//                    NS = FEED_IN;
            end else begin
                if (OP==`OP'd15 && !din_v_rejsamp && buffer_in_count >= OLEN) 
                    NS = PREPARE_BUFF;
                else if (!din_v_rejsamp && buffer_in_count >= rate_constant) 
                    NS = PREPARE_BUFF;
                else
                    NS = FEED_IN;
            end
        end
        PREPARE_BUFF: begin
            NS = FEED_OUT; //PREPARE_BUFF_2;
        end
        PREPARE_BUFF_2: begin
            NS = FEED_OUT;
        end
        FEED_OUT: begin
            if((OP==`OP'd13 || OP==`OP'd14)) begin   // this deals with the hashed bytes before the rejection
                if (count_bytes_requested >= OLEN) begin 
                    dout_v_rejsamp = 1;
                    NS = DONE;
                end else begin
                    dout_v_rejsamp = 1;
                    NS = FEED_IN;
                end
            end else begin          // this deals with the hashed bytes after the rejection
                if (count_bytes_requested >= length_rejsamp) begin 
                    NS = DONE;
                end else begin
                    dout_v_rejsamp = 1;
                    NS = FEED_IN;
                end
            end
        end
        
        DONE: done_rejsamp = 1;
    endcase
    end
    
    //assign dout_rejsamp = (CS==FEED_OUT) ? buffer_in[8*`RATE_SHAKE128_BYTES-1:0] : dout_rejsamp; 
    //assign v_bytes_for_expand = (CS==FEED_OUT) ? t_v_bytes_c_stage : v_bytes_for_expand; 
    
    assign dout_rejsamp = (CS==FEED_OUT) ? buffer_in[8*`RATE_SHAKE128_BYTES-1:0] : dout_rejsamp;
    assign v_bytes_for_expand = (CS==FEED_OUT) ? t_v_bytes_c_stage : v_bytes_for_expand;
    //assign v_bytes_for_expand = (CS==FEED_OUT) ? ((OP==`OP'd13) ? count_bytes_requested : t_v_bytes_c_stage) : v_bytes_for_expand;

endmodule
