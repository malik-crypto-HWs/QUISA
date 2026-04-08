`timescale 1ns / 1ps
`include"signal_sizes.vh"

/*=======================================================================
--  The generated PUBLIC-KEY resides at addresses 5122--5445 and 5770--6093
=========================================================================*/

module TB_VERIFY_SL1;

    // Clock and reset
    reg clk = 0;
    reg rst;
    
    // select algorithm (KeyGen, Sign or Verify)
    reg  [1:0] algo_select;
    
    // Other Inputs to DUT
    reg  [`INS-1:0]    ins;
	reg  [`DWIDTH-1:0] din_ext;	   // 64 bit data input
	// Outputs from DUT
	wire [`DWIDTH-1:0] dout_ext;   // 64 bit data output
	wire [`TOD-1:0]    TOD;		   // 0: IDLE, 1: done_load_input_data, 2: done_compute, 3: done_retrieve_output_data  
	wire sig_pf;                   // A one bit signal indicatin signature pass or failed   
    
    reg [`DWIDTH-1:0] seed_sk [1:0];
    reg [`DWIDTH-1:0] seed_pk [1:0];
    reg [`DWIDTH-1:0] seed_y  [1:0];
    reg [`DWIDTH-1:0] message [6:0];
    reg [`DWIDTH-1:0] seed_r  [1:0];
    reg [`DATA-1:0]   sig     [75:0];
    reg [`ADDR-1:0] i;
    reg [`ADDR-1:0] addr_ext;
    
    integer j;
    reg [`IV-1:0] iv0, iv1, EQN_GEN_ADDR;
    reg [`ADDR-1:0] ADDR_Pi3, T, U;


    initial begin
        seed_sk[0] = 64'hAA9476B0A035997C;
        seed_sk[1] = 64'hDD1A6BDBE4106D0C;
        
        // *** FIXED: Corrected seed_pk values ***
        seed_pk[0] = 64'h5EB54C6514222891;
        seed_pk[1] = 64'h4D601939D5AC2C7C;  // Was correct
        
        seed_y[0]  = 64'h2C4D878B45E04942;
        seed_y[1]  = 64'h758E06E47D70EEF0;
        
        // Little Endian Format (correct byte order for Keccak):
        message[0] = 64'h5EB54C6514222891;  // seed_pk bytes 0-7
        message[1] = 64'h4D601939D5AC2C7C;  // seed_pk bytes 8-15
        message[2] = 64'hFBCB4F738D4D1CD8;  // message bytes 0-7
        message[3] = 64'hAA9F038A3F3DDEEA;  // message bytes 8-15
        message[4] = 64'h55AD35E857992C2A;  // *** FIXED: Was 55ADE83557992C2A ***
        message[5] = 64'h6A55BB57BF752EB2;  // message bytes 24-31
        message[6] = 64'h00000000000000C8;  // *** FIXED: Added leading zeros for clarity ***
        
        seed_r[0] = 64'h2BD88E8AE7B613D1;
        seed_r[1] = 64'h39884E13ED801604;
        
        // generated signature (unpacked format)
        sig[0]  = 24'h367791;
        sig[1]  = 24'h0999C1;
        sig[2]  = 24'h71A158;
        sig[3]  = 24'h9ABE7C;
        sig[4]  = 24'h82F577;
        sig[5]  = 24'h0000C9;
        sig[6]  = 24'h084602;
        sig[7]  = 24'h274968;
        sig[8]  = 24'h4F3D51;
        sig[9]  = 24'h245558;
        sig[10] = 24'h780569;
        sig[11] = 24'h084963;
        sig[12] = 24'h0E591D;
        sig[13] = 24'h53761F;
        sig[14] = 24'h64520E;
        sig[15] = 24'h461B61;
        sig[16] = 24'h1A4753;
        sig[17] = 24'h58270E;
        sig[18] = 24'h7B130B;
        sig[19] = 24'h073F2E;
        sig[20] = 24'h5A6938;
        sig[21] = 24'h515C3D;
        sig[22] = 24'h214B62;
        sig[23] = 24'h225938;
        sig[24] = 24'h7E3300;
        sig[25] = 24'h5E0271;
        sig[26] = 24'h763773;
        sig[27] = 24'h59425A;
        sig[28] = 24'h0F0662;
        sig[29] = 24'h323300;
        sig[30] = 24'h326F4E;
        sig[31] = 24'h5D714A;
        sig[32] = 24'h253B75;
        sig[33] = 24'h646D61;
        sig[34] = 24'h515F03;
        sig[35] = 24'h335710;
        sig[36] = 24'h642349;
        sig[37] = 24'h157A08;
        sig[38] = 24'h732228;
        sig[39] = 24'h775236;
        sig[40] = 24'h346D22;
        sig[41] = 24'h701044;
        sig[42] = 24'h430D61;
        sig[43] = 24'h471908;
        sig[44] = 24'h256355;
        sig[45] = 24'h1B3075;
        sig[46] = 24'h546114;
        sig[47] = 24'h1A492C;
        sig[48] = 24'h47550C;
        sig[49] = 24'h0F4233;
        sig[50] = 24'h3B6F4E;
        sig[51] = 24'h5C0561;
        sig[52] = 24'h670F2D;
        sig[53] = 24'h7B033B;
        sig[54] = 24'h687817;
        sig[55] = 24'h3D535B;
        sig[56] = 24'h221A50;
        sig[57] = 24'h79133F;
        sig[58] = 24'h2A4437;
        sig[59] = 24'h70501C;
        sig[60] = 24'h621D7B;
        sig[61] = 24'h3D1905;
        sig[62] = 24'h59351F;
        sig[63] = 24'h1E1326;
        sig[64] = 24'h25303A;
        sig[65] = 24'h6B7A78;
        sig[66] = 24'h1B4058;
        sig[67] = 24'h2E6A71;
        sig[68] = 24'h416843;
        sig[69] = 24'h055520;
        sig[70] = 24'h020220;
        sig[71] = 24'h6B4D74;
        sig[72] = 24'h527E0F;
        sig[73] = 24'h441A1D;
        sig[74] = 24'h2F3521;
        sig[75] = 24'h54101C;
    end
    
    // Instantiate DUT
    qruov_top qruov_uut (
        .clk(clk),
        .rst(rst),
        .algo_select(algo_select),
        .ins(ins),
        .din_ext(din_ext),
        .dout_ext(dout_ext),
        .TOD(TOD),
        .sig_pf(sig_pf)
    );

    // Clock generation
    always #6.25 clk = ~clk;  // 100MHz

    initial begin
        // Initialize signals
        rst = 0;
        @(posedge clk);
        rst = 1;
        algo_select = 2'd0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk); 
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);    
        rst          = 0;
        iv0          = 0;
        iv1          = 0; 
        ADDR_Pi3     = 0;
        T            = 0;
        U            = 0;
        EQN_GEN_ADDR = 0;
        
        @(posedge clk);
        algo_select = 2'd3;    
        
        // TID:     0: IDLE, 1: start_load_input_data, 2: start_compute, 3: start_retrieve_output_data
        // CDT:     corresponding data: 0: load seed, 1: load public key, 2: load secret key
        // OP:      determines which operation is need to execute: 0: NOP, 1: inputs to shake128 with seed
        // RADDR:   The largest public key bytes for security level V are 173,676. Therefore, we preferred 16-bit address for memories: 2^12 = 4096 and 4096 * 64 (bits on each address) = 262,144
        // WADDR:   The largest public key bytes for security level V are 173,676. Therefore, we preferred 16-bit address for memories: 2^12 = 4096 and 4096 * 64 (bits on each address) = 262,144
        // WE:      write enable signal
        // IV:      initialization vector (of 2 bytes or 16 bits)
        // RTYPE:   rate_type => 0: SHA3-256, => 1: SHA3-512, => 2: SHAKE128, and => 3: SHAKE256
        
        /*=======================================================================
        --  PHASE 1: Load input data into the memories
        =========================================================================*/
        $display("==== Load Input Data Started ====");
        
        // Loading seed_sk
        $display("==== Load seed_sk Started ====");
        for (i=0; i<=1; i=i+1) begin
            @(posedge clk);
            addr_ext = i;
            din_ext  = seed_sk[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_sk Finished ====");
        
        // Loading seed_pk
        $display("==== Load seed_pk Started ====");
        for (i=0; i<=1; i=i+1) begin
            @(posedge clk);
            addr_ext = i+2;
            din_ext  = seed_pk[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_pk Finished ====");
        
        // Loading seed_y
        $display("==== Load seed_y Started ====");
        for (i=0; i<=1; i=i+1) begin
            @(posedge clk);
            addr_ext = i+4;
            din_ext  = seed_y[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_y Finished ====");
        
        // Loading concatenated message with seed_pk
        $display("==== Load concatenated message Started ====");
        for (i=0; i<=6; i=i+1) begin
            @(posedge clk);
            addr_ext = i+6;
            din_ext  = message[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load concatenated message Finished ====");
        
        // Loading seed_r
        $display("==== Load seed_r Started ====");
        for (i=0; i<=1; i=i+1) begin
            @(posedge clk);
            addr_ext = i+13;
            din_ext  = seed_r[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_r Finished ====");
        
        @(posedge clk);
        $display("==== Load Input Data Finished ====");
        
        /*=======================================================================
        --  PHASE 2: Start Sign
        =========================================================================*/
        
        /*================================================
        -- Expand_mu(seed_pk, message, message_length, mu) ;
        =================================================*/
        $display("==== Start Expand_mu ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Generating matrix Expand_mu (see address 0 to 21 of memory 
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd6, `OP'd13, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-256 for Expand_mu");
        //$finish;
        
        /*================================================
        -- Loading sig_r into Memory (see addresses 22 to 97)
        =================================================*/
        
        $display("==== Load sig Started ====");
        for (i=0; i<=75; i=i+1) begin
            @(posedge clk);
            addr_ext = i+22;
            din_ext  = {{40'b0}, sig[i]}; 
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd1, `TID'd1};
        end
        $display("==== Load sig Finished ====");
        @(posedge clk);
        @(posedge clk);
        //$finish;
        
        /*================================================
        -- Start Buffering the mu and sig->r bytes for HASH
        =================================================*/
        $display("==== Start Buffering the mu and sig->r bytes for HASH ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Start Buffering the mu and sig->r bytes for HASH (from addresses 0 to 27 comprising mu and sig->r)
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd16, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Buffering the mu and sig->r bytes for HASH");
        //$finish;
        
        /*================================================
        -- Generating Hash(mu, sig->r, msg) ;
        =================================================*/
        $display("==== Start Generating HASH ====");
        // reset the internal blocks
        //@(posedge clk);
        //ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        //@(posedge clk);
        //ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Generating SHAKE256 for Generating HASH(mu, sig->r, msg) (see address 98 to 115 of memory )
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd98, `ADDR'd0, `ADDR'd0, `OP'd15, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE256 for Generating HASH(mu, sig->r, msg)");
        //$finish;
        
        
        for(j=0; j<54; j=j+1) 
        begin
            /*================================================
            -- Expand seed_pk
            =================================================*/
            $display("==== Start Expanding the Public Key (Expand_pk) ====");
            
            iv0         = 2*j;
            iv1         = (2*j) + 1'b1;
            ADDR_Pi3    = (18*18)*j; // M = 18 (its offset of 324 = 18 x 18) This means that the matrix of size 18x18 is passed for verify
            T           = 2604 + j;
            U           = 2658 + j;
            //C_GEN_ADDR = 4362 + j;
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            
            // Generating matrix Pi1 (see address 116 to 1493 of memory (4134/3=1378))
            ins = {`RTYPE'd2, iv0, `WE'd0, `ADDR'd116, `ADDR'd0, `ADDR'd2, `OP'd3, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for Pi1 matrix generation");
            //$finish;
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Generating matrix Pi2 (see address 1494 to 2429 of memory (writing 2808 bytes))
            ins = {`RTYPE'd2, iv1, `WE'd0, `ADDR'd1494, `ADDR'd0, `ADDR'd2, `OP'd4, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for Pi2 matrix generation");
            $display("==== Finished Expanding the Public Key (Expand_pk) ====");
            //$finish;
            
            /*================================================
            -- Below we are generating the instructions for 
            -- verify_i() function of the reference code;
            =================================================*/
            
            /*================================================
            -- Generating VECTOR_M_dot_VECTOR_M(oil, Pi2[j], t) ;
            =================================================*/
            $display("==== Start VECTOR_M_dot_VECTOR_M(oil, Pi2[j], t) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address 2430 to 2481 for t )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd2430, `ADDR'd80, `ADDR'd1494, `OP'd19, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_M_dot_VECTOR_M(oil, Pi2[j], t) ;");
            //$finish;
            
            /*================================================
            -- Generating VECTOR_V_dot_VECTOR_V(vineger, Pi1[j], u) ;
            =================================================*/
            $display("==== Start VECTOR_V_dot_VECTOR_V(vineger, Pi1[j], u) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address 2482 to 2533 for u )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd2482, `ADDR'd116, `ADDR'd28, `OP'd23, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_V_dot_VECTOR_V(vineger, Pi1[j], u) ;");
            //$finish;
            
            /*================================================
            -- Generating t + t from for(k=0;k<QRUOV_L;k++) tmp_v[k][j] = Fq_add(Fq_add(t[k],t[k]),u[k]) ;
            =================================================*/
            $display("==== Start t + t ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address in mem_2 from 17496 to 17547 for  t + t)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd17496, `ADDR'd2430, `ADDR'd2430, `OP'd9, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: t + t ");
            //$finish;
            
            /*================================================
            -- Generating t + u from for(k=0;k<QRUOV_L;k++) tmp_v[k][j] = Fq_add(Fq_add(t[k],t[k]),u[k]) ;
            =================================================*/
            $display("==== Start t + u ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address 2534 to 2585 for  t + u)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd2534, `ADDR'd2482, `ADDR'd17496, `OP'd24, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: t + u ");
            //$finish;
            
            /*================================================
            -- Generating VECTOR_M_dot_VECTOR_M(oil, Pi3[j], t) ;
            =================================================*/
            $display("==== Start VECTOR_M_dot_VECTOR_M(oil, Pi3[j], t) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address 2586 to 2603 )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd2586, `ADDR'd80, ADDR_Pi3, `OP'd25, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_M_dot_VECTOR_M(oil, Pi3[j], t) ;");
            //$finish;
            
            
            /*================================================
            -- Generating VECTOR_V_dot_VECTOR_V(vineger, tmp_v, t) ;
            =================================================*/
            $display("==== Start VECTOR_V_dot_VECTOR_V(vineger, tmp_v, t) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address 2604 to 2657 for t )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, T, `ADDR'd2534, `ADDR'd28, `OP'd26, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_V_dot_VECTOR_V(vineger, tmp_v, t) ;");
            //$finish;
            
            /*================================================
            -- Generating VECTOR_M_dot_VECTOR_M(oil    , tmp_o, u) ;
            =================================================*/
            $display("==== Start VECTOR_M_dot_VECTOR_M(oil    , tmp_o, u) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // (see address 2658 to 2711 for u )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, U, `ADDR'd2586, `ADDR'd80, `OP'd27, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_M_dot_VECTOR_M(oil    , tmp_o, u) ;");
            //$finish;
            
        end
        
        
        /*================================================
        -- Generating vector to compare with msg_i  
        =================================================*/
        $display("==== Start: Computing the msg_i == Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ; ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
            
        // (see address 0 to 53 of mem-2 for sum of overall addition of the computed vectors for msg comparison)
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd2658, `ADDR'd2604, `OP'd28, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Computing the msg_i == Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ;");
        
        /*================================================
        -- Copying Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ; correct bytes order to exact comparison with msg_i
        =================================================*/
        $display("==== Start: Copying Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ; bytes to exact comparison with msg_i ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Copying bytes (loading address 0 to 53 from mem-2 and store on mem-1 on addresses from 2712 to 2729)
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd2712, `ADDR'd0, `ADDR'd0, `OP'd17, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Copying Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ; bytes to exact comparison with msg_i ");
        //$finish;
        
        /*================================================
        -- Compare msg_i (here)
        =================================================*/
        $display("==== Start: Comparing msg_i ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd2712, `ADDR'd98, `OP'd30, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Comparing msg_i ");
        //$finish;

        // wait a cycle or two if sig_pf is produced after TOD
        @(posedge clk);
        @(posedge clk);
    
        $display("==================================================================================================");
        if (sig_pf == 1'b1) begin
            $display("== Signature Passed Successfully !!!! ==");
        end else begin
            $display("== Signature Failed !!!! ==");
        end
        $display("==================================================================================================");    
        
    $display("==================================================================================================");
    $display("== Finished Signature Verification ==");
    $display("==================================================================================================");
      
    $finish;
        
    end
    

endmodule