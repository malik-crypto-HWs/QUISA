`timescale 1ns / 1ps
`include "signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module rejsamp_and_q(
    input  wire [`DWIDTH-1:0] din,
	input [6:0] Q,
    output wire  [`DWIDTH-1:0] dout
);

    wire [7:0] b0 = din[7:0]   & Q;
    wire [7:0] b1 = din[15:8]  & Q;
    wire [7:0] b2 = din[23:16] & Q;
    wire [7:0] b3 = din[31:24] & Q;
    wire [7:0] b4 = din[39:32] & Q;
    wire [7:0] b5 = din[47:40] & Q;
    wire [7:0] b6 = din[55:48] & Q;
    wire [7:0] b7 = din[63:56] & Q;

    assign dout = {b7, b6, b5, b4, b3, b2, b1, b0};

endmodule
