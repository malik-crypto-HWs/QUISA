`timescale 1ns / 1ps
//`include "parameters.vh"
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module arithmetic_unit_gen (
    input  clk,
    input  rst_au,
    input  en_au,
    input  is_KeyGen,
    input  is_Sign,
    input  is_Verify,
    input  [7:0]  m,
    input  [7:0]  V,
    input  [5:0]  M,
    input  [3:0]  l,
    input  [6:0]  q,
    input  [`OP-1:0] OP,
    input  [3:0] SECAP,
    input  [`DATA-1:0] din1,
    input  [`DATA-1:0] din2,
    output [`DATA-1:0] dout1,
    output [`DATA-1:0] dout2,
    output reg                  dout_v_au,
    output reg [`ADDR-1:0]      raddr1, raddr2,
    output reg [`ADDR-1:0]      waddr,
    output reg                  done_au
);
    
    parameter integer MAC_STAGES = 2;

    //======================================================================
    // Constants / decode
    //======================================================================
    localparam L_MEM = 2;
    localparam integer MAC_LAT = (MAC_STAGES<1) ? 0 :
                                 (MAC_STAGES>3) ? 2 : (MAC_STAGES-1);

    //======================================================================
    // FSM
    //======================================================================
    localparam IDLE                  = 4'd0,
               READ_FIRST            = 4'd1,
               READ_SECOND           = 4'd2,
               READ_THIRD            = 4'd3,
               FEED_IN               = 4'd4,
               FEED_OUT              = 4'd5,
               SUB_READ_FIRST        = 4'd6,
               SUB_READ_SECOND       = 4'd7,
               SUB_PRIME             = 4'd8,
               SUB_FEED_IN           = 4'd9,
               SUB_FEED_OUT          = 4'd10,
               RESET_BUFF_2_STAGE_1  = 4'd11,
               RESET_BUFF_2_STAGE_2  = 4'd12,
               RESET_BUFF_2_STAGE_3  = 4'd13,
               RESET_BUFF_2_STAGE_4  = 4'd14,
               DONE                  = 4'd15;

    wire is_mul     = (OP==`OP'd5  || OP==`OP'd7  || OP==`OP'd8 ||
                       OP==`OP'd11 || OP==`OP'd19 || OP==`OP'd23 || OP==`OP'd25 || OP==`OP'd26 || OP==`OP'd27);
    wire is_sub     = (OP==`OP'd6 || OP==`OP'd20);
    wire is_add     = (OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28);

    reg [3:0] CS, NS;

    reg [6:0] count_row_a, count_col_b;
    reg [7:0] idx_i;
    wire last_i     = (idx_i == (V-1));
    wire end_of_row = is_mul && (CS==FEED_OUT) && last_i;

    reg  inc_raddr1, inc_raddr2;
    reg  set_base_raddr1;
    reg  set_sym_start_b;

    reg        b_sym_mode;
    reg [7:0]  b_sym_left;
    reg [7:0]  b_stride;

    reg [7:0] tap_issue_cnt;
    reg [7:0] tap_cons_cnt;

    wire [7:0] Vm1 = V - 1'b1;
    wire [7:0] Mm1 = M - 1'b1;

    // OP19 / OP25 / OP27 use inner length M instead of V
    wire [7:0] op19_len    = M;
    wire [7:0] op19_len_m1 = M - 1'b1;

    // OP9 / OP24 add length
    // OP28 also uses M automatically
    wire [7:0] add_len    = ((OP==`OP'd9 || OP==`OP'd24) && is_Verify) ? V : 
                            (OP==`OP'd28) ? m  : 
                            {2'b00, M};
    wire [7:0] add_len_m1 = add_len - 1'b1;

    //======================================================================
    // BRAM issue timing
    //======================================================================
    wire pre_issue_mul     = (CS==READ_THIRD);
    wire issue_addr_fi_mul = (CS==FEED_IN) &&
                             ((((OP==`OP'd19) || (OP==`OP'd25) || (OP==`OP'd27)) && (op19_len!=0) && (tap_issue_cnt < op19_len_m1)) ||
                              (((OP!=`OP'd19) && (OP!=`OP'd25) && (OP!=`OP'd27)) && (V!=0)        && (tap_issue_cnt < Vm1)));

    wire pre_issue_sub     = (CS==SUB_PRIME);

    wire issue_addr_fi_sub = (OP==`OP'd20) ? ((CS==SUB_FEED_IN) && (V!=0) && (tap_issue_cnt < Vm1)) :
                             (is_Sign)     ? ((CS==SUB_FEED_IN) && (M!=0) && (tap_issue_cnt < Mm1)) :
                                             ((CS==SUB_FEED_IN) && (V!=0) && (tap_issue_cnt < Vm1));
                    
    wire pre_issue_add     = (CS==SUB_PRIME);
    wire issue_addr_fi_add = (CS==SUB_FEED_IN) && (add_len!=0) && (tap_issue_cnt < add_len_m1);

    wire pre_issue_any     = (is_mul & pre_issue_mul) | (is_sub & pre_issue_sub) | (is_add & pre_issue_add);
    wire issue_addr_fi_any = (is_mul & issue_addr_fi_mul) | (is_sub & issue_addr_fi_sub) | (is_add & issue_addr_fi_add);

    //======================================================================
    // Valid align / staging
    //======================================================================
    reg [L_MEM-1:0] din_v_sr;
    wire din_v_au_w = din_v_sr[L_MEM-1];

    reg  [23:0] a_hold, b_hold;
    reg         din_use_sr;
    wire        din_use = din_use_sr;

    wire [7:0] a0 = a_hold[7:0];
    wire [7:0] a1 = a_hold[15:8];
    wire [7:0] a2 = a_hold[23:16];
    wire [7:0] b0 = b_hold[7:0];
    wire [7:0] b1 = b_hold[15:8];
    wire [7:0] b2 = b_hold[23:16];

    reg  [2:0] mac_cons_sr;
    wire       mac_consume = (MAC_LAT==0) ? din_use : mac_cons_sr[MAC_LAT-1];

    wire clr_acc = rst_au | (CS==READ_THIRD);
    wire release_out_bytes = (NS==FEED_OUT);

    wire [23:0] mac_pack, sub_out, add_out;
    reg [6:0] count;

    //======================================================================
    // Instances
    //======================================================================
    MAC_TILE #(.MAC_STAGES(MAC_STAGES)) mac_tile_uut (
      .clk(clk),
      .rst_au(rst_au),
      .din_use(din_use),
      .clr_acc(clr_acc),
      .release_out_bytes(release_out_bytes),
      .a0(a0), .a1(a1), .a2(a2),
      .b0(b0), .b1(b1), .b2(b2),
      .mac_pack(mac_pack)
    );

    mod_sub mod_sub_uut (
      .a0(a0), .a1(a1), .a2(a2),
      .b0(b0), .b1(b1), .b2(b2),
      .sub_out(sub_out)
    );
    
    mod_add mod_add_uut (
      .is_KeyGen(is_KeyGen),
      .is_Sign(is_Sign),
      .is_Verify(is_Verify),
      .OP(OP),
      .a0(a0), .a1(a1), .a2(a2),
      .b0(b0), .b1(b1), .b2(b2),
      .add_out(add_out)
    );

    //======================================================================
    // FSM reg
    //======================================================================
    always @(posedge clk) begin
        if (rst_au) CS <= IDLE;
        else        CS <= NS;
    end

    //======================================================================
    // count_row_a
    //======================================================================
    always @(posedge clk) begin
        if (rst_au)
            count_row_a <= 0;
        else if (OP==`OP'd5 && is_mul) begin
            if (end_of_row)
                count_row_a <= count_row_a + 1'b1;
        end else if ((OP==`OP'd6 || OP==`OP'd20) && is_sub) begin 
            if (is_KeyGen && count == V)
                count_row_a <= count_row_a + 1'b1;
            else if (is_Sign && OP==`OP'd6 && count == M-1)
                count_row_a <= count_row_a + 1'b1;
            else if (OP==`OP'd20 && count == V-1)
                count_row_a <= count_row_a + 1'b1;
        end else if (((OP==`OP'd7 || OP==`OP'd19 || OP==`OP'd25) && is_mul) || (OP==`OP'd8 && is_mul)) begin 
            if ((OP!=`OP'd19 && OP!=`OP'd25) && CS==FEED_OUT && count_col_b == (M-1))
                count_row_a <= count_row_a + 1'b1;
        end else if ((OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28) && is_add) begin
            if (count == add_len)
                count_row_a <= count_row_a + 1'b1;
        end else if (OP==`OP'd11) begin
            if (CS==FEED_IN && tap_cons_cnt==V)
                count_row_a <= count_row_a + 1'b1;
        end else if (OP==`OP'd23 && is_mul) begin 
            if (CS==FEED_OUT && count_col_b == (V-1))
                count_row_a <= count_row_a + 1'b1;
        end else if (OP==`OP'd26 && is_mul) begin 
            if (CS==FEED_IN && tap_cons_cnt == V)
                count_row_a <= count_row_a + 1'b1;
        end else if (OP==`OP'd27 && is_mul) begin 
            if (CS==FEED_IN && tap_cons_cnt == M)
                count_row_a <= count_row_a + 1'b1;
        end
    end
        
    //======================================================================
    // count_col_b
    //======================================================================
    always @(posedge clk) begin
        if (rst_au)
            count_col_b <= 0;
        else if (OP==`OP'd7 && is_mul) begin 
            if (CS==FEED_OUT) begin
                if (count_col_b == (M-1)) 
                    count_col_b <= 0;
                else
                    count_col_b <= count_col_b + 1'b1;
            end
        end else if (OP==`OP'd19 && is_mul) begin
            if (CS==FEED_OUT) begin
                if (count_col_b == V)
                    count_col_b <= 0;
                else
                    count_col_b <= count_col_b + 1'b1;
            end
        end else if (OP==`OP'd23 && is_mul) begin
            if (CS==FEED_OUT) begin
                if (count_col_b == V)
                    count_col_b <= 0;
                else
                    count_col_b <= count_col_b + 1'b1;
            end
        end else if (OP==`OP'd25 && is_mul) begin
            if (CS==FEED_OUT) begin
                if (count_col_b == M)
                    count_col_b <= 0;
                else
                    count_col_b <= count_col_b + 1'b1;
            end
        end else if (OP==`OP'd8 && is_mul) begin 
            if (CS==FEED_OUT) begin
                if (count_col_b == (M-1)) 
                    count_col_b <= 0;
                else
                    count_col_b <= count_col_b + 1'b1;
            end
        end else if (OP==`OP'd11 && is_mul) begin 
            if (CS==FEED_IN && tap_cons_cnt==V) begin
                count_col_b <= count_col_b + 1'b1;
            end
        end
    end
    
    //======================================================================
    // count
    //======================================================================
    always @(posedge clk) begin
        if (rst_au ||
            ((OP==`OP'd20)                && (count == V)) ||
            ((OP==`OP'd6)  && is_Sign    && (count == M)) ||
            ((OP==`OP'd6)  && !is_Sign   && (count == V)) ||
            ((OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28) && (count == add_len)))
            count <= 0;
        else if (din_v_au_w)
            count <= count + 1'b1;
    end

    always @(posedge clk) begin
        if (rst_au)
            idx_i <= 0;
        else if (CS==FEED_OUT)
            idx_i <= last_i ? 8'd0 : (idx_i + 1'b1);
    end

    //======================================================================
    // raddr1
    //======================================================================
    always @(posedge clk) begin
        if (rst_au) begin
            raddr1 <= 0;
        end 
        else if (OP==`OP'd5 && is_mul) begin
            if (is_Sign) begin
                if (set_base_raddr1 || CS==IDLE) raddr1 <= count_row_a;
                else if (inc_raddr1)             raddr1 <= raddr1 + 1;
            end else begin
                if (set_base_raddr1 || CS==IDLE) raddr1 <= count_row_a;
                else if (inc_raddr1)             raddr1 <= raddr1 + M;
            end
        end 
        else if ((OP==`OP'd6 || OP==`OP'd20) && is_sub) begin
            if (CS==IDLE)                       raddr1 <= count_row_a;
            else if (is_KeyGen && inc_raddr1)   raddr1 <= raddr1 + M;
            else if (is_Sign   && inc_raddr1)   raddr1 <= raddr1 + 1;
        end 
        else if (((OP==`OP'd7) || OP==`OP'd11) && is_mul) begin
            if(is_Sign) begin
                if (set_base_raddr1 || CS==IDLE) raddr1 <= count_row_a;
                else if (inc_raddr1)             raddr1 <= raddr1 + 1;
            end else begin
                if (set_base_raddr1 || CS==IDLE) raddr1 <= (count_row_a * V);
                else if (inc_raddr1)             raddr1 <= raddr1 + 1;
            end
        end 
        else if ((OP==`OP'd19 || OP==`OP'd25) && is_mul) begin
            if (set_base_raddr1 || CS==IDLE) raddr1 <= count_col_b * M;
            else if (inc_raddr1)             raddr1 <= raddr1 + 1;
        end 
        else if (OP==`OP'd8 && is_mul) begin
            if (set_base_raddr1 || CS==IDLE) raddr1 <= count_row_a;
            else if (inc_raddr1)             raddr1 <= raddr1 + M;
        end 
        else if ((OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28) && is_add) begin
            if (CS==IDLE)                    raddr1 <= count_row_a;
            else if (inc_raddr1)             raddr1 <= raddr1 + 1;
        end 
        else if ((OP==`OP'd23 || OP==`OP'd26 || OP==`OP'd27) && is_mul) begin
            if (set_base_raddr1 || CS==IDLE) raddr1 <= 0;
            else if (inc_raddr1)             raddr1 <= raddr1 + 1;
        end
    end
    
    //======================================================================
    // raddr2
    //======================================================================
    always @(posedge clk) begin
        if (rst_au) begin
            raddr2     <= 0;
            b_sym_mode <= 1'b0;
            b_sym_left <= 8'd0;
            b_stride   <= 8'd0;
        end 
        else if (OP==`OP'd5 && is_mul) begin
            if (set_sym_start_b) begin
                raddr2     <= idx_i;
                b_sym_mode <= (idx_i!=0);
                b_sym_left <= idx_i;
                b_stride   <= (V>0) ? (V-1) : 8'd0;
            end else if (inc_raddr2) begin
                if (b_sym_mode) begin
                    raddr2     <= raddr2 + b_stride;
                    b_stride   <= b_stride - 8'd1;
                    b_sym_left <= b_sym_left - 8'd1;
                    if (b_sym_left == 8'd1) b_sym_mode <= 1'b0;
                end else begin
                    raddr2 <= raddr2 + 1'b1;
                end
            end
        end 
        else if ((OP==`OP'd6 || OP==`OP'd20) && is_sub) begin
            if (inc_raddr2) raddr2 <= raddr2 + 1'b1;
        end 
        else if (OP==`OP'd7 && is_mul) begin
            if (set_sym_start_b) raddr2 <= count_col_b;
            else if (inc_raddr2) raddr2 <= raddr2 + M;
        end 
        else if ((OP==`OP'd23 || OP==`OP'd26 || OP==`OP'd27) && is_mul) begin
            if (set_sym_start_b) begin
                raddr2     <= count_col_b;
                b_sym_mode <= (count_col_b!=0);
                b_sym_left <= count_col_b;
                b_stride   <= (V>0) ? (V-1) : 8'd0;
            end else if (inc_raddr2) begin
                if (b_sym_mode) begin
                    raddr2     <= raddr2 + b_stride;
                    b_stride   <= b_stride - 1'b1;
                    b_sym_left <= b_sym_left - 1'b1;
                    if (b_sym_left == 8'd1) b_sym_mode <= 1'b0;
                end else begin
                    raddr2 <= raddr2 + 1'b1;
                end
            end
        end
        else if ((OP==`OP'd19 || OP==`OP'd25) && is_mul) begin
            if (set_sym_start_b || CS==IDLE) raddr2 <= 0;
            else if (inc_raddr2)             raddr2 <= raddr2 + 1'b1;
        end 
        else if (OP==`OP'd8 && is_mul) begin
            if (set_sym_start_b) raddr2 <= count_col_b;
            else if (inc_raddr2) raddr2 <= raddr2 + M;
        end 
        else if ((OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28) && is_add) begin
            if (inc_raddr2) raddr2 <= raddr2 + 1'b1;
        end 
        else if (OP==`OP'd11 && is_mul) begin
            if (set_sym_start_b) raddr2 <= count_col_b;
            else if (inc_raddr2) raddr2 <= raddr2 + 1'b1;
        end
    end

    //======================================================================
    // Tap issue/consume & staging
    //======================================================================
    always @(posedge clk) begin
        if (rst_au) din_v_sr <= {L_MEM{1'b0}};
        else        din_v_sr <= {din_v_sr[L_MEM-2:0], (pre_issue_any | issue_addr_fi_any)};
    end

    always @(posedge clk) begin
        if (rst_au) begin
            a_hold     <= 24'd0;
            b_hold     <= 24'd0;
            din_use_sr <= 1'b0;
        end else begin
            din_use_sr <= din_v_au_w;
            if (din_v_au_w) begin
                a_hold <= din1;
                b_hold <= din2;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_au) mac_cons_sr <= 3'b000;
        else        mac_cons_sr <= {mac_cons_sr[1:0], din_use};
    end

    always @(posedge clk) begin
        if (rst_au || CS==READ_THIRD || CS==FEED_OUT || CS==DONE
                   || CS==SUB_PRIME   || CS==SUB_FEED_OUT)
            tap_issue_cnt <= 8'd0;
        else if (issue_addr_fi_any)
            tap_issue_cnt <= tap_issue_cnt + 1'b1;
    end

    always @(posedge clk) begin
        if (rst_au || CS==READ_THIRD || CS==FEED_OUT || CS==DONE
                   || CS==SUB_PRIME   || CS==SUB_FEED_OUT)
            tap_cons_cnt <= 8'd0;
        else if (is_mul && mac_consume)
            tap_cons_cnt <= tap_cons_cnt + 1'b1;
        else if ((is_sub || is_add) && din_use)
            tap_cons_cnt <= tap_cons_cnt + 1'b1;
    end

    //======================================================================
    // Datapath select
    //======================================================================
    assign dout1 = (OP==`OP'd5 || OP==`OP'd7 || OP==`OP'd8 || OP==`OP'd11 ||
                    OP==`OP'd19 || OP==`OP'd23 || OP==`OP'd25 || OP==`OP'd26 || OP==`OP'd27) ? mac_pack
                  : (OP==`OP'd6 || OP==`OP'd20) ? sub_out
                  : (OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28) ? add_out
                  : {`DATA{1'b0}};

    assign dout2 = dout1;

    always @(posedge clk) begin
        if (rst_au) dout_v_au <= 1'b0;
        else if (is_mul) dout_v_au <= (NS==FEED_OUT);
        else if (is_sub) dout_v_au <= din_v_au_w;
        else if (is_add) dout_v_au <= din_v_au_w;
        else             dout_v_au <= 1'b0;
    end

    always @(posedge clk) begin
        if (rst_au)         waddr <= 0;
        else if (dout_v_au) waddr <= waddr + 1'b1;
    end

    //======================================================================
    // Next-state & controls
    //======================================================================
    always @(*) begin
        NS              = CS;
        done_au         = 1'b0;
        inc_raddr1      = 1'b0;
        inc_raddr2      = 1'b0;
        set_base_raddr1 = 1'b0;
        set_sym_start_b = 1'b0;

        case (CS)
        IDLE: begin
            if (en_au && is_mul) NS = READ_FIRST;
            else if ((en_au && is_sub) || (en_au && is_add)) NS = SUB_READ_FIRST;
        end

        //======================================================
        // MUL path
        //======================================================
        READ_FIRST:  begin 
            if (is_Sign && OP==`OP'd5 && count_row_a)
                NS = DONE;
            else if (is_Sign && (OP==`OP'd7 || OP==`OP'd11) && count_row_a)
                NS = DONE;
            else if (is_Sign && OP==`OP'd19 && (count_col_b == V))
                NS = DONE;
            else if (is_Verify && OP==`OP'd23 && (count_col_b == V))
                NS = DONE;
            else if (OP==`OP'd25 && (count_col_b == M))
                NS = DONE;
            else if ((OP==`OP'd26 || OP==`OP'd27) && count_row_a == 1)
                NS = DONE;
            else
                NS = READ_SECOND;
        end

        READ_SECOND: begin
            if(OP==`OP'd5) begin
                set_base_raddr1 = 1'b1;
                set_sym_start_b = 1'b1;
                NS = READ_THIRD;
            end else if (OP==`OP'd7 || OP==`OP'd8 || OP==`OP'd11 ||
                         OP==`OP'd19 || OP==`OP'd23 || OP==`OP'd25 || OP==`OP'd26 || OP==`OP'd27) begin
                set_base_raddr1 = 1'b1;
                set_sym_start_b = 1'b1;
                NS = READ_THIRD;
            end
        end

        READ_THIRD: begin
            inc_raddr1 = 1'b1;
            inc_raddr2 = 1'b1;
            NS = FEED_IN;
        end

        FEED_IN: begin
            inc_raddr1 = issue_addr_fi_mul;
            inc_raddr2 = issue_addr_fi_mul;

            if ((((OP==`OP'd19) || (OP==`OP'd25) || (OP==`OP'd27)) && (tap_cons_cnt == op19_len)) ||
                (((OP!=`OP'd19) && (OP!=`OP'd25) && (OP!=`OP'd27)) && (tap_cons_cnt == V)))
                NS = FEED_OUT;
        end

        FEED_OUT: begin
            if(OP==`OP'd5) begin
                if(is_Sign) begin
                    if (count_row_a)       NS = DONE;
                    else                   NS = READ_FIRST;
                end else begin
                    if ((count_row_a >= M-1) && last_i) NS = DONE;
                    else if (last_i)                    NS = IDLE;
                    else                                NS = READ_FIRST;
                end
            end else if (OP==`OP'd7 || OP==`OP'd8 || OP==`OP'd11) begin
                if(is_Sign) begin
                    if (count_row_a) NS = DONE;
                    else             NS = READ_FIRST;
                end else begin
                    if ((count_row_a == (M-1)) && (count_col_b == (M-1)))
                        NS = DONE;
                    else
                        NS = READ_FIRST;
                end
            end else if (OP==`OP'd19 || OP==`OP'd23) begin
                if(is_Sign || is_Verify) begin
                    if (count_col_b == V) NS = DONE;
                    else                  NS = READ_FIRST;
                end else begin
                    if (count_col_b == (V-1)) NS = DONE;
                    else                      NS = READ_FIRST;
                end
            end else if (OP==`OP'd25) begin
                if (count_col_b == M)
                    NS = DONE;
                else
                    NS = READ_FIRST;
            end else if (OP==`OP'd26 || OP==`OP'd27) begin
                NS = DONE;
            end
        end

        //======================================================
        // SUB / ADD path
        //======================================================
        SUB_READ_FIRST:  NS = SUB_READ_SECOND;
        SUB_READ_SECOND: NS = SUB_PRIME;

        SUB_PRIME: begin
            inc_raddr1 = 1'b1;
            inc_raddr2 = 1'b1;
            NS = SUB_FEED_IN;
        end

        SUB_FEED_IN: begin
            if((OP==`OP'd6 || OP==`OP'd20) && is_sub) begin
                inc_raddr1 = issue_addr_fi_sub;
                inc_raddr2 = issue_addr_fi_sub;

                if(is_Sign) begin
                    if (count_row_a) NS = SUB_FEED_OUT;
                end else begin
                    if (count == V && count_row_a == M-1) NS = SUB_FEED_OUT;
                    else if (count == V && count_row_a < M) NS = IDLE;
                end
            end 

            if((OP==`OP'd9 || OP==`OP'd24 || OP==`OP'd28) && is_add) begin
                inc_raddr1 = issue_addr_fi_add;
                inc_raddr2 = issue_addr_fi_add;

                if (OP==`OP'd28) begin
                    if (count_row_a == 1)
                        NS = SUB_FEED_OUT;
                end else if (is_KeyGen) begin
                    if (count == add_len && count_row_a == M-1)
                        NS = SUB_FEED_OUT;
                    else if (count == add_len && count_row_a < M)
                        NS = SUB_PRIME;
                end else if (is_Verify) begin
                    if (count == add_len)
                        NS = SUB_FEED_OUT;
                end else if (is_Sign) begin
                    if (count_row_a == 1)
                        NS = SUB_FEED_OUT;
                end
            end
        end

        SUB_FEED_OUT: begin
            NS = DONE;
        end

        DONE: begin
            done_au = 1'b1;
        end

        default: NS = IDLE;
        endcase
    end

endmodule