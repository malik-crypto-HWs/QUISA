
`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

// =============================================
// mod_add_2k1.v  (Mersenne modulus: q = 2^K - 1)
// x,y in [0, q]; z = (x + y) mod q
// =============================================

module mod_add (
  input  wire is_KeyGen,
  input  wire is_Sign,
  input  wire is_Verify,
  input  wire [`OP-1:0] OP,
  input  wire [7:0]  a0,
  input  wire [7:0]  a1,
  input  wire [7:0]  a2,
  input  wire [7:0]  b0,
  input  wire [7:0]  b1,
  input  wire [7:0]  b2,
  output wire [23:0] add_out
);

  
  // 7-bit end-around-carry adder: (x+y) mod 127; canonicalize 127 -> 0
  function automatic [6:0] eac_add7;
      input [6:0] x, y;
      reg  [7:0] s;
      reg  [6:0] t;
  begin
    s = x + y;                 
    t = s[6:0] + s[7];         // fold carry; for modular reduction
    eac_add7 = (t == 7'd127) ? 7'd0 : t; // canonical residue 0..126
  end
  endfunction

  // Lane-wise (a - b) mod 127
  wire [6:0] z0 = eac_add7(a0, b0);
  wire [6:0] z1 = eac_add7(a1, b1);
  wire [6:0] z2 = eac_add7(a2, b2);

  // Pack bytes with MSB=0 per lane, order matches MAC packing
  assign add_out = (is_Sign && OP==`OP'd9) ? { {1'b0, z1}, {1'b0, z2}, {1'b0, z0} } : // z1 and z2 elements with replaced positions for EQN_GEN in SIGN
                   { {1'b0, z2}, {1'b0, z1}, {1'b0, z0} }; // default: elements producing in a sequence

endmodule
