`timescale 1ns / 1ps
`include"signal_sizes.vh"
//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module MEMORY (
    input wire clk,
    input wire wen,
    input wire [`AWIDTH-1:0] waddr,
    input wire [`DWIDTH-1:0] din,
    input wire [`AWIDTH-1:0] raddr,
    output reg [`DWIDTH-1:0] dout
);

    // Memory declaration
    (* ram_style = "block" *)  // Optional: Suggest BRAM inference in Xilinx
    reg [`DWIDTH-1:0] mem [0:(1<<`AWIDTH)-1];

    // Write logic
    always @(posedge clk) begin
        if (wen)
            mem[waddr] <= din;
    end

    // Read logic
    always @(posedge clk) begin
        dout <= mem[raddr];
    end

endmodule

