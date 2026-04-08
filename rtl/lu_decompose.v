`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//
// LU decomposition controller - QR-UOV, GF(127)
//
//   rank_lu         : echelon rank
//   orig_row_id_bus : original row id for each echelon row
//   index_map_bus   : pivot column index for each echelon row
//
//////////////////////////////////////////////////////////////////////////////////

module lu_decompose (
    input  wire               clk,
    input  wire               rst_lu,
    input  wire               en_lu,
    input  wire [7:0]         m,           // elements per row
    input  wire [5:0]         M,           // 24-bit words per row
    input  wire [3:0]         l,           // bytes per word (=3)
    input  wire [6:0]         q,           // 127 (arithmetic below is fixed to 127)
    input  wire [`OP-1:0]     OP,
    input  wire [23:0]        din1,
    input  wire [23:0]        din2,
    output reg  [23:0]        dout1,
    output reg  [23:0]        dout2,
    output reg                dout_v_lu,
    output reg                swap_occuring,
    output reg  [`ADDR-1:0]   raddr1,
    output reg  [`ADDR-1:0]   raddr2,
    output reg  [`ADDR-1:0]   waddr,
    output reg                done_lu,
    // metadata outputs
    output reg  [6:0]         rank_lu,
    output reg  [7*105-1:0]   orig_row_id_bus,
    output reg  [7*105-1:0]   index_map_bus
);

    localparam integer MAX_M = 105;

    // -----------------------------------------------------------------------
    // FSM state encoding
    // -----------------------------------------------------------------------
    localparam [3:0]
        IDLE               = 4'd0,
        INIT               = 4'd1,
        FEED_IN            = 4'd2,
        ROW_WAIT1          = 4'd3,
        ROW_WAIT2          = 4'd4,
        PIVOT              = 4'd5,
        SWAP               = 4'd6,
        SCALE              = 4'd7,
        FEED_OUT_SCALE     = 4'd8,
        ELIMINATE          = 4'd9,
        FEED_OUT_ELIMINATE = 4'd10,
        DONE               = 4'd11;

    reg [3:0] state;

    // -----------------------------------------------------------------------
    // Algorithm indices
    // -----------------------------------------------------------------------
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] c;
    reg [7:0] k;

    // -----------------------------------------------------------------------
    // Control flags
    // -----------------------------------------------------------------------
    reg        load_pivot_row;
    reg        pivot_ready;
    reg [6:0]  mul_factor;

    // -----------------------------------------------------------------------
    // BRAM stream counters
    // -----------------------------------------------------------------------
    reg [6:0] req_i, cap_i;
    reg [6:0] req_j, cap_j;

    // -----------------------------------------------------------------------
    // Row buffers
    // -----------------------------------------------------------------------
    reg signed [7:0] row_i_buf [0:MAX_M-1];
    reg signed [7:0] row_j_buf [0:MAX_M-1];

    // -----------------------------------------------------------------------
    // Metadata registers
    // -----------------------------------------------------------------------
    reg [6:0] orig_row_id [0:MAX_M-1];
    reg [6:0] index_map   [0:MAX_M-1];
    reg [6:0] tmp_row_id;

    integer t;
    integer p;

    // -----------------------------------------------------------------------
    // Row base-address helper
    // -----------------------------------------------------------------------
    function [`ADDR-1:0] base_addr_row;
        input [7:0] row_idx;
        begin
            base_addr_row = row_idx * M;
        end
    endfunction

    // -----------------------------------------------------------------------
    // GF(127) inverse ROM
    // -----------------------------------------------------------------------
    reg [6:0] Fq_inv_table [0:126];
    initial begin
        Fq_inv_table[0]=0;   Fq_inv_table[1]=1;   Fq_inv_table[2]=64;
        Fq_inv_table[3]=85;  Fq_inv_table[4]=32;  Fq_inv_table[5]=51;
        Fq_inv_table[6]=106; Fq_inv_table[7]=109; Fq_inv_table[8]=16;
        Fq_inv_table[9]=113; Fq_inv_table[10]=89; Fq_inv_table[11]=104;
        Fq_inv_table[12]=53; Fq_inv_table[13]=88; Fq_inv_table[14]=118;
        Fq_inv_table[15]=17; Fq_inv_table[16]=8;  Fq_inv_table[17]=15;
        Fq_inv_table[18]=120;Fq_inv_table[19]=107;Fq_inv_table[20]=108;
        Fq_inv_table[21]=121;Fq_inv_table[22]=52; Fq_inv_table[23]=116;
        Fq_inv_table[24]=90; Fq_inv_table[25]=61; Fq_inv_table[26]=44;
        Fq_inv_table[27]=80; Fq_inv_table[28]=59; Fq_inv_table[29]=92;
        Fq_inv_table[30]=72; Fq_inv_table[31]=41; Fq_inv_table[32]=4;
        Fq_inv_table[33]=77; Fq_inv_table[34]=71; Fq_inv_table[35]=98;
        Fq_inv_table[36]=60; Fq_inv_table[37]=103;Fq_inv_table[38]=117;
        Fq_inv_table[39]=114;Fq_inv_table[40]=54; Fq_inv_table[41]=31;
        Fq_inv_table[42]=124;Fq_inv_table[43]=65; Fq_inv_table[44]=26;
        Fq_inv_table[45]=48; Fq_inv_table[46]=58; Fq_inv_table[47]=100;
        Fq_inv_table[48]=45; Fq_inv_table[49]=70; Fq_inv_table[50]=94;
        Fq_inv_table[51]=5;  Fq_inv_table[52]=22; Fq_inv_table[53]=12;
        Fq_inv_table[54]=40; Fq_inv_table[55]=97; Fq_inv_table[56]=93;
        Fq_inv_table[57]=78; Fq_inv_table[58]=46; Fq_inv_table[59]=28;
        Fq_inv_table[60]=36; Fq_inv_table[61]=25; Fq_inv_table[62]=84;
        Fq_inv_table[63]=125;Fq_inv_table[64]=2;  Fq_inv_table[65]=43;
        Fq_inv_table[66]=102;Fq_inv_table[67]=91; Fq_inv_table[68]=99;
        Fq_inv_table[69]=81; Fq_inv_table[70]=49; Fq_inv_table[71]=34;
        Fq_inv_table[72]=30; Fq_inv_table[73]=87; Fq_inv_table[74]=115;
        Fq_inv_table[75]=105;Fq_inv_table[76]=122;Fq_inv_table[77]=33;
        Fq_inv_table[78]=57; Fq_inv_table[79]=82; Fq_inv_table[80]=27;
        Fq_inv_table[81]=69; Fq_inv_table[82]=79; Fq_inv_table[83]=101;
        Fq_inv_table[84]=62; Fq_inv_table[85]=3;  Fq_inv_table[86]=96;
        Fq_inv_table[87]=73; Fq_inv_table[88]=13; Fq_inv_table[89]=10;
        Fq_inv_table[90]=24; Fq_inv_table[91]=67; Fq_inv_table[92]=29;
        Fq_inv_table[93]=56; Fq_inv_table[94]=50; Fq_inv_table[95]=123;
        Fq_inv_table[96]=86; Fq_inv_table[97]=55; Fq_inv_table[98]=35;
        Fq_inv_table[99]=68; Fq_inv_table[100]=47;Fq_inv_table[101]=83;
        Fq_inv_table[102]=66;Fq_inv_table[103]=37;Fq_inv_table[104]=11;
        Fq_inv_table[105]=75;Fq_inv_table[106]=6; Fq_inv_table[107]=19;
        Fq_inv_table[108]=20;Fq_inv_table[109]=7; Fq_inv_table[110]=112;
        Fq_inv_table[111]=119;Fq_inv_table[112]=110;Fq_inv_table[113]=9;
        Fq_inv_table[114]=39;Fq_inv_table[115]=74;Fq_inv_table[116]=23;
        Fq_inv_table[117]=38;Fq_inv_table[118]=14;Fq_inv_table[119]=111;
        Fq_inv_table[120]=18;Fq_inv_table[121]=21;Fq_inv_table[122]=76;
        Fq_inv_table[123]=95;Fq_inv_table[124]=42;Fq_inv_table[125]=63;
        Fq_inv_table[126]=126;
    end

    // -----------------------------------------------------------------------
    // GF(127) arithmetic
    // -----------------------------------------------------------------------
    function automatic [6:0] eac_add7;
        input [6:0] x, y;
        reg [7:0] s;
        reg [6:0] t1;
        begin
            s  = {1'b0, x} + {1'b0, y};
            t1 = s[6:0] + s[7];
            eac_add7 = (t1 == 7'd127) ? 7'd0 : t1;
        end
    endfunction

    function automatic [6:0] modsub7;
        input [6:0] x, y;
        begin
            modsub7 = eac_add7(x, ~y);
        end
    endfunction

    function automatic [6:0] fold127_14;
        input [13:0] p;
        reg [7:0] s;
        reg [6:0] t1;
        begin
            s  = {1'b0, p[6:0]} + {1'b0, p[13:7]};
            t1 = s[6:0] + s[7];
            fold127_14 = (t1 == 7'd127) ? 7'd0 : t1;
        end
    endfunction

    function automatic [6:0] modmul;
        input [6:0] a, b;
        begin
            modmul = fold127_14(a * b);
        end
    endfunction

    function automatic [6:0] modsub;
        input [6:0] a, b;
        begin
            modsub = modsub7(a, b);
        end
    endfunction

    wire [6:0] pivot_val_w     = row_i_buf[c][6:0];
    wire [6:0] inv_pivot_val_w = Fq_inv_table[pivot_val_w];

    // -----------------------------------------------------------------------
    // Pack metadata buses
    // -----------------------------------------------------------------------
    always @(*) begin
        for (p = 0; p < MAX_M; p = p + 1) begin
            orig_row_id_bus[p*7 +: 7] = orig_row_id[p];
            index_map_bus[p*7 +: 7]   = index_map[p];
        end
    end

    // -----------------------------------------------------------------------
    // Main FSM
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_lu) begin
            state          <= IDLE;
            done_lu        <= 1'b0;
            dout_v_lu      <= 1'b0;
            swap_occuring  <= 1'b0;
            dout1          <= 24'd0;
            dout2          <= 24'd0;
            raddr1         <= {`ADDR{1'b0}};
            raddr2         <= {`ADDR{1'b0}};
            waddr          <= {`ADDR{1'b0}};
            i              <= 8'd0;
            j              <= 8'd1;
            c              <= 8'd0;
            k              <= 8'd0;
            req_i          <= 7'd0;
            cap_i          <= 7'd0;
            req_j          <= 7'd0;
            cap_j          <= 7'd0;
            load_pivot_row <= 1'b1;
            pivot_ready    <= 1'b0;
            mul_factor     <= 7'd0;
            rank_lu        <= 7'd0;
            tmp_row_id     <= 7'd0;
            for (t = 0; t < MAX_M; t = t + 1) begin
                row_i_buf[t]   <= 8'd0;
                row_j_buf[t]   <= 8'd0;
                orig_row_id[t] <= t[6:0];
                index_map[t]   <= 7'd0;
            end
        end else begin
            dout_v_lu     <= 1'b0;
            swap_occuring <= 1'b0;

            case (state)

            IDLE: begin
                done_lu <= 1'b0;
                if (en_lu && (OP == `OP'd12)) begin
                    i              <= 8'd0;
                    c              <= 8'd0;
                    j              <= (m > 8'd1) ? 8'd1 : 8'd0;
                    k              <= 8'd0;
                    req_i          <= 7'd0;
                    cap_i          <= 7'd0;
                    req_j          <= 7'd0;
                    cap_j          <= 7'd0;
                    load_pivot_row <= 1'b1;
                    pivot_ready    <= 1'b0;
                    mul_factor     <= 7'd0;
                    waddr          <= {`ADDR{1'b0}};
                    rank_lu        <= 7'd0;
                    for (t = 0; t < MAX_M; t = t + 1) begin
                        orig_row_id[t] <= t[6:0];
                        index_map[t]   <= 7'd0;
                    end
                    state          <= INIT;
                end
            end

            INIT: begin
                if (load_pivot_row) begin
                    raddr1 <= base_addr_row(i);
                    req_i  <= 7'd1;
                    cap_i  <= 7'd0;
                    if (j < m) begin
                        raddr2 <= base_addr_row(j);
                        req_j  <= 7'd1;
                        cap_j  <= 7'd0;
                    end else begin
                        req_j <= M;
                        cap_j <= M;
                    end
                end else begin
                    req_i <= M;
                    cap_i <= M;
                    if (j < m) begin
                        raddr2 <= base_addr_row(j);
                        req_j  <= 7'd1;
                        cap_j  <= 7'd0;
                    end else begin
                        req_j <= M;
                        cap_j <= M;
                    end
                end
                state <= FEED_IN;
            end

            FEED_IN: begin
                if (load_pivot_row) begin
                    if (req_i < M) begin
                        raddr1 <= base_addr_row(i) + req_i;
                        req_i  <= req_i + 7'd1;
                    end
                end

                if (j < m) begin
                    if (req_j < M) begin
                        raddr2 <= base_addr_row(j) + req_j;
                        req_j  <= req_j + 7'd1;
                    end
                end

                if (load_pivot_row) begin
                    if ((req_i >= 7'd2) && (cap_i < (req_i - 7'd2))) begin
                        row_i_buf[cap_i*l]   <= din1[7:0];
                        row_i_buf[cap_i*l+1] <= din1[15:8];
                        row_i_buf[cap_i*l+2] <= din1[23:16];
                        cap_i <= cap_i + 7'd1;
                    end
                end

                if (j < m) begin
                    if ((req_j >= 7'd2) && (cap_j < (req_j - 7'd2))) begin
                        row_j_buf[cap_j*l]   <= din2[7:0];
                        row_j_buf[cap_j*l+1] <= din2[15:8];
                        row_j_buf[cap_j*l+2] <= din2[23:16];
                        cap_j <= cap_j + 7'd1;
                    end
                end

                if (((!load_pivot_row) || (req_i == M)) &&
                    ((j >= m)          || (req_j == M)))
                    state <= ROW_WAIT1;
            end

            ROW_WAIT1: begin
                if (load_pivot_row) begin
                    if (cap_i < M) begin
                        row_i_buf[cap_i*l]   <= din1[7:0];
                        row_i_buf[cap_i*l+1] <= din1[15:8];
                        row_i_buf[cap_i*l+2] <= din1[23:16];
                        cap_i <= cap_i + 7'd1;
                    end
                end
                if (j < m) begin
                    if (cap_j < M) begin
                        row_j_buf[cap_j*l]   <= din2[7:0];
                        row_j_buf[cap_j*l+1] <= din2[15:8];
                        row_j_buf[cap_j*l+2] <= din2[23:16];
                        cap_j <= cap_j + 7'd1;
                    end
                end
                state <= ROW_WAIT2;
            end

            ROW_WAIT2: begin
                if (load_pivot_row) begin
                    if (cap_i < M) begin
                        row_i_buf[cap_i*l]   <= din1[7:0];
                        row_i_buf[cap_i*l+1] <= din1[15:8];
                        row_i_buf[cap_i*l+2] <= din1[23:16];
                        cap_i <= cap_i + 7'd1;
                    end
                end
                if (j < m) begin
                    if (cap_j < M) begin
                        row_j_buf[cap_j*l]   <= din2[7:0];
                        row_j_buf[cap_j*l+1] <= din2[15:8];
                        row_j_buf[cap_j*l+2] <= din2[23:16];
                        cap_j <= cap_j + 7'd1;
                    end
                end
                state <= PIVOT;
            end

            PIVOT: begin
                if (!pivot_ready) begin
                    if (pivot_val_w != 7'd0) begin
                        index_map[i] <= c;
                        rank_lu      <= i + 1'b1;
                        k            <= c + 8'd1;
                        state        <= SCALE;

                    end else if ((j < m) && (row_j_buf[c] != 8'd0)) begin
                        k             <= 8'd1;
                        waddr         <= base_addr_row(i);
                        dout1         <= {row_j_buf[2], row_j_buf[1], row_j_buf[0]};
                        dout2         <= {row_i_buf[2], row_i_buf[1], row_i_buf[0]};
                        dout_v_lu     <= 1'b1;
                        swap_occuring <= 1'b1;
                        state         <= SWAP;

                    end else if ((j + 8'd1) < m) begin
                        j              <= j + 8'd1;
                        req_j          <= 7'd0;
                        cap_j          <= 7'd0;
                        load_pivot_row <= 1'b0;
                        state          <= INIT;

                    end else if ((c + 8'd1) < m) begin
                        c <= c + 8'd1;
                        if ((i + 8'd1) < m) begin
                            j              <= i + 8'd1;
                            req_j          <= 7'd0;
                            cap_j          <= 7'd0;
                            load_pivot_row <= 1'b0;
                            state          <= INIT;
                        end else begin
                            state <= PIVOT;
                        end

                    end else begin
                        state <= DONE;
                    end

                end else begin
                    if (j < m) begin
                        k     <= c;
                        state <= ELIMINATE;
                    end else begin
                        if (((i + 8'd1) < m) && ((c + 8'd1) < m)) begin
                            i              <= i + 8'd1;
                            c              <= i + 8'd1;
                            j              <= i + 8'd2;
                            req_i          <= 7'd0;
                            cap_i          <= 7'd0;
                            req_j          <= 7'd0;
                            cap_j          <= 7'd0;
                            load_pivot_row <= 1'b1;
                            pivot_ready    <= 1'b0;
                            state          <= INIT;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
            end

            SWAP: begin
                if (k < M) begin
                    dout1         <= {row_j_buf[(k*l)+2], row_j_buf[(k*l)+1], row_j_buf[k*l]};
                    dout2         <= {row_i_buf[(k*l)+2], row_i_buf[(k*l)+1], row_i_buf[k*l]};
                    dout_v_lu     <= 1'b1;
                    swap_occuring <= 1'b1;
                    waddr         <= waddr + 1'b1;
                    k             <= k + 8'd1;
                end else begin
                    // swap row-id metadata too
                    tmp_row_id    = orig_row_id[i];
                    orig_row_id[i] <= orig_row_id[j];
                    orig_row_id[j] <= tmp_row_id;

                    req_i          <= 7'd0;
                    cap_i          <= 7'd0;
                    req_j          <= 7'd0;
                    cap_j          <= 7'd0;
                    load_pivot_row <= 1'b1;
                    pivot_ready    <= 1'b0;
                    j              <= ((i + 8'd1) < m) ? (i + 8'd1) : i;
                    state          <= INIT;
                end
            end

            SCALE: begin
                if (k < m) begin
                    row_i_buf[k] <= modmul(row_i_buf[k][6:0], inv_pivot_val_w);
                    k            <= k + 8'd1;
                end else begin
                    row_i_buf[i] <= {1'b0, pivot_val_w};
                    k         <= 8'd0;
                    waddr     <= base_addr_row(i);
                    dout1     <= {row_i_buf[2], row_i_buf[1], row_i_buf[0]};
                    dout_v_lu <= 1'b1;
                    state     <= FEED_OUT_SCALE;
                end
            end

            FEED_OUT_SCALE: begin
                if (k < M) begin
                    dout_v_lu <= 1'b1;
                    dout1     <= {row_i_buf[(k*l)+2], row_i_buf[(k*l)+1], row_i_buf[k*l]};
                    if (k != 8'd0)
                        waddr <= waddr + 1'b1;
                    k <= k + 8'd1;
                end else begin
                    pivot_ready <= 1'b1;
                    if ((i + 8'd1) < m) begin
                        j              <= i + 8'd1;
                        req_j          <= 7'd0;
                        cap_j          <= 7'd0;
                        load_pivot_row <= 1'b0;
                        state          <= INIT;
                    end else begin
                        state <= DONE;
                    end
                end
            end

            ELIMINATE: begin
                if (k == c) begin
                    mul_factor   <= row_j_buf[c][6:0];
                    row_j_buf[i] <= {1'b0, row_j_buf[c][6:0]};
                    k            <= c + 8'd1;
                end else if (k < m) begin
                    row_j_buf[k] <= modsub(row_j_buf[k][6:0],
                                           modmul(mul_factor, row_i_buf[k][6:0]));
                    k <= k + 8'd1;
                end else begin
                    k         <= 8'd0;
                    waddr     <= base_addr_row(j);
                    dout1     <= {row_j_buf[2], row_j_buf[1], row_j_buf[0]};
                    dout_v_lu <= 1'b1;
                    state     <= FEED_OUT_ELIMINATE;
                end
            end

            FEED_OUT_ELIMINATE: begin
                if (k < M) begin
                    dout_v_lu <= 1'b1;
                    dout1     <= {row_j_buf[(k*l)+2], row_j_buf[(k*l)+1], row_j_buf[k*l]};
                    if (k != 8'd0)
                        waddr <= waddr + 1'b1;
                    k <= k + 8'd1;
                end else begin
                    if ((j + 8'd1) < m) begin
                        j              <= j + 8'd1;
                        req_j          <= 7'd0;
                        cap_j          <= 7'd0;
                        load_pivot_row <= 1'b0;
                        state          <= INIT;
                    end else begin
                        if (((i + 8'd1) < m) && ((c + 8'd1) < m)) begin
                            i              <= i + 8'd1;
                            c              <= i + 8'd1;
                            j              <= i + 8'd2;
                            req_i          <= 7'd0;
                            cap_i          <= 7'd0;
                            req_j          <= 7'd0;
                            cap_j          <= 7'd0;
                            load_pivot_row <= 1'b1;
                            pivot_ready    <= 1'b0;
                            state          <= INIT;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
            end

            DONE: begin
                done_lu <= 1'b1;
            end

            default: state <= IDLE;

            endcase
        end
    end

endmodule