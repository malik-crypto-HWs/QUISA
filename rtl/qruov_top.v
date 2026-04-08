`timescale 1ns / 1ps
`include"signal_sizes.vh"
//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////

module qruov_top (
    input  clk,
    input  rst,
    input  [1:0]           algo_select, // (KeyGen, Sign or Verify)
    input  [`INS-1:0]      ins,
    input  [`DWIDTH-1:0]   din_ext,       // 64 bit data input
    output [`DWIDTH-1:0]   dout_ext,   // 64 bit data output
    output [`TOD-1:0]      TOD,       // 0: IDLE, 1: done_load_input_data, 2: done_compute, 3: done_retrieve_output_data
    output                 sig_pf
);
    
    // Top-level input register for ins (one-cycle latency for all internal users)
    (* IOB = "TRUE", keep = "true" *) reg [`INS-1:0] ins_r;
    always @(posedge clk) begin
      ins_r <= ins;
    end
    
    (* IOB = "TRUE", keep = "true" *) reg [`DWIDTH-1:0] din_ext_r;
    always @(posedge clk) begin
      din_ext_r <= din_ext;
    end
    
    wire is_KeyGen  = algo_select == 2'd1;
    wire is_Sign    = algo_select == 2'd2;
    wire is_Verify  = algo_select == 2'd3;
    
    
    //========================================
    //-- Decoding instruction
    //========================================
    wire  [`TID-1:0]   TID = ins_r[1:0];            // 0: IDLE, 1: start_load_input_data, 2: start_compute, 3: start_retrieve_output_data
    wire  [`CDT-1:0]   CDT = ins_r[3:2];            // corresponding data: 0: load seed, 1: load public key, 2: load secret key
    wire  [`OP-1:0]    OP  = ins_r[8:4];            // 5-bit determines which operation is need to execute: 0: NOP, 1: inputs to shake128 with seed
    wire  [`ADDR-1:0]  raddr1_ext = ins_r[26:9];    // The largest public key bytes for security level V are 173,676. Therefore, we preferred 16-bit address for memories: 2^12 = 4096 and 4096 * 64 (bits on each address) = 262,144
    wire  [`ADDR-1:0]  raddr2_ext = ins_r[44:27];
    wire  [`ADDR-1:0]  waddr_ext = ins_r[62:45];    // The largest public key bytes for security level V are 173,676. Therefore, we preferred 16-bit address for memories: 2^12 = 4096 and 4096 * 64 (bits on each address) = 262,144
    wire  [`WE-1:0]    we_ext = ins_r[63:63];       // write enable signal
    wire  [`IV-1:0]    iv = ins_r[79:64];           // initialization vector (of 2 bytes or 16 bits)
    wire  [`RTYPE-1:0] rate_type = ins_r[81:80];    // rate_type => 0: SHA3-256, => 1: SHA3-512, => 2: SHAKE128, and => 3: SHAKE256
    
    
    parameter [3:0] SECAP = 4'd1;
    
    localparam [8:0] SecLevel = (SECAP == 4'd1) ? 9'd128 : // NIST SecLevel-1
                                (SECAP == 4'd5) ? 9'd192 : // NIST SecLevel-3
                                (SECAP == 4'd9) ? 9'd256 : // NIST SecLevel-5
                                3'd0;
    
    wire  [`MLEN-1:0]  mlen;      // input message length (in bytes)
    wire  [`OLEN-1:0]  olen;     // input message length (in bytes)
    wire  [`OLEN-1:0]  bytes_produced_after_rej;     // bytes that need to produce after rejection
    
    //========================================
    //-- signals for QR-UOV algorithm parameters
    //========================================
    wire [6:0]  q;
    wire [10:0] v;
    wire [7:0]  m;
    wire [3:0]  l;
    wire [10:0] n;           // message length
    wire [7:0]  N;           // total variables = v + o
    wire [7:0]  V;           // vinegar vars (same as v)
    wire [5:0]  M;           // number of equations (same as m)
    wire [16:0] tau1;        // tau_1
    wire [15:0] tau2;        // tau_2
    wire [8:0]  tau3;        // tau_3
    wire [7:0]  tau4;        // tau_3
    
    //========================================
    //-- signals for memory units
    //========================================
    
    // memory signals to load initial data 
    wire we_mem;
    wire [`ADDR-1:0] waddr_mem;
    wire [`DWIDTH-1:0] din_mem;
    wire [`ADDR-1:0] raddr_mem;
    wire [`DWIDTH-1:0] dout_mem;
    
    // memory signals to keep intermediate and final results
    wire wea_int_mem;
    wire [`ADDR-1:0] addra_int_mem;
    wire [`DATA-1:0] dina_int_mem;
    wire [`DATA-1:0] douta_int_mem;
    wire web_int_mem;
    wire [`ADDR-1:0] addrb_int_mem;
    wire [`DATA-1:0] dinb_int_mem;
    wire [`DATA-1:0] doutb_int_mem;
    
    // write enable signal(s) for mem2
    wire wea_int_mem_2;
    wire [`ADDR-1:0] addra_int_mem_2;
    wire [`DATA-1:0] dina_int_mem_2;
    wire [`DATA-1:0] douta_int_mem_2;
    wire web_int_mem_2;
    wire [`ADDR-1:0] addrb_int_mem_2;
    wire [`DATA-1:0] dinb_int_mem_2;
    wire [`DATA-1:0] doutb_int_mem_2;
    
    //========================================
    //-- signals for sha_shake_wrapper
    //========================================
    wire rst_sha_shake;
    wire en_sha_shake;
    wire shake_intermediate_rst;
    wire shake_next_extract;
    wire [`ADDR-1:0] raddr_shake;
    wire [`DWIDTH-1:0] din_shake;
    wire [`DWIDTH-1:0] dout_shake;
    wire [`ADDR-1:0] waddr_shake;
    wire dout_v_shake;
    wire done_shake;
    wire disable_iv_injection;
    
    //========================================
    //-- signals for rej_samp
    //========================================
    wire rst_rejsamp;
    wire en_rejsamp;
    wire [`DWIDTH-1:0] din_rejsamp;
    wire [8*168-1:0] dout_rejsamp;
    wire dout_v_rejsamp;
    wire done_rejsamp;
    
    //========================================
    //-- signals for expand
    //========================================
    wire rst_expand;
    wire en_expand;
    wire [8*168-1:0] din_expand;
    wire [`DATA-1:0] dout_expand_1, dout_expand_2;
    wire [`ADDR-1:0] waddr_expand;
    wire dout_v_expand;
    wire done_expand;
    wire [7:0] v_bytes_for_expand_wire;
    
    //========================================
    //-- signals for arithmetic unit
    //========================================
    wire rst_au;
    wire en_au;
    wire [`DATA-1:0] din1_au, din2_au, dout1_au, dout2_au;
    wire dout_v_au;
    wire [`ADDR-1:0] raddr1_au, raddr2_au, waddr_au;
    wire done_au;
    
    //========================================
    //-- signals for lu_decompose unit
    //========================================
    wire rst_lu;
    wire en_lu;
    wire [`DATA-1:0] din1_lu, din2_lu, dout1_lu, dout2_lu;
    wire dout_v_lu, swap_occuring;
    wire [`ADDR-1:0] raddr1_lu, raddr2_lu, waddr_lu;
    wire done_lu;
    // live outputs from LU
    wire [6:0]       rank_lu;
    wire [7*105-1:0] orig_row_id_bus;
    wire [7*105-1:0] index_map_bus;
    // registered copies held for sample_sol
    reg  [6:0]       rank_lu_reg;
    reg  [7*105-1:0] orig_row_id_bus_reg;
    reg  [7*105-1:0] index_map_bus_reg;
    
    //========================================
    //-- signals for ByteStream unit
    //========================================
    wire rst_byte_stream;
    wire en_byte_stream;
    wire [1:0] SL_byte_stream;
    wire [`DATA-1:0] din1_byte_stream, din2_byte_stream;
    wire [`DWIDTH-1:0] dout_byte_stream;
    wire [`ADDR-1:0] raddr1_byte_stream, raddr2_byte_stream;
    wire done_byte_stream;
    
    //========================================
    //-- signals for copy_words unit
    //========================================
    wire rst_copy_words;
    wire en_copy_words;
    //wire [6:0] t_in_words;
    wire [`DATA-1:0] din_copy_words, dout_copy_words;
    wire [`ADDR-1:0] raddr_copy_words, waddr_copy_words;
    wire dout_v_copy_words, done_copy_words;
    
    //========================================
    //-- signals for compare unit
    //========================================
    wire rst_compare;
    wire en_compare;
    wire [7:0] words_to_compare;
    wire [`DATA-1:0] din1_compare, din2_compare;
    wire [`ADDR-1:0] raddr1_compare, raddr2_compare;
    wire done_compare, pass_fail_compare;
        
    assign t_in_words = (SecLevel == 9'd128 && is_Sign    && OP==`OP'd17) ? 52 :  // this operates for the c_gen (and copies only the LSB byte)
						(SecLevel == 9'd192 && is_Sign    && OP==`OP'd17) ? 76 :  // this operates for the c_gen (and copies only the LSB byte)
						(SecLevel == 9'd256 && is_Sign    && OP==`OP'd17) ? 105 : // this operates for the c_gen (and copies only the LSB byte)
						((SecLevel == 9'd128 || SecLevel == 9'd192 || SecLevel == 9'd256) && is_Sign    && OP==`OP'd21) ? M :   // this copies the oil part of the signature from MEM_1 to MEM_2 to complete the generated signature (copies all three bytes)
						(SecLevel == 9'd128 && is_Sign    && OP==`OP'd22) ? 6 :   // this copies the salt (sig->r) into MEM_2 to form the signature (copying from 6 addresses - 16 bytes salt)
						(SecLevel == 9'd192 && is_Sign    && OP==`OP'd22) ? 8:   // this copies the salt (sig->r) into MEM_2 to form the signature (copying from 6 addresses - 16 bytes salt)
						(SecLevel == 9'd256 && is_Sign    && OP==`OP'd22) ? 11:   // this copies the salt (sig->r) into MEM_2 to form the signature (copying from 6 addresses - 16 bytes salt)
						((SecLevel == 9'd128 || SecLevel == 9'd192 || SecLevel == 9'd256) && is_Verify  && OP==`OP'd17) ? m :   // this copies the generated bytes to compare with msg_i in their correct order
						0;
    
//    assign t_in_words = (OP==`OP'd17) ? m : // this operates for the c_gen (and copies only the LSB byte)
//						(OP==`OP'd21) ? M : // this copies the oil part of the signature from MEM_1 to MEM_2 to complete the generated signature (copies all three bytes)
//						(SecLevel == 9'd128 && OP==`OP'd22) ? 6 : // this copies the salt (sig->r) into MEM_2 to form the signature (copying from 6 addresses - 16 bytes salt)
//						//(SecLevel == 9'd128 && is_Verify  && OP==`OP'd17) ? m : // this copies the generated bytes to compare with msg_i in their correct order
//						0;
    
    assign words_to_compare = (OP==`OP'd30) ? M : 0;
    //========================================
    //-- signals for sol unit
    //========================================
    wire rst_sol;
    wire en_sol;
    wire [`DATA-1:0] din1_sol, din2_sol, dout_sol; 
    wire [`ADDR-1:0] raddr1_sol, raddr2_sol, waddr_sol;
    wire dout_v_sol, done_sol;
    
    reg [1:0] counetr_seed;
    
    // internal control signals
    reg done_load_seed;
    
    always @(posedge clk) begin
        if (rst) begin
            rank_lu_reg         <= 7'd0;
            orig_row_id_bus_reg <= {(7*105){1'b0}};
            index_map_bus_reg   <= {(7*105){1'b0}};
        end
        else if (done_lu) begin
            rank_lu_reg         <= rank_lu;
            orig_row_id_bus_reg <= orig_row_id_bus;
            index_map_bus_reg   <= index_map_bus;
        end
    end
    
    assign bytes_produced_after_rej = (OP==`OP'd2 || OP==`OP'd4)  ? (v * m) / l : 
                                      (OP==`OP'd3)                ? l * (((v/l) * ((v/l)+1))/2) : 
                                      (OP==`OP'd10)               ? l * (v/l):
                                      (OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15)? olen :
                                      0;
    
    assign waddr_mem = (TID == `TID'd1 && CDT == `CDT'd0) ? waddr_ext :   // writing seed into memory 
                       waddr_mem;
                                
    assign raddr_mem = (en_sha_shake || en_rejsamp) ? raddr_shake + raddr1_ext :         // reading data from memory for sha_shake
                       raddr_mem;
    
    assign we_mem = (TID == `TID'd1 && CDT == `CDT'd0) ? we_ext :     // corresponding we signal when writing seed into memory
                    1'd0;
              
    assign din_mem = (TID == `TID'd1 && CDT == `CDT'd0) ? din_ext_r : // filling memories with initial data
                     din_mem;
   
    //==================================================
    //-- Interconnectionns for internal memory (INT_MEM)
    //==================================================
    // interconnections for first memory 
    assign wea_int_mem    = (TID == `TID'd1 && CDT == `CDT'd1) ? we_ext :     // writing sig-> r for verify
                            (OP==`OP'd2   && en_expand) ? dout_v_expand :
                            (OP==`OP'd3   && en_expand) ? dout_v_expand : 
                            (OP==`OP'd4   && en_expand) ? dout_v_expand : 
                            (OP==`OP'd5   && en_au)     ? dout_v_au     :
                            (is_KeyGen && OP==`OP'd7   && en_au)     ? dout_v_au     :
                            (is_Sign   && OP==`OP'd7   && en_au)     ? dout_v_au     :
                            (OP==`OP'd8   && en_au)     ? dout_v_au     :
                            (is_Sign      && OP==`OP'd9 && en_au)       ? dout_v_au     :
                            (OP==`OP'd10  && en_expand) ? dout_v_expand :
                            (OP==`OP'd11  && en_au)     ? dout_v_au     : // this computes the C_GEN for SIGN operation
                            (OP==`OP'd12  && en_lu)     ? dout_v_lu     : // this computes the LU_decompose for SIGN operation
                            (OP==`OP'd13  && en_expand) ? dout_v_expand : // this computes the Expand_mu for SIGN operation
                            ((OP==`OP'd14 || OP==`OP'd15)  && en_expand) ? dout_v_expand : // this computes the salt 
                            (is_Sign     && OP==`OP'd19   && en_au)     ? dout_v_au     : // implements VECTOR_M_dot_VECTOR_M
                            (is_Verify   && OP==`OP'd19   && en_au)     ? dout_v_au     : // implements VECTOR_M_dot_VECTOR_M
                            (is_Verify   && OP==`OP'd23   && en_au)     ? dout_v_au     : // implements VECTOR_V_dot_VECTOR_V
                            (OP==`OP'd24   && en_au)     ? dout_v_au     :
                            (OP==`OP'd25   && en_au)     ? dout_v_au     :                // implements VECTOR_M_dot_VECTOR_M with different addressing for verify            
                            (OP==`OP'd26   && en_au)     ? dout_v_au     :                // implements VECTOR_V_dot_VECTOR_V
                            (OP==`OP'd27   && en_au)     ? dout_v_au     :                // implements VECTOR_M_dot_VECTOR_M
                            ((is_Verify    && OP==`OP'd17)  && en_copy_words)     ? dout_v_copy_words     : 
                            1'd0;

    assign addra_int_mem  = (TID == `TID'd1 && CDT == `CDT'd1) ? waddr_ext :   // write address for sig-> r for verify 
                            ((OP==`OP'd2) && (en_expand && dout_v_expand) && (wea_int_mem))   ? waddr_expand  : 
                            ((OP==`OP'd3) && (en_expand && dout_v_expand) && (wea_int_mem))   ? waddr_expand + waddr_ext :
                            ((OP==`OP'd4) && (en_expand && dout_v_expand) && (wea_int_mem))   ? waddr_expand + waddr_ext : 
                            ((OP==`OP'd5) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext :
                            ((is_KeyGen && OP==`OP'd7) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext :
                            ((is_Sign   && OP==`OP'd7) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext :
                            ((OP==`OP'd8) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext :
                            (is_Sign && (OP==`OP'd9) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext :
                            ((OP==`OP'd10)&& (en_expand && dout_v_expand) && (wea_int_mem))   ? waddr_expand + waddr_ext :
                            ((OP==`OP'd11)&& (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext :
                            ((OP==`OP'd12)&& (en_lu     && dout_v_lu      && swap_occuring)   && (wea_int_mem))   ? (waddr_lu) + waddr_ext: 
                            ((OP==`OP'd12)&& (en_lu     && dout_v_lu)     && (wea_int_mem))   ? waddr_lu     + waddr_ext :
                            (OP==`OP'd12) ? raddr1_lu + raddr1_ext : 
                            ((OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) && (en_expand && dout_v_expand) && (wea_int_mem))   ? waddr_expand + waddr_ext :
                            (OP==`OP'd16) ? raddr1_byte_stream + raddr1_ext :
                            (((is_Sign && OP==`OP'd17) || OP==`OP'd21 || OP==`OP'd22)&& (en_copy_words))   ? raddr_copy_words     + raddr1_ext :
                            (OP==`OP'd18 && en_sol) ? raddr1_sol + raddr1_ext :
                            ((is_Sign   && OP==`OP'd19) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext : // implements VECTOR_M_dot_VECTOR_M
                            ((is_Verify && OP==`OP'd19) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext : // implements VECTOR_M_dot_VECTOR_M
                            ((is_Verify && OP==`OP'd23) && (en_au     && dout_v_au)     && (wea_int_mem))   ? waddr_au     + waddr_ext : // implements VECTOR_V_dot_VECTOR_V
                            (OP==`OP'd24 && (en_au      && dout_v_au) && (wea_int_mem))                     ? waddr_au     + waddr_ext :
                            (OP==`OP'd25 && (en_au      && dout_v_au) && (wea_int_mem))                     ? waddr_au     + waddr_ext : // implements VECTOR_M_dot_VECTOR_M with different addressing for verify
                            (OP==`OP'd26 && (en_au     && dout_v_au)  && (wea_int_mem))                     ? waddr_au     + waddr_ext : // implements VECTOR_V_dot_VECTOR_V
                            (OP==`OP'd27 && (en_au     && dout_v_au)  && (wea_int_mem))                     ? waddr_au     + waddr_ext : // implements VECTOR_M_dot_VECTOR_M
                            (OP==`OP'd28 && en_au)     ? raddr1_au     + raddr1_ext :
                            (((is_Verify && OP==`OP'd17))&& (en_copy_words        && dout_v_copy_words)     && (wea_int_mem))   ? waddr_copy_words + waddr_ext :
                            (OP==`OP'd30 && en_compare)     ? raddr1_compare + raddr1_ext :
                            raddr1_au + raddr1_ext;

    assign dina_int_mem   = (TID == `TID'd1 && CDT == `CDT'd1) ? din_ext_r :                // corresponding input bytes of sig->r for verify operation
                            ((OP==`OP'd2) && (en_expand && dout_v_expand)) ? dout_expand_1 : 
                            ((OP==`OP'd3) && (en_expand && dout_v_expand)) ? dout_expand_1 :
                            ((OP==`OP'd4) && (en_expand && dout_v_expand)) ? dout_expand_1 : 
                            ((OP==`OP'd5) && (en_au     && dout_v_au))     ? dout1_au : 
                            ((is_KeyGen && OP==`OP'd7) && (en_au     && dout_v_au))     ? dout1_au :
                            ((is_Sign   && OP==`OP'd7) && (en_au     && dout_v_au))     ? dout1_au : 
                            ((OP==`OP'd8) && (en_au     && dout_v_au))     ? dout1_au : 
                            (is_Sign && (OP==`OP'd9) && (en_au     && dout_v_au))     ? dout1_au : 
                            ((OP==`OP'd10)&& (en_expand && dout_v_expand)) ? dout_expand_1 :
                            ((OP==`OP'd11)&& (en_au     && dout_v_au))     ? dout1_au :
                            ((OP==`OP'd12)&& (en_lu     && dout_v_lu))     ? dout1_lu :
                            ((OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15)&& (en_expand && dout_v_expand)) ? dout_expand_1 :
                            ((is_Sign   && OP==`OP'd19) && (en_au     && dout_v_au))     ? dout1_au : // implements VECTOR_M_dot_VECTOR_M
                            ((is_Verify && OP==`OP'd19) && (en_au     && dout_v_au))     ? dout1_au : // implements VECTOR_M_dot_VECTOR_M
                            ((is_Verify && OP==`OP'd23) && (en_au     && dout_v_au))     ? dout1_au : // implements VECTOR_V_dot_VECTOR_V
                            (OP==`OP'd24 && (en_au     && dout_v_au))     ? dout1_au :
                            (OP==`OP'd25 && (en_au     && dout_v_au))     ? dout1_au :               // implements VECTOR_M_dot_VECTOR_M with different addressing for verify
                            (OP==`OP'd26 && (en_au     && dout_v_au))     ? dout1_au :               // implements VECTOR_V_dot_VECTOR_V
                            (OP==`OP'd27 && (en_au     && dout_v_au))     ? dout1_au :               // implements VECTOR_M_dot_VECTOR_M
                            (((is_Verify && OP==`OP'd17)) && (en_copy_words      && dout_v_copy_words))     ? dout_copy_words :
                            `DATA'd0;

    assign web_int_mem    = (OP==`OP'd2   && en_expand) ? dout_v_expand : 
                            (OP==`OP'd3   && en_expand) ? dout_v_expand : 
                            (OP==`OP'd4   && en_expand) ? dout_v_expand : 
                            (OP==`OP'd5   && en_au)     ? dout_v_au     : 
                            (OP==`OP'd8   && en_au)     ? dout_v_au     : 
                            (OP==`OP'd10  && en_expand) ? dout_v_expand :
                            (OP==`OP'd11   && en_au)     ? dout_v_au     :
                            (OP==`OP'd12   && en_lu && swap_occuring)    ? dout_v_lu     :
                            (OP==`OP'd13  && en_expand) ? dout_v_expand : // this computes the Expand_mu for SIGN operation
                            ((OP==`OP'd14 || OP==`OP'd15)  && en_expand) ? dout_v_expand : // this computes the salt
                            ((is_Sign && OP==`OP'd17)  && en_copy_words)     ? dout_v_copy_words     :  
                            (OP==`OP'd18 && en_sol) ? dout_v_sol : 
                            1'd0;

    assign addrb_int_mem  = ((OP==`OP'd2) && (en_expand && dout_v_expand) && (web_int_mem))   ? waddr_expand + 1  : 
                            ((OP==`OP'd3) && (en_expand && dout_v_expand) && (web_int_mem))   ? waddr_expand + waddr_ext + 1 : 
                            ((OP==`OP'd4) && (en_expand && dout_v_expand) && (web_int_mem))   ? waddr_expand + waddr_ext + 1 : 
                            ((OP==`OP'd5) && (en_au     && dout_v_au)     && (web_int_mem))   ? waddr_au     + waddr_ext + 1 :
                            ((is_KeyGen && OP==`OP'd7) && (en_au))   ? raddr2_au     + raddr2_ext :
                            ((is_Sign   && OP==`OP'd7) && (en_au))   ? raddr2_au     + raddr2_ext :
                            ((OP==`OP'd8) && (en_au     && dout_v_au)     && (web_int_mem))   ? waddr_au     + waddr_ext + 1 :
                            ((OP==`OP'd10)&& (en_expand && dout_v_expand) && (web_int_mem))   ? waddr_expand + waddr_ext + 1 :
                            ((OP==`OP'd11)&& (en_au     && dout_v_au)     && (web_int_mem))   ? waddr_au     + waddr_ext + 1 : 
                            ((OP==`OP'd12)&& (en_lu     && dout_v_lu      && swap_occuring)   && (web_int_mem))   ? (waddr_lu + M) + waddr_ext : 
                            ((OP==`OP'd12)&& (en_lu     && dout_v_lu)     && (web_int_mem))   ? waddr_lu + waddr_ext + 1 : 
                            (OP==`OP'd12) ? raddr2_lu + raddr2_ext : 
                            ((OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) && (en_expand && dout_v_expand) && (web_int_mem))   ? waddr_expand + waddr_ext + 1 :
                            (OP==`OP'd16) ? raddr2_byte_stream + raddr1_ext :
                            (((is_Sign && OP==`OP'd17))&& (en_copy_words        && dout_v_copy_words)     && (web_int_mem))   ? waddr_copy_words     + waddr_ext :
                            (OP==`OP'd18 && (en_sol && dout_v_sol))                 ? waddr_sol + waddr_ext :
                            (OP==`OP'd24 && (en_au  && dout_v_au) && (wea_int_mem)) ? raddr2_au  + raddr2_ext :
                            (OP==`OP'd25 && (en_au  && dout_v_au) && (wea_int_mem)) ? raddr2_au  + raddr2_ext : // implements VECTOR_M_dot_VECTOR_M with different addressing for verify
                            (OP==`OP'd28 && en_au)     ? raddr2_au     + raddr2_ext :
                            (OP==`OP'd30 && en_compare)     ? raddr2_compare + raddr2_ext :
                            raddr2_au + raddr2_ext;

    assign dinb_int_mem   = ((OP==`OP'd2) && (en_expand && dout_v_expand)) ? dout_expand_2 : 
                            ((OP==`OP'd3) && (en_expand && dout_v_expand)) ? dout_expand_2 : 
                            ((OP==`OP'd4) && (en_expand && dout_v_expand)) ? dout_expand_2 : 
                            ((OP==`OP'd5) && (en_au     && dout_v_au))     ? dout2_au :
                            ((OP==`OP'd8) && (en_au     && dout_v_au))     ? dout2_au :
                            ((OP==`OP'd10)&& (en_expand && dout_v_expand)) ? dout_expand_2 :
                            ((OP==`OP'd11)&& (en_au     && dout_v_au))     ? dout2_au : 
                            ((OP==`OP'd12)&& (en_lu     && dout_v_lu))     ? dout2_lu : 
                            ((OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15)&& (en_expand && dout_v_expand)) ? dout_expand_2 :
                            (((is_Sign && OP==`OP'd17)) && (en_copy_words      && dout_v_copy_words))     ? dout_copy_words :
                            (OP==`OP'd18 && (en_sol && dout_v_sol)) ? dout_sol :
                            `DATA'd0;
   
    // interconnections for second memory 
    assign wea_int_mem_2    = ((OP==`OP'd6 || OP==`OP'd20)   && en_au)  ? dout_v_au         : // Executing subtract 'd6 for M and 'd20 for V
                             ((OP==`OP'd21 || OP==`OP'd22)   && en_copy_words)           ? dout_v_copy_words :
                             (is_KeyGen    && OP==`OP'd9   && en_au)     ? dout_v_au     :
                             (is_Verify    && OP==`OP'd9   && en_au)     ? dout_v_au     :
                             (OP==`OP'd28  && en_au)       ? dout_v_au     :
                             1'd0;

    assign addra_int_mem_2  = ((OP==`OP'd6 || OP==`OP'd20) && (en_au && dout_v_au) && (wea_int_mem_2))   ? waddr_au         + waddr_ext :
                              (is_KeyGen    && (OP==`OP'd7) && (en_au))   ? raddr1_au     + raddr1_ext  :
                              ((OP==`OP'd21 || OP==`OP'd22) && (en_copy_words && dout_v_copy_words) && wea_int_mem_2)     ? waddr_copy_words + waddr_ext :
                              (is_KeyGen    && (OP==`OP'd9) && (en_au     && dout_v_au)     && (wea_int_mem_2))   ? waddr_au     + waddr_ext  :
                              (is_Verify    && (OP==`OP'd9) && (en_au     && dout_v_au)     && (wea_int_mem_2))   ? waddr_au     + waddr_ext  :
                              (OP==`OP'd18 && en_sol) ? raddr2_sol + raddr2_ext :
                              (OP==`OP'd24  && (en_au))   ? raddr1_au     + raddr1_ext  :
                              (OP==`OP'd25  && (en_au))   ? raddr1_au     + raddr1_ext  :
                              (OP==`OP'd28  && (en_au     && dout_v_au)   && (wea_int_mem_2))   ? waddr_au     + waddr_ext  :
                              ((is_Verify   && OP==`OP'd17) && (en_copy_words))   ? raddr_copy_words     + raddr1_ext :
                              raddr1_au + raddr1_ext;

    assign dina_int_mem_2   = ((OP==`OP'd6 || OP==`OP'd20)      && (en_au && dout_v_au))  ? dout1_au : 
                              ((OP==`OP'd21 || OP==`OP'd22) && (en_copy_words    && dout_v_copy_words))    ? dout_copy_words : 
                              (is_KeyGen    && (OP==`OP'd9) && (en_au     && dout_v_au))     ? dout1_au :
                              (is_Verify    && (OP==`OP'd9) && (en_au     && dout_v_au))     ? dout1_au :
                              ((OP==`OP'd28)&& (en_au       && dout_v_au))                   ? dout1_au :
                              `DATA'd0;

    assign web_int_mem_2    = (is_KeyGen    && OP==`OP'd9   && en_au)     ? dout_v_au     : 
                              (is_Verify    && OP==`OP'd9   && en_au)     ? dout_v_au     :
                              1'd0;

    assign addrb_int_mem_2  = (is_KeyGen    && (OP==`OP'd9) && (en_au     && dout_v_au)     && (web_int_mem_2))  ? waddr_au     + waddr_ext  :
                              (is_Verify    && (OP==`OP'd9) && (en_au     && dout_v_au)     && (web_int_mem_2))  ? waddr_au     + waddr_ext  :
                              raddr2_au + raddr2_ext;

    assign dinb_int_mem_2   = (is_KeyGen    && (OP==`OP'd9) && (en_au     && dout_v_au))     ? dout1_au : 
                              (is_Verify    && (OP==`OP'd9) && (en_au     && dout_v_au))     ? dout1_au :
                              `DATA'd0;
   
    // providing the inputs to the building-blocks
    assign din_shake     = (OP==`OP'd1 || OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14) ? dout_mem : 
                           (OP==`OP'd15) ? dout_byte_stream:
                           din_shake;

    assign din_rejsamp   = (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? dout_shake             : din_rejsamp;
    assign din_expand    = (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? dout_rejsamp           : din_expand;

    assign din1_au       = (OP==`OP'd5 || OP==`OP'd6 || (is_Sign && OP==`OP'd17) || OP==`OP'd20) ? douta_int_mem          : 
                           (is_KeyGen && OP==`OP'd7)                ? douta_int_mem_2        : 
                           (is_Sign   && OP==`OP'd7)                ? douta_int_mem          :
                           (OP==`OP'd11)                            ? douta_int_mem          : 
                           (OP==`OP'd8)                             ? douta_int_mem          :
                           ((is_KeyGen || is_Verify) && OP==`OP'd9) ? douta_int_mem          :  
                           (is_Sign   && OP==`OP'd9)                ? douta_int_mem_2        : 
                           (is_Sign   && OP==`OP'd19)               ? douta_int_mem          :
                           (is_Verify && OP==`OP'd19)               ? douta_int_mem          :
                           (is_Verify && OP==`OP'd23)               ? douta_int_mem          :
                           (OP==`OP'd24)                            ? douta_int_mem_2        :
                           (OP==`OP'd25)                            ? douta_int_mem_2        :
                           (OP==`OP'd26)                            ? douta_int_mem          :
                           (OP==`OP'd27)                            ? douta_int_mem          :
                           (OP==`OP'd28)                            ? douta_int_mem          :
                           {`DATA{1'b0}};

    assign din2_au       = (OP==`OP'd5 || OP==`OP'd6 || (is_KeyGen && OP==`OP'd9) || (is_Sign && OP==`OP'd17) || OP==`OP'd20) ? doutb_int_mem          : 
                           (is_KeyGen && OP==`OP'd7)                ? doutb_int_mem          : 
                           (is_Sign   && OP==`OP'd7)                ? doutb_int_mem          :
                           (OP==`OP'd11)                            ? doutb_int_mem          : 
                           (OP==`OP'd8)                             ? doutb_int_mem          :
                           ((is_KeyGen || is_Verify) && OP==`OP'd9) ? doutb_int_mem          :  
                           (is_Sign   && OP==`OP'd9)                ? doutb_int_mem_2        : 
                           (is_Sign   && OP==`OP'd19)               ? doutb_int_mem          :
                           (is_Verify && OP==`OP'd19)               ? doutb_int_mem          :
                           (is_Verify && OP==`OP'd23)               ? doutb_int_mem          :
                           (OP==`OP'd24)                            ? doutb_int_mem          :
                           (OP==`OP'd25)                            ? doutb_int_mem          :
                           (OP==`OP'd26)                            ? doutb_int_mem          :
                           (OP==`OP'd27)                            ? doutb_int_mem          :
                           (OP==`OP'd28)                            ? doutb_int_mem          :
                           {`DATA{1'b0}};

    assign din1_lu       = (OP==`OP'd12) ? douta_int_mem :   {`DATA{1'b0}};
    assign din2_lu       = (OP==`OP'd12) ? doutb_int_mem :   {`DATA{1'b0}};
   
    assign din1_byte_stream = (OP==`OP'd16) ? douta_int_mem :   {`DATA{1'b0}} ;
    assign din2_byte_stream = (OP==`OP'd16) ? doutb_int_mem :   {`DATA{1'b0}} ;
    assign SL_byte_stream   = (SecLevel == 9'd128) ? 2'd1 :
                              (SecLevel == 9'd192) ? 2'd2 :
                              (SecLevel == 9'd256) ? 2'd3 :
                              2'd0;
   
    assign din_copy_words = ((is_Sign   && OP==`OP'd17) || OP==`OP'd21 || OP==`OP'd22) ? douta_int_mem : 
                            ((is_Verify && OP==`OP'd17)) ? douta_int_mem_2 :
                            {`DATA{1'b0}};
   
    assign din1_sol = (OP == `OP'd18) ? douta_int_mem   : {`DATA{1'b0}};     // EQN via port A
    assign din2_sol = (OP == `OP'd18) ? douta_int_mem_2 : {`DATA{1'b0}};   // b/row_id via port B
    
    assign din1_compare = (OP==`OP'd30) ? douta_int_mem : {`DATA{1'b0}};
    assign din2_compare = (OP==`OP'd30) ? doutb_int_mem : {`DATA{1'b0}};
    
    assign sig_pf = (is_Verify) ? pass_fail_compare : 1'b0;
   
    // setting corresponding enable signals
    assign en_sha_shake          = (OP==`OP'd1 || OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? 1'd1 : 1'd0;
    assign en_rejsamp            = (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? 1'd1 : 1'd0;
    assign en_expand             = (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? 1'd1 : 1'd0;
    assign en_au                 = (OP==`OP'd5 || OP==`OP'd6 || OP==`OP'd7 || OP==`OP'd8 || OP==`OP'd9 || OP==`OP'd11 || OP==`OP'd12 || OP==`OP'd19 || OP==`OP'd20 || OP==`OP'd23 || OP==`OP'd24 || OP==`OP'd25 || OP==`OP'd26 || OP==`OP'd27 || OP==`OP'd28) ? 1'd1 : 1'd0;
    assign en_lu                 = (OP==`OP'd12) ? 1'd1 : 1'd0;
    assign en_byte_stream        = (OP==`OP'd15 || OP==`OP'd16) ? 1'd1 : 1'd0;
    assign en_copy_words         = (OP==`OP'd17 || OP==`OP'd21 || OP==`OP'd22) ? 1'd1 : 1'd0;
    assign en_sol                = (OP == `OP'd18) ? 1'd1 : 1'd0;
    assign en_compare            = (OP == `OP'd30) ? 1'd1 : 1'd0;
   
    // setting corresponding rst signals
    assign rst_sha_shake         = (en_sha_shake)        ? 1'd0 : 1'd1;
    assign rst_rejsamp           = (en_rejsamp)          ? 1'd0 : 1'd1;
    assign rst_expand            = (en_expand)           ? 1'd0 : 1'd1;
    assign rst_au                = (en_au)               ? 1'd0 : 1'd1;
    assign rst_lu                = (en_lu)               ? 1'd0 : 1'd1;
    assign rst_byte_stream       = (en_byte_stream)      ? 1'd0 : 1'd1;
    assign rst_copy_words        = (en_copy_words)       ? 1'd0 : 1'd1;
    assign rst_sol               = (en_sol)              ? 1'd0 : 1'd1;
    assign rst_compare           = (en_compare)          ? 1'd0 : 1'd1;
   
    (* IOB = "TRUE" *) reg TOD_r;
    // setting the done signal as output
    wire TOD_ext = (OP==`OP'd1) ? done_shake : 
                   (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10 || OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? done_shake && done_rejsamp && done_expand : 
                   (OP==`OP'd5 || OP==`OP'd6 || OP==`OP'd7 || OP==`OP'd8 || OP==`OP'd9 || OP==`OP'd11 || OP==`OP'd19 || OP==`OP'd20 || OP==`OP'd23 || OP==`OP'd24 || OP==`OP'd25 || OP==`OP'd26 || OP==`OP'd27 || OP==`OP'd28) ? done_au : 
                   (OP==`OP'd12) ? done_lu :  
                   (OP==`OP'd16) ? done_byte_stream :
                   (OP==`OP'd17 || OP==`OP'd21 || OP==`OP'd22) ? done_copy_words :  
                   (OP==`OP'd18) ? done_sol :
                   (OP==`OP'd30) ? done_compare :
                   `TOD'd0; 

    always @(posedge clk) begin
       TOD_r <= TOD_ext;
    end
    assign TOD = TOD_r;
   
    assign olen = ((en_sha_shake && OP==`OP'd2) || (en_sha_shake && OP==`OP'd4)) ? {16'b0, tau2[15:0]} : 
                  (en_sha_shake && OP==`OP'd3)  ? {15'b0, tau1[16:0]} :
                  (en_sha_shake && OP==`OP'd10) ? {23'b0, tau3[8:0]} : 
                  ((SecLevel == 9'd128 || SecLevel == 9'd192 || SecLevel == 9'd256) && en_sha_shake && OP==`OP'd13) ? 64 :
                  (SecLevel == 9'd128 && en_sha_shake && OP==`OP'd14) ? 16 :
                  (SecLevel == 9'd192 && en_sha_shake && OP==`OP'd14) ? 24 :
                  (SecLevel == 9'd256 && en_sha_shake && OP==`OP'd14) ? 32 :
                  (SecLevel == 9'd128 && en_sha_shake && OP==`OP'd15) ? 54 : // selecting tau_4
                  (SecLevel == 9'd192 && en_sha_shake && OP==`OP'd15) ? 78 : // selecting tau_4
                  (SecLevel == 9'd256 && en_sha_shake && OP==`OP'd15) ? 105 : // selecting tau_4
                  32'b0;

    assign mlen = ((SecLevel == 9'd128 && en_sha_shake) && (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10)) ? {16'd0, 16'd16} : 
                  ((SecLevel == 9'd192 && en_sha_shake) && (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10)) ? {16'd0, 16'd24} :
                  ((SecLevel == 9'd256 && en_sha_shake) && (OP==`OP'd2 || OP==`OP'd3 || OP==`OP'd4 || OP==`OP'd10)) ? {16'd0, 16'd32} :
                  (SecLevel  == 9'd128 && en_sha_shake  && OP==`OP'd13) ? 49 : // (33 bytes for message + 16 bytes for public key)
                  (SecLevel  == 9'd192 && en_sha_shake  && OP==`OP'd13) ? 57 : // (33 bytes for message + 24 bytes for public key)
                  (SecLevel  == 9'd256 && en_sha_shake  && OP==`OP'd13) ? 65 : // (33 bytes for message + 32 bytes for public key)
                  (SecLevel  == 9'd128 && en_sha_shake  && OP==`OP'd14) ? 16 :
                  (SecLevel  == 9'd192 && en_sha_shake  && OP==`OP'd14) ? 24 :
                  (SecLevel  == 9'd256 && en_sha_shake  && OP==`OP'd14) ? 32 :
                  (SecLevel  == 9'd128 && en_sha_shake  && OP==`OP'd15) ? 80 : // sum of bytes of message (mu = 64) and salt (sig-> r = 16) 
                  (SecLevel  == 9'd192 && en_sha_shake  && OP==`OP'd15) ? 88 : // sum of bytes of message (mu = 64) and salt (sig-> r = 24) 
                  (SecLevel  == 9'd256 && en_sha_shake  && OP==`OP'd15) ? 96 : // sum of bytes of message (mu = 64) and salt (sig-> r = 96) 
                  0; 
   
    assign disable_iv_injection = (OP==`OP'd13 || OP==`OP'd14 || OP==`OP'd15) ? 1 : 0;
   
    // set external_dout
    (* IOB = "TRUE" *) reg [`DATA-1:0] dout_ext_r;
    wire use_ext = (OP==`OP'd2) || (OP==`OP'd3) || (OP==`OP'd4) || (OP==`OP'd5);
    always @(posedge clk) begin
       dout_ext_r <= use_ext ? douta_int_mem : {`DATA{1'b0}};
    end
    assign dout_ext = dout_ext_r;

    //========================================
    //-- making olen divisble by 64
    //========================================
    wire [5:0] olen_remainder = olen[5:0];
    wire [`OLEN-1:0] olen_div_by_64 = (olen_remainder == 0) ? olen : 
                                      (OP==`OP'd14) ? olen : 
                                      olen + (7'd64 - olen_remainder);
    
    always @ (posedge clk) begin
        if(rst) begin
            counetr_seed <= 2'd0;
        end else if (TID == 2'd1 && CDT == 2'd0) begin
            if(counetr_seed == 2'd1) begin
                counetr_seed <= 2'd0;
                done_load_seed <= 1;
            end else
                counetr_seed <= counetr_seed+1;
        end
    end
    
    //========================================
    //-- FSM
    //========================================
    reg [2:0] CS, NS;
    reg set_msg_op_lengths_for_sha_shake;
    
    always @ (posedge clk) begin
        if(rst) 
            CS <= 0;
        else
            CS <= NS;
    end
    
    always @ (*) begin
        set_msg_op_lengths_for_sha_shake = 0;
        case (CS)
            3'd0: begin 
                if ((en_sha_shake && done_shake) || rst_sha_shake) 
                    NS = 3'd0; 
                else if(en_sha_shake)
                    NS = 3'd1;
                else
                    NS = 3'd0;
            end
            
            3'd1: begin
                set_msg_op_lengths_for_sha_shake = 1;
                NS = 3'd2;
            end
            
            3'd2: begin
                if (done_shake)
                    NS = 3'd0;
                else
                    NS = 3'd2;
            end
            
            default: NS = 3'd0;
        endcase
    end
    
    //==================================
    // Algorithm Parameters Selection
    // based on SECAP signal 
    //==================================
    qruov_parameters qruov_parameters_uut (
       .SECAP(SECAP),
       .q(q),
       .v(v),
       .m(m),
       .l(l),
       .n(n),
       .N(N),
       .V(V),
       .M(M),
       .tau1(tau1),
       .tau2(tau2),
       .tau3(tau3),
       .tau4(tau4) 
    );
    
    //==================================
    // simple dual-port memory
    // to kept 256 bit seed 
    //==================================
    
    MEM_1 MEM_1 (
      .clka(clk),
      .wea(wea_int_mem),
      .addra(addra_int_mem[15:0]),
      .dina(dina_int_mem),
      .douta(douta_int_mem),
      .clkb(clk),
      .web(web_int_mem),
      .addrb(addrb_int_mem[15:0]),
      .dinb(dinb_int_mem),
      .doutb(doutb_int_mem)
    );
    
    MEM_2 MEM_2 (
      .clka(clk),
      .wea(wea_int_mem_2),
      .addra(addra_int_mem_2),
      .dina(dina_int_mem_2),
      .douta(douta_int_mem_2),
      .clkb(clk),
      .web(web_int_mem_2),
      .addrb(addrb_int_mem_2),
      .dinb(dinb_int_mem_2),
      .doutb(doutb_int_mem_2)
    );
    
    /*
    MEM_3 MEM_3 (
      .clka(clk),        // write clock
      .wea(we_mem),     // write enable
      .addra(waddr_mem[`AWIDTH-1:0]),  // write address
      .dina(din_mem),    // write data
      .clkb(clk),        // read clock (same clock)
      .addrb(raddr_mem[`AWIDTH-1:0]),  // read address
      .doutb(dout_mem)    // read data
    );
    */
    
    
    MEMORY MEM_3 (
       .clk(clk),
       .wen(we_mem),
       .waddr(waddr_mem[`AWIDTH-1:0]),
       .din(din_mem),
       .raddr(raddr_mem[`AWIDTH-1:0]),
       .dout(dout_mem)
    );
    
    
    
    //==================================
    // sha-shake core 
    //==================================
    SHAKE_wrapper_malik sha_shake_wrapper_uut (
        .clk(clk),
        .rst(rst_sha_shake),
        .set_msg_op_lengths_for_sha_shake(set_msg_op_lengths_for_sha_shake),
        .shake_intermediate_rst(shake_intermediate_rst),
        .shake_next_extract(shake_next_extract),
        .rate_type(rate_type),
        .msg_length_bytes(mlen),
        .r_addr(raddr_shake),
        .din(din_shake),
        .op_length_bytes(olen_div_by_64),
        .dout(dout_shake),
        .w_addr(waddr_shake),
        .sample_dout_final(dout_v_shake),
        .done(done_shake),
        .iv_input(iv),
        .disable_iv_injection(disable_iv_injection)
    );
    
    //==================================
    // rejsamp unit 
    //==================================
    rejsamp rejsamp_uut (
        .clk(clk),
        .rst_rejsamp(rst_rejsamp),
        .en_rejsamp(en_rejsamp),
        .q(q),
        .SECAP(SECAP),
        .rate_type(rate_type),
        .OP(OP),
        .OLEN(olen),
        .din_v_rejsamp(dout_v_shake),
        .din_rejsamp(din_rejsamp),
        .dout_rejsamp(dout_rejsamp),
        .length_rejsamp(bytes_produced_after_rej),
        .v_bytes_for_expand(v_bytes_for_expand_wire),
        .dout_v_rejsamp(dout_v_rejsamp),
        .done_rejsamp(done_rejsamp)
    );
    
    //==================================
    // output format block 
    //==================================
    op_format_block_rejsamp op_block_uut (
        .clk(clk),
        .rst_expand(rst_expand),
        .en_expand(en_expand),
        .V(V),           // vinegar vars (same as v)
        .M(M),           // number of equations (same as m)
        .l(l),           // extension degree 
        .q(q),           // modulus q
        .OP(OP),
        .SECAP(SECAP),
        //.rate_type(rate_type),
        .din_v_expand(dout_v_rejsamp),
        .done_rejsamp_for_expand(done_rejsamp),
        .din_expand(din_expand),
        .length_rejsamp(bytes_produced_after_rej),
        .v_bytes_from_rejsamp(v_bytes_for_expand_wire), 
        .dout_expand_1(dout_expand_1),
        .dout_expand_2(dout_expand_2),
        .dout_v_expand(dout_v_expand),
        .waddr_expand(waddr_expand),
        .done_expand(done_expand)
    );
    
    //==================================
    // arithmetic unit 
    //==================================
    arithmetic_unit_gen au_uut(
        .clk(clk),
        .rst_au(rst_au),
        .en_au(en_au),
        .is_KeyGen(is_KeyGen),
        .is_Sign(is_Sign),
        .is_Verify(is_Verify),
        .m(m),
        .V(V),           // vinegar vars (same as v)
        .M(M),           // number of equations (same as m)
        .l(l),           // extension degree 
        .q(q),           // modulus q
        .OP(OP),
        .SECAP(SECAP),
        .din1(din1_au),
        .din2(din2_au),
        .dout1(dout1_au),
        .dout2(dout2_au),
        .dout_v_au(dout_v_au),
        .raddr1(raddr1_au),
        .raddr2(raddr2_au),
        .waddr(waddr_au),
        .done_au(done_au)
    );
    
    //==================================
    // LU_decompose unit 
    //==================================
    lu_decompose lu_decompose_uut (
        .clk(clk),
        .rst_lu(rst_lu),
        .en_lu(en_lu),
        .m(m),           // vinegar vars (same as v)
        .M(M),
        .l(l),           // extension degree 
        .q(q),           // modulus q
        .OP(OP),
        .din1(din1_lu),
        .din2(din2_lu),
        .dout1(dout1_lu),
        .dout2(dout2_lu),
        .dout_v_lu(dout_v_lu),
        .swap_occuring(swap_occuring),
        .raddr1(raddr1_lu),
        .raddr2(raddr2_lu),
        .waddr(waddr_lu),
        .done_lu(done_lu),
        // metadata outputs
        .rank_lu(rank_lu),
        .orig_row_id_bus(orig_row_id_bus),
        .index_map_bus(index_map_bus)
    );
    
    //==================================
    // ByteStream unit 
    //==================================
    ByteStream ByteStream_uut (
        .clk(clk),
        .rst_byte_stream(rst_byte_stream),
        .en_byte_stream(en_byte_stream),
        .OP(OP),
        .SL_byte_stream(SL_byte_stream),
        .din1_byte_stream(din1_byte_stream),
        .din2_byte_stream(din2_byte_stream),
        .raddr1_byte_stream(raddr1_byte_stream),
        .raddr2_byte_stream(raddr2_byte_stream),
        .dout_byte_stream(dout_byte_stream),
        .done_byte_stream(done_byte_stream)
    );
    
    //==================================
    // copy_words unit 
    //==================================
    copy_words copy_words_uut (
        .clk(clk),
        .rst_copy_words(rst_copy_words),
        .en_copy_words(en_copy_words),
        .t_in_words(M),
		.OP(OP),
        .din_copy_words(din_copy_words),
        .raddr_copy_words(raddr_copy_words),
        .waddr_copy_words(waddr_copy_words),
        .dout_copy_words(dout_copy_words),
        .dout_v_copy_words(dout_v_copy_words),
        .done_copy_words(done_copy_words)                
    );
    
    //==================================
    // sample_sol unit 
    //==================================
    sample_sol sample_sol_uut (
        .clk(clk),
        .rst_sol(rst_sol),
        .en_sol(en_sol),
        .m(m),           // vinegar vars (same as v)
        .M(M),
        .l(l),           // extension degree 
        .q(q),           // modulus q
        .OP(OP),
        .din1(din1_sol),
        .raddr1(raddr1_sol),
        .din2(din2_sol),
        .raddr2(raddr2_sol),
        .dout2(dout_sol),
        .waddr(waddr_sol),
        .dout_v(dout_v_sol),
        // metadata outputs
        .rank_meta(rank_lu_reg),
        .orig_row_id_bus(orig_row_id_bus_reg),
        .index_map_bus(index_map_bus_reg),
        //.rank(m[6:0]),
        .done_sol(done_sol)                
    );
    
    //==================================
    // compare unit 
    //==================================
    compare compare_uut (
        .clk(clk),
        .rst_compare(rst_compare), 
        .en_compare(en_compare),
        .words_to_compare(words_to_compare),
        .OP(OP),
        .raddr1_compare(raddr1_compare),
        .raddr2_compare(raddr2_compare),
        .din1_compare(din1_compare),
        .din2_compare(din2_compare),
        .done_compare(done_compare),
        .pass_fail_compare(pass_fail_compare)
    );
    
    
endmodule
