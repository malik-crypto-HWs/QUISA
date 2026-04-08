`timescale 1ns / 1ps
`include"signal_sizes.vh"

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

// =============================================================
// Malik Imran (Note: "rate_type" signal configures different variants)
// rate_type => 0: SHA3-256 
// rate_type => 1: SHA3-512 
// rate_type => 2: SHAKE128 
// rate_type => 3: SHAKE256
// =============================================================

// =============================================================
// DOMAIN SEPARATORS (FIPS 202)
// =============================================================
// 0: SHA3-256       => domain = 0x06, rate = 17
// 1: SHA3-512       => domain = 0x06, rate = 9
// 2: SHAKE128       => domain = 0x1F, rate = 21
// 3: SHAKE256       => domain = 0x1F, rate = 17
// =============================================================
`define DOMAIN_SHA3       8'h06    // SHA3-256, SHA3-512
`define DOMAIN_SHAKE      8'h1F    // SHAKE128, SHAKE256

// =============================================================
// RATE CONSTANTS (in 64-bit words)
// =============================================================
`define RATE_SHA3_256     8'd17    // 136 bytes = 1088 bits / 8
`define RATE_SHA3_512     8'd9     // 72 bytes = 576 bits / 8
`define RATE_SHAKE128     8'd21    // 168 bytes = 1344 bits / 8
`define RATE_SHAKE256     8'd17    // 136 bytes = 1088 bits / 8

module SHAKE_wrapper_malik(
                        clk, 
                        rst, 
                        set_msg_op_lengths_for_sha_shake,
                        shake_intermediate_rst, 
                        shake_next_extract, 
                        rate_type, 
                        msg_length_bytes, 
                        r_addr, 
                        din,
                        op_length_bytes, 
                        dout, 
                        w_addr, 
                        sample_dout_final, 
                        done,
                        iv_input,
                        disable_iv_injection
                    );

input 			       clk, rst, set_msg_op_lengths_for_sha_shake;
input 			       shake_intermediate_rst, shake_next_extract; 
input [1:0] 	       rate_type;  // 0: SHA3-256, 1: SHA3-512, 2: SHAKE128, 3: SHAKE256
input [`MLEN-1:0] 	   msg_length_bytes;
output reg [`ADDR-1:0] r_addr;
input [`DWIDTH-1:0]    din;
input [`OLEN-1:0] 	   op_length_bytes;
output [`DWIDTH-1:0]   dout;
output reg [`ADDR-1:0] w_addr;
output 		           sample_dout_final;
output  	           done;
input [`IV-1:0]        iv_input; // NEW: External IV input (of size 2 Bytes)
input                  disable_iv_injection;

reg [`MLEN-1:0]   msg_length_bytes_reg, op_length_bytes_reg;
reg 		      dec_msg_length_bytes;
reg 		      continue_permutation;
reg 		      inc_r_addr;

reg [7:0] 	rate;
reg 		inc_rate;
reg [3:0] 	CS, NS;
wire 		done_wire; 
reg			domain_separator_used;

reg start, rst_keccak;
reg din_valid;
reg last_block;    

// Keccak core outputs
wire buffer_full, ready, dout_valid;
wire [63:0] dout;

reg [4:0] count_sample_dout;

