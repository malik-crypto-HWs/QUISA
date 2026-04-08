
`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

// =============================================
// mod_sub_2k1.v  (Mersenne modulus: q = 2^K - 1)
// x,y in [0, q]; z = (x - y) mod q
// =============================================
// =============================================
// mod_sub.v
// Lane-wise (a2..a0) - (b2..b0) modulo 127
// Each byte is reduced like in MAC: 8b -> 7b residue via EAC,
// then (a - b) mod 127 = EAC_ADD(a, ~b).
// Output packs {1'b0, residue} per byte: {z2, z1, z0} -> 24 bits.
// =============================================
module mod_sub (
  input  wire [7:0]  a0,
  input  wire [7:0]  a1,
  input  wire [7:0]  a2,
  input  wire [7:0]  b0,
  input  wire [7:0]  b1,
  input  wire [7:0]  b2,
  output wire [23:0] sub_out
);

  
  // 7-bit end-around-carry adder: (x+y) mod 127; canonicalize 127 -> 0
  function automatic [6:0] eac_add7;
      input [6:0] x, y;
      reg  [7:0] s;
      reg  [6:0] t;
  begin
    s = x + y;                 // 0..254, s[7] is carry-out
    t = s[6:0] + s[7];         // fold carry; 0..127
    eac_add7 = (t == 7'd127) ? 7'd0 : t; // canonical residue 0..126
  end
  endfunction

  function automatic [6:0] eac_sub7;
  input [6:0] x, y;
  begin
    eac_sub7 = eac_add7(x, ~y);  // (~y) == (127 - y) for 7-bit y
  end
  endfunction

  // Lane-wise (a - b) mod 127
  wire [6:0] z0 = eac_sub7(a0, b0);
  wire [6:0] z1 = eac_sub7(a1, b1);
  wire [6:0] z2 = eac_sub7(a2, b2);

  // Pack bytes with MSB=0 per lane, order matches MAC packing
  assign sub_out = { {1'b0, z2}, {1'b0, z1}, {1'b0, z0} };

endmodule
