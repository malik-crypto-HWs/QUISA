`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

/*=======================================
-- MAC Tile (fabric-only, no DSPs)
-- Parameterizable pipeline depth:
--   MAC_STAGES=1 : original (no extra regs)
--   MAC_STAGES=2 : register products (1 extra cycle)
--   MAC_STAGES=3 : + register sum-tree (2 extra cycles)
========================================*/
module MAC_TILE (
  input  wire        clk,
  input  wire        rst_au,
  input  wire        din_use,               // tap valid at MAC input
  input  wire        clr_acc,
  input  wire        release_out_bytes,
  input  wire [7:0]  a0,
  input  wire [7:0]  a1,
  input  wire [7:0]  a2,
  input  wire [7:0]  b0,
  input  wire [7:0]  b1,
  input  wire [7:0]  b2,
  output wire [23:0] mac_pack
);
  
  parameter integer MAC_STAGES = 2;
  localparam integer MAC_LAT = (MAC_STAGES<1) ? 0 :
                               (MAC_STAGES>3) ? 2 : (MAC_STAGES-1); // 0..2

  // 14-bit -> 7-bit fold for product (2^7 ? 1 mod 127)
  function automatic [6:0] fold127_14(input [13:0] p);
    reg [7:0] s;
  begin
    s = {1'd0, p[6:0]} + {1'd0, p[13:7]}; // 0..254
    if (s >= 8'd127) s = s - 8'd127;
    fold127_14 = s[6:0];
  end
  endfunction

  function automatic [6:0] add127_2(input [6:0] x, input [6:0] y);
    reg [7:0] s, t;
  begin
    s = {1'b0, x} + {1'b0, y};
    t = {1'b0, s[6:0]} + {7'd0, s[7]};
    add127_2 = (&t[6:0]) ? 7'd0 : t[6:0];
  end
  endfunction

  function automatic [6:0] add127_3(input [6:0] x, input [6:0] y, input [6:0] z);
    reg [8:0] s; reg [7:0] t;
  begin
    s = {2'b00,x} + {2'b00,y} + {2'b00,z};
    t = {1'b0, s[6:0]} + {1'b0, s[8:7]};
    t = {1'b0, t[6:0]} + {7'd0, t[7]};
    add127_3 = (&t[6:0]) ? 7'd0 : t[6:0];
  end
  endfunction

  function automatic [6:0] mul127_7;
    input [6:0] u, v;
    reg   [13:0] p;
  begin
    p = u * v;
    mul127_7 = fold127_14(p);
  end
  endfunction

  // -------------------------------
  // Stage 0: raw products
  // -------------------------------
  wire [6:0] p00_w = mul127_7(a0[6:0], b0[6:0]);
  wire [6:0] p01_w = mul127_7(a0[6:0], b1[6:0]);
  wire [6:0] p02_w = mul127_7(a0[6:0], b2[6:0]);
  wire [6:0] p10_w = mul127_7(a1[6:0], b0[6:0]);
  wire [6:0] p11_w = mul127_7(a1[6:0], b1[6:0]);
  wire [6:0] p12_w = mul127_7(a1[6:0], b2[6:0]);
  wire [6:0] p20_w = mul127_7(a2[6:0], b0[6:0]);
  wire [6:0] p21_w = mul127_7(a2[6:0], b1[6:0]);
  wire [6:0] p22_w = mul127_7(a2[6:0], b2[6:0]);

  // Optional Stage 1: register products
  reg [6:0] p00_r, p01_r, p02_r, p10_r, p11_r, p12_r, p20_r, p21_r, p22_r;
  wire      use_reg_p = (MAC_STAGES >= 2);
  always @(posedge clk) if (use_reg_p) begin
    p00_r <= p00_w; p01_r <= p01_w; p02_r <= p02_w;
    p10_r <= p10_w; p11_r <= p11_w; p12_r <= p12_w;
    p20_r <= p20_w; p21_r <= p21_w; p22_r <= p22_w;
  end
  wire [6:0] p00 = use_reg_p ? p00_r : p00_w;
  wire [6:0] p01 = use_reg_p ? p01_r : p01_w;
  wire [6:0] p02 = use_reg_p ? p02_r : p02_w;
  wire [6:0] p10 = use_reg_p ? p10_r : p10_w;
  wire [6:0] p11 = use_reg_p ? p11_r : p11_w;
  wire [6:0] p12 = use_reg_p ? p12_r : p12_w;
  wire [6:0] p20 = use_reg_p ? p20_r : p20_w;
  wire [6:0] p21 = use_reg_p ? p21_r : p21_w;
  wire [6:0] p22 = use_reg_p ? p22_r : p22_w;

  // Sum tree
  wire [6:0] sT1_w = add127_2(p01, p10);
  wire [6:0] sT2_w = add127_3(p02, p11, p20);
  wire [6:0] sT3_w = add127_2(p12, p21);

  // Optional Stage 2: register sum tree
  reg [6:0] sT1_r, sT2_r, sT3_r, p00_r2, p22_r2;
  wire      use_reg_s = (MAC_STAGES >= 3);
  always @(posedge clk) if (use_reg_s) begin
    sT1_r <= sT1_w;
    sT2_r <= sT2_w;
    sT3_r <= sT3_w;
    p00_r2 <= p00;
    p22_r2 <= p22;
  end
  wire [6:0] sT1 = use_reg_s ? sT1_r : sT1_w;
  wire [6:0] sT2 = use_reg_s ? sT2_r : sT2_w;
  wire [6:0] sT3 = use_reg_s ? sT3_r : sT3_w;
  wire [6:0] p00f = use_reg_s ? p00_r2 : p00;
  wire [6:0] p22f = use_reg_s ? p22_r2 : p22;

  // Accumulator enable aligned to MAC latency
  reg [2:0] en_sr;
  wire      acc_en = (MAC_LAT==0) ? din_use : en_sr[MAC_LAT-1];
  always @(posedge clk) en_sr <= {en_sr[1:0], din_use};

  // 7-bit accumulators (mod 127)
  reg [6:0] acc_T0, acc_T1, acc_T2, acc_T3, acc_T4;
  wire [6:0] nxt_T0 = add127_2(acc_T0, p00f);
  wire [6:0] nxt_T1 = add127_2(acc_T1, sT1);
  wire [6:0] nxt_T2 = add127_2(acc_T2, sT2);
  wire [6:0] nxt_T3 = add127_2(acc_T3, sT3);
  wire [6:0] nxt_T4 = add127_2(acc_T4, p22f);

  always @(posedge clk) begin
    if (clr_acc) begin
      acc_T0 <= 7'd0; acc_T1 <= 7'd0; acc_T2 <= 7'd0; acc_T3 <= 7'd0; acc_T4 <= 7'd0;
    end else if (acc_en) begin
      acc_T0 <= nxt_T0;
      acc_T1 <= nxt_T1;
      acc_T2 <= nxt_T2;
      acc_T3 <= nxt_T3;
      acc_T4 <= nxt_T4;
    end
  end

  // Reduction & packing
  reg [7:0] T0_red, T1_red, T2_red;
  always @(posedge clk) begin
    if (rst_au) begin
      T0_red <= 8'd0; T1_red <= 8'd0; T2_red <= 8'd0;
    end else if (release_out_bytes) begin
      T0_red <= {1'b0, add127_2(acc_T0, acc_T3)};
      T1_red <= {1'b0, add127_3(acc_T1, acc_T3, acc_T4)};
      T2_red <= {1'b0, add127_2(acc_T2, acc_T4)};
    end
  end

  assign mac_pack = {T2_red, T1_red, T0_red};

endmodule
