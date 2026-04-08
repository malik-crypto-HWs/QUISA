`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module sample_sol (
    input  wire               clk,
    input  wire               rst_sol,
    input  wire               en_sol,
    input  wire [7:0]         m,        // 54 / 78 / 105
    input  wire [5:0]         M,        // words per row
    input  wire [3:0]         l,        // 3 bytes per word
    input  wire [6:0]         q,        // 127
    input  wire [`OP-1:0]     OP,

    // Port 1 : LU matrix rows
    input  wire [23:0]        din1,
    output reg  [`ADDR-1:0]   raddr1,

    // Port 2 : b[] read | b2[] and x[] write
    input  wire [23:0]        din2,
    output reg  [`ADDR-1:0]   raddr2,
    output reg  [23:0]        dout2,
    output reg  [`ADDR-1:0]   waddr,
    output reg                dout_v,

    // metadata from LU/top registers
    input  wire [6:0]         rank_meta,
    input  wire [7*105-1:0]   orig_row_id_bus,
    input  wire [7*105-1:0]   index_map_bus,

    output reg                done_sol
);

    localparam integer MAX_M = 105;

    // -------------------------------
    // Fq inverse table (q=127)
    // -------------------------------
    reg [6:0] Fq_inv_table [0:126];
    initial begin
        Fq_inv_table[0]=0;Fq_inv_table[1]=1;Fq_inv_table[2]=64;Fq_inv_table[3]=85;Fq_inv_table[4]=32;
        Fq_inv_table[5]=51;Fq_inv_table[6]=106;Fq_inv_table[7]=109;Fq_inv_table[8]=16;Fq_inv_table[9]=113;
        Fq_inv_table[10]=89;Fq_inv_table[11]=104;Fq_inv_table[12]=53;Fq_inv_table[13]=88;Fq_inv_table[14]=118;
        Fq_inv_table[15]=17;Fq_inv_table[16]=8;Fq_inv_table[17]=15;Fq_inv_table[18]=120;Fq_inv_table[19]=107;
        Fq_inv_table[20]=108;Fq_inv_table[21]=121;Fq_inv_table[22]=52;Fq_inv_table[23]=116;Fq_inv_table[24]=90;
        Fq_inv_table[25]=61;Fq_inv_table[26]=44;Fq_inv_table[27]=80;Fq_inv_table[28]=59;Fq_inv_table[29]=92;
        Fq_inv_table[30]=72;Fq_inv_table[31]=41;Fq_inv_table[32]=4;Fq_inv_table[33]=77;Fq_inv_table[34]=71;
        Fq_inv_table[35]=98;Fq_inv_table[36]=60;Fq_inv_table[37]=103;Fq_inv_table[38]=117;Fq_inv_table[39]=114;
        Fq_inv_table[40]=54;Fq_inv_table[41]=31;Fq_inv_table[42]=124;Fq_inv_table[43]=65;Fq_inv_table[44]=26;
        Fq_inv_table[45]=48;Fq_inv_table[46]=58;Fq_inv_table[47]=100;Fq_inv_table[48]=45;Fq_inv_table[49]=70;
        Fq_inv_table[50]=94;Fq_inv_table[51]=5;Fq_inv_table[52]=22;Fq_inv_table[53]=12;Fq_inv_table[54]=40;
        Fq_inv_table[55]=97;Fq_inv_table[56]=93;Fq_inv_table[57]=78;Fq_inv_table[58]=46;Fq_inv_table[59]=28;
        Fq_inv_table[60]=36;Fq_inv_table[61]=25;Fq_inv_table[62]=84;Fq_inv_table[63]=125;Fq_inv_table[64]=2;
        Fq_inv_table[65]=43;Fq_inv_table[66]=102;Fq_inv_table[67]=91;Fq_inv_table[68]=99;Fq_inv_table[69]=81;
        Fq_inv_table[70]=49;Fq_inv_table[71]=34;Fq_inv_table[72]=30;Fq_inv_table[73]=87;Fq_inv_table[74]=115;
        Fq_inv_table[75]=105;Fq_inv_table[76]=122;Fq_inv_table[77]=33;Fq_inv_table[78]=57;Fq_inv_table[79]=82;
        Fq_inv_table[80]=27;Fq_inv_table[81]=69;Fq_inv_table[82]=79;Fq_inv_table[83]=101;Fq_inv_table[84]=62;
        Fq_inv_table[85]=3;Fq_inv_table[86]=96;Fq_inv_table[87]=73;Fq_inv_table[88]=13;Fq_inv_table[89]=10;
        Fq_inv_table[90]=24;Fq_inv_table[91]=67;Fq_inv_table[92]=29;Fq_inv_table[93]=56;Fq_inv_table[94]=50;
        Fq_inv_table[95]=123;Fq_inv_table[96]=86;Fq_inv_table[97]=55;Fq_inv_table[98]=35;Fq_inv_table[99]=68;
        Fq_inv_table[100]=47;Fq_inv_table[101]=83;Fq_inv_table[102]=66;Fq_inv_table[103]=37;Fq_inv_table[104]=11;
        Fq_inv_table[105]=75;Fq_inv_table[106]=6;Fq_inv_table[107]=19;Fq_inv_table[108]=20;Fq_inv_table[109]=7;
        Fq_inv_table[110]=112;Fq_inv_table[111]=119;Fq_inv_table[112]=110;Fq_inv_table[113]=9;Fq_inv_table[114]=39;
        Fq_inv_table[115]=74;Fq_inv_table[116]=23;Fq_inv_table[117]=38;Fq_inv_table[118]=14;Fq_inv_table[119]=111;
        Fq_inv_table[120]=18;Fq_inv_table[121]=21;Fq_inv_table[122]=76;Fq_inv_table[123]=95;Fq_inv_table[124]=42;
        Fq_inv_table[125]=63;Fq_inv_table[126]=126;
    end

    // -------------------------------
    // mod-127 arithmetic
    // -------------------------------
    function automatic [6:0] sub_mod127;
        input [6:0] x, y;
        reg [7:0] tmp;
        begin
            if (x >= y) sub_mod127 = x - y;
            else begin
                tmp = {1'b0,x} + 8'd127 - {1'b0,y};
                sub_mod127 = tmp[6:0];
            end
        end
    endfunction

    function automatic [6:0] red127_20;
        input [20:0] p;
        reg  [13:0] s1;
        reg  [7:0]  s2;
        reg  [6:0]  t;
        begin
            s1 = {7'b0, p[6:0]} + {1'b0, p[20:7]};
            s2 = {1'b0, s1[6:0]} + {1'b0, s1[13:7]};
            t  = s2[6:0] + s2[7];
            red127_20 = (t == 7'd127) ? 7'd0 : t;
        end
    endfunction

    function automatic [6:0] mul_mod127;
        input [6:0] a, b;
        reg [13:0] p;
        reg [7:0]  s;
        reg [6:0]  t;
        begin
            p = a * b;
            s = {1'b0, p[6:0]} + {1'b0, p[13:7]};
            t = s[6:0] + s[7];
            mul_mod127 = (t == 7'd127) ? 7'd0 : t;
        end
    endfunction

    function [`ADDR-1:0] base_addr_row;
        input [6:0] row_idx;
        begin
            base_addr_row = row_idx * M;
        end
    endfunction

    // -------------------------------
    // FSM
    // -------------------------------
    localparam [3:0]
        IDLE         = 4'd0,
        LOAD_ROW     = 4'd1,
        ROW_WAIT1    = 4'd2,
        ROW_WAIT2    = 4'd3,
        P1_MAC       = 4'd4,
        P1_READ_B    = 4'd5,
        P1_WAIT_B1   = 4'd6,
        P1_WAIT_B2   = 4'd7,
        P1_WRITE_B2  = 4'd8,
        P2_PREP      = 4'd9,
        P2_MAC       = 4'd10,
        P2_STORE     = 4'd11,
        X_STREAM     = 4'd12,
        DONE         = 4'd13;

    reg [3:0] state;

    // buffers
    reg [6:0] row_buf [0:MAX_M-1];
    reg [6:0] b2_buf  [0:MAX_M-1];
    reg [6:0] x_buf   [0:MAX_M-1];

    // unpacked metadata
    reg [6:0] orig_row_id [0:MAX_M-1];
    reg [6:0] index_map   [0:MAX_M-1];

    reg [6:0] row_sel;
    reg [6:0] i;
    reg [6:0] j;
    reg [6:0] k;
    reg [6:0] req_w, cap_w;

    reg [6:0] i_ptr;
    reg [20:0] t_acc;

    reg [6:0] b_idx;
    reg [6:0] b_val;

    reg [6:0] b2_calc;
    reg [6:0] x_calc;

    reg [23:0] word_tmp;
    reg [5:0]  x_word_idx;

    integer zz;
    integer mm;

    // unpack metadata buses
    always @(*) begin
        for (mm = 0; mm < MAX_M; mm = mm + 1) begin
            orig_row_id[mm] = orig_row_id_bus[mm*7 +: 7];
            index_map[mm]   = index_map_bus[mm*7 +: 7];
        end
    end

    always @(posedge clk) begin
        if (rst_sol) begin
            state    <= IDLE;
            done_sol <= 1'b0;
            dout_v   <= 1'b0;

            raddr1   <= 0;
            raddr2   <= 0;
            waddr    <= 0;
            dout2    <= 0;

            row_sel  <= 0;
            i        <= 0;
            j        <= 0;
            k        <= 0;
            req_w    <= 0;
            cap_w    <= 0;

            i_ptr    <= 0;

            t_acc    <= 0;
            b_idx    <= 0;
            b_val    <= 0;

            b2_calc  <= 0;
            x_calc   <= 0;

            x_word_idx <= 0;

            for (zz = 0; zz < MAX_M; zz = zz + 1) begin
                row_buf[zz] <= 0;
                b2_buf[zz]  <= 0;
                x_buf[zz]   <= 0;
            end
        end else begin
            dout_v <= 1'b0;

            case (state)

            IDLE: begin
                done_sol <= 1'b0;
                if (en_sol && OP == `OP'd18) begin
                    if (rank_meta == 0) begin
                        // rank 0: all variables are free (currently filled with zero)
                        for (zz = 0; zz < MAX_M; zz = zz + 1)
                            x_buf[zz] <= 0;
                        x_word_idx <= 0;
                        state      <= X_STREAM;
                    end else begin
                        i       <= 0;
                        row_sel <= 0;
                        req_w   <= 1;
                        cap_w   <= 0;
                        raddr1  <= base_addr_row(0);
                        state   <= LOAD_ROW;
                    end
                end
            end

            // -------- read EQN[row_sel][0..m-1] into row_buf --------
            LOAD_ROW: begin
                if (req_w < M) begin
                    raddr1 <= base_addr_row(row_sel) + req_w;
                    req_w  <= req_w + 1;
                end

                if ((req_w >= 2) && (cap_w < (req_w - 2))) begin
                    row_buf[cap_w*l]   <= din1[7:0];
                    row_buf[cap_w*l+1] <= din1[15:8];
                    row_buf[cap_w*l+2] <= din1[23:16];
                    cap_w <= cap_w + 1;
                end

                if (req_w == M)
                    state <= ROW_WAIT1;
            end

            ROW_WAIT1: begin
                if (cap_w < M) begin
                    row_buf[cap_w*l]   <= din1[7:0];
                    row_buf[cap_w*l+1] <= din1[15:8];
                    row_buf[cap_w*l+2] <= din1[23:16];
                    cap_w <= cap_w + 1;
                end
                state <= ROW_WAIT2;
            end

            ROW_WAIT2: begin
                if (cap_w < M) begin
                    row_buf[cap_w*l]   <= din1[7:0];
                    row_buf[cap_w*l+1] <= din1[15:8];
                    row_buf[cap_w*l+2] <= din1[23:16];
                    cap_w <= cap_w + 1;
                end

                if (i < rank_meta) begin
                    t_acc <= 0;
                    k     <= 0;
                    state <= P1_MAC;
                end else begin
                    state <= P2_PREP;
                end
            end

            // -------------------------------
            // PHASE 1: forward substitution
            // b2[i] = (b[orig_row_id[i]] - sum(EQN(i,j)*b2[j])) * inv(EQN(i,i))
            // -------------------------------
            P1_MAC: begin
                if (k < i) begin
                    t_acc <= t_acc + (row_buf[k] * b2_buf[k]);
                    k     <= k + 1;
                end else begin
                    b_idx  <= orig_row_id[i];
                    raddr2 <= orig_row_id[i] / l;
                    state  <= P1_READ_B;
                end
            end

            P1_READ_B:  state <= P1_WAIT_B1;
            P1_WAIT_B1: state <= P1_WAIT_B2;

            P1_WAIT_B2: begin
                case (b_idx % l)
                    0: b_val <= din2[7:0];
                    1: b_val <= din2[15:8];
                    2: b_val <= din2[23:16];
                    default: b_val <= 0;
                endcase
                state <= P1_WRITE_B2;
            end

            P1_WRITE_B2: begin
                b2_calc   <= mul_mod127(
                                sub_mod127(b_val, red127_20(t_acc)),
                                Fq_inv_table[row_buf[i]]
                             );
                b2_buf[i] <= mul_mod127(
                                sub_mod127(b_val, red127_20(t_acc)),
                                Fq_inv_table[row_buf[i]]
                             );

                word_tmp[7:0]   = {1'b0, b2_buf[(i/3)*3 + 0]};
                word_tmp[15:8]  = {1'b0, b2_buf[(i/3)*3 + 1]};
                word_tmp[23:16] = {1'b0, b2_buf[(i/3)*3 + 2]};

                case (i % l)
                    0: word_tmp[7:0]   = {1'b0, mul_mod127(sub_mod127(b_val, red127_20(t_acc)), Fq_inv_table[row_buf[i]])};
                    1: word_tmp[15:8]  = {1'b0, mul_mod127(sub_mod127(b_val, red127_20(t_acc)), Fq_inv_table[row_buf[i]])};
                    2: word_tmp[23:16] = {1'b0, mul_mod127(sub_mod127(b_val, red127_20(t_acc)), Fq_inv_table[row_buf[i]])};
                endcase

                if ((i % l == 2) || (i == rank_meta - 1)) begin
                    waddr  <= (i / l);
                    dout2  <= word_tmp;
                    dout_v <= 1'b1;
                end

                if (i < rank_meta - 1) begin
                    i       <= i + 1;
                    row_sel <= i + 1;
                    req_w   <= 1;
                    cap_w   <= 0;
                    raddr1  <= base_addr_row(i + 1);
                    state   <= LOAD_ROW;
                end else begin
                    j       <= rank_meta - 1;
                    i       <= rank_meta;
                    i_ptr   <= m - 1;
                    row_sel <= rank_meta - 1;
                    req_w   <= 1;
                    cap_w   <= 0;
                    raddr1  <= base_addr_row(rank_meta - 1);
                    state   <= LOAD_ROW;
                end
            end

            // -------------------------------
            // PHASE 2: back substitution
            // free variables are currently filled with zero
            // -------------------------------
            P2_PREP: begin
                if (i_ptr > index_map[j]) begin
                    x_buf[i_ptr] <= 7'd0;
                    i_ptr        <= i_ptr - 1;
                end else begin
                    t_acc <= 0;
                    k     <= index_map[j] + 1;
                    state <= P2_MAC;
                end
            end

            P2_MAC: begin
                if (k < m) begin
                    t_acc <= t_acc + (row_buf[k] * x_buf[k]);
                    k     <= k + 1;
                end else begin
                    x_calc <= sub_mod127(b2_buf[j], red127_20(t_acc));
                    state  <= P2_STORE;
                end
            end

            P2_STORE: begin
                x_buf[index_map[j]] <= x_calc;

                if (i_ptr != 0)
                    i_ptr <= i_ptr - 1;

                if (j > 0) begin
                    j       <= j - 1;
                    row_sel <= j - 1;
                    req_w   <= 1;
                    cap_w   <= 0;
                    raddr1  <= base_addr_row(j - 1);
                    state   <= LOAD_ROW;
                end else begin
                    // if rank<m, remaining low-index free vars stay 0
                    x_word_idx <= 0;
                    state      <= X_STREAM;
                end
            end

            // stream x[0..m-1] to memory addresses M + word_index
            X_STREAM: begin
                if (x_word_idx < M) begin
                    word_tmp[7:0]   = {1'b0, x_buf[x_word_idx*3 + 0]};
                    word_tmp[15:8]  = {1'b0, x_buf[x_word_idx*3 + 1]};
                    word_tmp[23:16] = {1'b0, x_buf[x_word_idx*3 + 2]};

                    waddr  <= M + x_word_idx;
                    dout2  <= word_tmp;
                    dout_v <= 1'b1;

                    x_word_idx <= x_word_idx + 1;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                done_sol <= 1'b1;
            end

            default: state <= IDLE;
            endcase
        end
    end

endmodule