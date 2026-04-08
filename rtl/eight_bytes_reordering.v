`timescale 1ns / 1ps
`include "signal_sizes.vh"
`define RATE_SHAKE128       8'd21    // 168 bytes = 1344 bits / 8
`define RATE_SHAKE128_BYTES 8'd168    // 168 bytes
//`define RATE_SHAKE128_BYTES 8'd168    // 168 bytes

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module eight_bytes_reordering(
    input  wire [`DWIDTH-1:0] din,
	input [6:0] Q,
    output reg  [`DWIDTH-1:0] dout,   // First N valid bytes packed at LSBs
    output reg  [3:0]  valid_count,   // Total number of valid bytes
    output wire [7:0]  valid_flags    // Per-byte valid flag
);

    wire v0 = (din[7:0]   < {1'b0, Q});
    wire v1 = (din[15:8]  < {1'b0, Q});
    wire v2 = (din[23:16] < {1'b0, Q});
    wire v3 = (din[31:24] < {1'b0, Q});
    wire v4 = (din[39:32] < {1'b0, Q});
    wire v5 = (din[47:40] < {1'b0, Q});
    wire v6 = (din[55:48] < {1'b0, Q});
    wire v7 = (din[63:56] < {1'b0, Q});
    
    assign valid_flags = {v7, v6, v5, v4, v3, v2, v1, v0};

    reg [3:0] pos;  // current index for packing
    
    always @(*) begin
        dout = 64'd0;
        valid_count = 3'd0;
        pos = 4'd0;

        if (v0) begin
            dout[pos*8 +: 8] = din[7:0];
            pos = pos + 1;
        end
        if (v1) begin
            dout[pos*8 +: 8] = din[15:8];
            pos = pos + 1;
        end
        if (v2) begin
            dout[pos*8 +: 8] = din[23:16];
            pos = pos + 1;
        end
        if (v3) begin
            dout[pos*8 +: 8] = din[31:24];
            pos = pos + 1;
        end
        if (v4) begin
            dout[pos*8 +: 8] = din[39:32];
            pos = pos + 1;
        end
        if (v5) begin
            dout[pos*8 +: 8] = din[47:40];
            pos = pos + 1;
        end
        if (v6) begin
            dout[pos*8 +: 8] = din[55:48];
            pos = pos + 1;
        end
        if (v7) begin
            dout[pos*8 +: 8] = din[63:56];
            pos = pos + 1;
        end

        valid_count = pos;
    end

endmodule