// =============================================================
// Rate constant selection
// =============================================================
wire [7:0] rate_constant =  (rate_type==2'd0) ? `RATE_SHA3_256 : 
                            (rate_type==2'd1) ? `RATE_SHA3_512 : 
                            (rate_type==2'd2) ? `RATE_SHAKE128 : 
                            (rate_type==2'd3) ? `RATE_SHAKE256 :
                            `RATE_SHAKE256; // Default to SHAKE256 rate

// =============================================================
// Domain separator selection
// =============================================================
wire [7:0] domain_separator = (rate_type==2'd0) ? `DOMAIN_SHA3 : 
                              (rate_type==2'd1) ? `DOMAIN_SHA3 : 
                              (rate_type==2'd2) ? `DOMAIN_SHAKE : 
                              `DOMAIN_SHAKE;
	
// =============================================================
// Dealing with the message length
// =============================================================
always @(posedge clk)
begin
	if(rst)
		msg_length_bytes_reg <= 32'd0;
    else if (set_msg_op_lengths_for_sha_shake)
        msg_length_bytes_reg <= msg_length_bytes;
	else if(dec_msg_length_bytes)
		msg_length_bytes_reg <= msg_length_bytes_reg - 32'd8;
	else
		msg_length_bytes_reg <= msg_length_bytes_reg;
end		

// =============================================================
// Dealing with the required output length
// =============================================================
always @(posedge clk)
begin
	if(rst)
		op_length_bytes_reg <= 32'd0;
	else if(set_msg_op_lengths_for_sha_shake)
		op_length_bytes_reg <= op_length_bytes;
	else if(shake_intermediate_rst)
		op_length_bytes_reg <= op_length_bytes;
	else if(sample_dout_final)
		op_length_bytes_reg <= op_length_bytes_reg - 32'd8;
	else
		op_length_bytes_reg <= op_length_bytes_reg;
end

// =============================================================
// Setting intermediate signals for msg and requested output bytes
// =============================================================
wire msg_length_bytes_g8 = (msg_length_bytes_reg > 32'd7) ? 1'b1 : 1'b0;
wire msg_length_bytes_n0 = (msg_length_bytes_reg != 32'd0) ? 1'b1 : 1'b0;
wire op_length_bytes_is0 = (op_length_bytes_reg==32'd0) ? 1'b1 : 1'b0;

// =============================================================
// Regarding the SHA3 domain separator
// =============================================================
reg first_iv_byte_inserted, second_iv_byte_inserted;

always @(posedge clk)
begin
	if(rst)
		first_iv_byte_inserted <= 1'b0;
	else if(first_iv_byte_inserted==1'b0 && msg_length_bytes_g8==1'b0 && CS==4'd1)
		first_iv_byte_inserted <= 1'b1;
	else
		first_iv_byte_inserted <= first_iv_byte_inserted;
end

always @(posedge clk)
begin
	if(rst)
		second_iv_byte_inserted <= 1'b0;
	else if(second_iv_byte_inserted==1'b0 && msg_length_bytes_g8==1'b0 && CS==4'd1)
		second_iv_byte_inserted <= 1'b1;
	else
		second_iv_byte_inserted <= second_iv_byte_inserted;
end

always @(posedge clk)
begin
	if(rst)
		domain_separator_used <= 1'b0;
	else if(domain_separator_used==1'b0 && msg_length_bytes_g8==1'b0 && CS==4'd1)
		domain_separator_used <= 1'b1;
	else
		domain_separator_used <= domain_separator_used;
end

// =============================================================
// Monitoring the SHA3 rate for identifying the last input msg byte 
// =============================================================
wire rate_full = (rate==rate_constant) ? 1'b1 : 1'b0;

always @(posedge clk)
begin
	if(rst)
		rate <= 8'd1;
	else if(rate_full && inc_rate)
		rate <= 8'd0;
	else if(inc_rate)
		rate <= rate + 1'b1;
	else
		rate <= rate;
end

wire last_rate_byte = (msg_length_bytes_g8==1'b0 && rate_full==1'b1) ? 1'b1 : 1'b0;		

// =============================================================
// Preparing input msg bytes for QR-UOV specific 
// =============================================================

wire [7:0] din0_qruov_spec = 		(msg_length_bytes_g8) ? din[7:0] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd0) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd1) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd2) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd3) ? din[7:0] :	
                                    8'd0;					 
wire [7:0] din1_qruov_spec = 		(msg_length_bytes_g8) ? din[15:8] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd3) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd0) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd1) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd2) ? din[15:8] :	
                                    8'd0;
wire [7:0] din2_qruov_spec = 		(msg_length_bytes_g8) ? din[23:16] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd2) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd3) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd0) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd1) ? din[23:16] :	
                                    8'd0;
wire [7:0] din3_qruov_spec = 		(msg_length_bytes_g8) ? din[31:24] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd1) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd2) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd3) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd4) ? din[31:24] :	
                                    8'd0;
wire [7:0] din4_qruov_spec = 		(msg_length_bytes_g8) ? din[39:32] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd2) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd3) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd4) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd5) ? din[39:32] :	
                                    8'd0;						 
wire [7:0] din5_qruov_spec = 		(msg_length_bytes_g8) ? din[47:40] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd3) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd4) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd5) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd6) ? din[47:40] :	
                                    8'd0;						
wire [7:0] din6_qruov_spec = 		(msg_length_bytes_g8) ? din[55:48] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd4) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd5) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd6) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd7) ? din[55:48] :	
                                    8'd0;						 
wire [7:0] din7_temp_qruov_spec = 	(msg_length_bytes_g8) ? din[63:56] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd5) ? iv_input[15:8] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd6) ? iv_input[7:0] :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd7) ? domain_separator :
                                    8'd0;

wire [7:0] din7_qruov_spec = 		(last_rate_byte) ? {1'b1,din7_temp_qruov_spec[6:0]} : din7_temp_qruov_spec;

wire [63:0] dina_qruov_spec = {
                                din7_qruov_spec, 
                                din6_qruov_spec, 
                                din5_qruov_spec, 
                                din4_qruov_spec, 
                                din3_qruov_spec, 
                                din2_qruov_spec, 
                                din1_qruov_spec, 
                                din0_qruov_spec
                              };

// =============================================================
// Preparing input msg bytes for normal mode (FIPS compliant)
// =============================================================

wire [7:0] din0_norm_mode = 		(msg_length_bytes_g8) ? din[7:0] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd0) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd1) ? din[7:0] :	
                                    8'd0;					 
wire [7:0] din1_norm_mode = 		(msg_length_bytes_g8) ? din[15:8] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd1) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd2) ? din[15:8] :	
                                    8'd0;
wire [7:0] din2_norm_mode = 		(msg_length_bytes_g8) ? din[23:16] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd2) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd3) ? din[23:16] :	
                                    8'd0;
wire [7:0] din3_norm_mode = 		(msg_length_bytes_g8) ? din[31:24] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd3) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd4) ? din[31:24] :	
                                    8'd0;
wire [7:0] din4_norm_mode = 		(msg_length_bytes_g8) ? din[39:32] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd4) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd5) ? din[39:32] :	
                                    8'd0;						 
wire [7:0] din5_norm_mode = 		(msg_length_bytes_g8) ? din[47:40] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd5) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd6) ? din[47:40] :	
                                    8'd0;						
wire [7:0] din6_norm_mode = 		(msg_length_bytes_g8) ? din[55:48] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd6) ? domain_separator :
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]>=3'd7) ? din[55:48] :	
                                    8'd0;						 
wire [7:0] din7_temp_norm_mode =    (msg_length_bytes_g8) ? din[63:56] : 
                                    (domain_separator_used==1'b0 && msg_length_bytes_reg[2:0]==3'd7) ? domain_separator :
                                    8'd0;

wire [7:0] din7_norm_mode = 		(last_rate_byte) ? {1'b1,din7_temp_norm_mode[6:0]} : din7_temp_norm_mode;

wire [63:0] dina_norm_mode = {
                                din7_norm_mode, 
                                din6_norm_mode, 
                                din5_norm_mode, 
                                din4_norm_mode, 
                                din3_norm_mode, 
                                din2_norm_mode, 
                                din1_norm_mode, 
                                din0_norm_mode
                              };

// =============================================================
// Final input to drive the KECCAK core
// =============================================================
wire [63:0] dina = (disable_iv_injection) ? dina_norm_mode : dina_qruov_spec;

// =============================================================
// Generating read and write addresses for the memory 
// =============================================================

always @(posedge clk)
begin
	if(rst)
		r_addr <= 16'd0;
	else if(inc_r_addr)
		r_addr <= r_addr + 1'b1;
	else
		r_addr <= r_addr;
end		

always @(posedge clk)
begin
	if(rst)
		w_addr <= 16'd0;
	else if(sample_dout_final)
		w_addr <= w_addr + 1'b1;
	else
		w_addr <= w_addr;
end

// =============================================================
// CS and NS logic
// =============================================================

always @(posedge clk)
begin
	if(rst)
		CS <= 4'd0;
	else
		CS <= NS;
end

// =============================================================
// FSM (controller logic)
// =============================================================

always @(*)
begin
	case(CS)
	4'd0: 	begin
				start<=1'b1;
				rst_keccak<=0; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	 
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end

	4'd10: 	begin
				start<=1'b1; 
				rst_keccak<=0; 
				inc_r_addr<=1; 
				din_valid<=1'b0; 
				last_block<=1'b0;	 
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end
	4'd1: 	begin
				start<=1'b0; 
				rst_keccak<=1; 
				din_valid<=1'b1; 
				last_block<=1'b0;
				if(msg_length_bytes_g8==1'b0 || rate_full==1'b1) 
					dec_msg_length_bytes<=0; 
				else 
					dec_msg_length_bytes<=1; 
				if(rate_full) 
					inc_r_addr<=0;  
				else 
					inc_r_addr<=1;  				
				if(rate_full) 
					inc_rate<=0; 
				else 
					inc_rate<=1;
				continue_permutation<=0;
			end
	
	4'd2: 	begin
				start<=1'b0; 
				rst_keccak<=1;  
				din_valid<=1'b0; 
				last_block<=1'b0;    
				dec_msg_length_bytes<=0; 
				inc_r_addr<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end
	4'd13: begin
				start<=1'b0; 
				rst_keccak<=1;  
				din_valid<=1'b0; 
				last_block<=1'b0;    
				if(msg_length_bytes_g8==1'b0) 
					dec_msg_length_bytes<=0; 
				else 
					dec_msg_length_bytes<=1;
				if(msg_length_bytes_g8==1'b0) 
					inc_r_addr<=0; 
				else 
					inc_r_addr<=1;
				inc_rate<=1; 
				continue_permutation<=0;
			end
				
	4'd3: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b1;	
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end
	
	4'd6: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end
	4'd7: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end
			
	4'd8: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	 
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=1;
			end
	4'd9: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end		

	4'd14: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	 
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end	

	4'd15: begin
				start<=1'b0; 
				rst_keccak<=1; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	 
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end	
			
	default: begin
				start<=1'b1; 
				rst_keccak<=0; 
				inc_r_addr<=0; 
				din_valid<=1'b0; 
				last_block<=1'b0;	
				dec_msg_length_bytes<=0; 
				inc_rate<=0; 
				continue_permutation<=0;
			end	
			
	endcase
end


always @(*)
begin
	case(CS)
	4'd0: 	NS <= 4'd10;
	4'd10: 	NS <= 4'd1;
	4'd1: 	begin
				if(buffer_full)
					NS <= 4'd2;
				else
					NS <= 4'd1;
			end
	
	4'd2: 	begin
				if(last_rate_byte)
					NS <= 4'd3;
				else if(buffer_full)
					NS <= 4'd2;
				else
					NS <= 4'd13;
			end
	4'd13: 	NS <= 4'd1;
		
	4'd3: 	begin
				if(sample_dout)
					NS <= 4'd6;
				else	
					NS <= 4'd3;
			end
	4'd6:	begin
				if(sample_dout)
					NS <= 4'd6;
				else	
					NS <= 4'd7;
			end
	4'd7: 	begin
				if(op_length_bytes_is0)
					NS <= 4'd15;
				else
					NS <= 4'd8;
			end			
	4'd8: 	NS <= 4'd9;				
	4'd9: 	NS <= 4'd3;					

	4'd15: 	begin
				if(shake_intermediate_rst)
					NS <= 4'd14;
				else		
					NS <= 4'd15;
			end		
	4'd14: 	begin
				if(shake_next_extract)
					NS <= 4'd8;
				else		
					NS <= 4'd14;
			end			
	default: 	NS <= 4'd0;
	endcase
end

// =============================================================
// Logic for the final outputs
// =============================================================

assign sample_dout = dout_valid & ready & (!op_length_bytes_is0);
assign done = (CS==4'd15) ? 1'b1 : 1'b0;

// =============================================================
// Dealing with the sample_dout
// =============================================================
always @(posedge clk)
begin
	if(rst || !sample_dout)
		count_sample_dout <= 5'd0;
	else if(sample_dout)
		count_sample_dout <= count_sample_dout + 1;
end

assign sample_dout_final = (sample_dout && (count_sample_dout < rate_constant)) ? 1 : 0;

// =============================================================
// Module Instances
// =============================================================	
keccak uut	(
				clk, 
				rst_keccak, 
				start, 
				continue_permutation,
				rate_type,
				dina,
				din_valid,
				buffer_full,
				last_block,    
				ready,    
				dout,
				dout_valid
			);
			

endmodule