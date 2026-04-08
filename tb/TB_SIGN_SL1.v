`timescale 1ns / 1ps
`include"signal_sizes.vh"

/*=======================================================================
--  The generated PUBLIC-KEY resides at addresses 5122--5445 and 5770--6093
=========================================================================*/

module TB_SIGN_SL1;

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
    reg [`ADDR-1:0] i;
    reg [`ADDR-1:0] addr_ext;
    
    integer j;
    reg [`IV-1:0] iv0, iv1, C_GEN_ADDR, EQN_GEN_ADDR;


    initial begin
        seed_sk[0] = 64'hAA9476B0A035997C;
        seed_sk[1] = 64'hDD1A6BDBE4106D0C;
        
        // *** FIXED: Corrected seed_pk values ***
        seed_pk[0] = 64'h5EB54C6514222891;
        seed_pk[1] = 64'h4D601939D5AC2C7C;  // Was correct
        
        seed_y[0]  = 64'h2C4D878B45E04942;
        seed_y[1]  = 64'h758E06E47D70EEF0;

        // *** FIXED: Corrected message concatenation ***
        // C reference test case:
        // seed_pk: 91 28 22 14 65 4C B5 5E 7C 2C AC D5 39 19 60 4D
        // message: D8 1C 4D 8D 73 4F CB FB EA DE 3D 3F 8A 03 9F AA 
        //          2A 2C 99 57 E8 35 AD 55 B2 2E 75 BF 57 BB 55 6A C8
        
        // Little Endian Format (correct byte order for Keccak):
        message[0] = 64'h5EB54C6514222891;  // seed_pk bytes 0-7
        message[1] = 64'h4D601939D5AC2C7C;  // seed_pk bytes 8-15
        message[2] = 64'hFBCB4F738D4D1CD8;  // message bytes 0-7
        message[3] = 64'hAA9F038A3F3DDEEA;  // message bytes 8-15
        message[4] = 64'h55AD35E857992C2A;  // *** FIXED: Was 55ADE83557992C2A ***
        message[5] = 64'h6A55BB57BF752EB2;  // message bytes 24-31
        message[6] = 64'h00000000000000C8;  // *** FIXED: Added leading zeros for clarity ***
        
        //seed_r[0]  = 64'h2BD88E8AE7B613D1;
        //seed_r[1]  = 64'h39884E13ED801604;
        seed_r[0] = 64'h2BD88E8AE7B613D1;
        seed_r[1] = 64'h39884E13ED801604;
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
        C_GEN_ADDR   = 0;
        EQN_GEN_ADDR = 0;
        
        @(posedge clk);
        algo_select = 2'd2;    
        
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
        -- Expand seed_sk
        =================================================*/
        $display("==== Start Expanding the Secret Key (Expand_sk) ====");
        // Generating matrix SD (see address 0 to 935 of memory (2808/3 = 936))
        @(posedge clk);
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd2, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for SD matrix generation");
        
        @(posedge clk);
        $display("==== Finished Expanding the Secret Key (Expand_sk) ====");
        //$finish;
        
        /*================================================
        -- Expand seed_y (156 elements -- 156/3 = 52 addresses) -- resides in 936 to 987
        =================================================*/
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        $display("==== Start Expanding the Seed_y ====");
        // Generating vecto y (vaniger variables) (see address 936 to 987 of memory)
        @(posedge clk);
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd936, `ADDR'd0, `ADDR'd4, `OP'd10, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for seed_y expansion");
        
        @(posedge clk);
        $display("==== Finished Expanding the seed_y ====");
        //$finish;
        EQN_GEN_ADDR = 3390;
        
        
        
        for(j=0; j<54; j=j+1) 
        begin
            /*================================================
            -- Expand seed_pk
            =================================================*/
            $display("==== Start Expanding the Public Key (Expand_pk) ====");
            
            iv0 = 2*j;
            iv1 = (2*j) + 1'b1;
            C_GEN_ADDR = 4362 + j;
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            
            // Generating matrix Pi1 (see address 988 to 2365 of memory (4134/3=1378))
            ins = {`RTYPE'd2, iv0, `WE'd0, `ADDR'd988, `ADDR'd0, `ADDR'd2, `OP'd3, `CDT'd0, `TID'd2}; 
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
            
            // Generating matrix Pi2 (see address 2366 to 3301 of memory (writing 2808 bytes))
            ins = {`RTYPE'd2, iv1, `WE'd0, `ADDR'd2366, `ADDR'd0, `ADDR'd2, `OP'd4, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for Pi2 matrix generation");
            //$finish;
    
            $display("==== Finished Expanding the Public Key (Expand_pk) ====");
            
            $display("==== Start Executing the Vector_V_MUL_SYMMETRIC_MATRIX_VxV (yT, Pi1, yT_Pi1)");
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing Vector_V_MUL_SYMMETRIC_MATRIX_VxV (yT, Pi1, yT_Pi1); (see addresses from 3302 to 3353)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd3302, `ADDR'd988, `ADDR'd936, `OP'd5, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the Vector_V_MUL_SYMMETRIC_MATRIX_VxV (yT, Pi1, yT_Pi1); ====");
            //$finish;
            
            $display("Start Executing the VECTOR_V_MUL_MATRIX_VxM(yT_Pi1, Sd, yT_Pi1_Sd) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing VECTOR_V_MUL_MATRIX_VxM(yT_Pi1, Sd, yT_Pi1_Sd) ; (write from 3354 to 3371)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd3354, `ADDR'd0, `ADDR'd3302, `OP'd7, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the VECTOR_V_MUL_MATRIX_VxM(yT_Pi1, Sd, yT_Pi1_Sd) ; ====");
            //$finish;
            
            $display("Start Executing the VECTOR_V_MUL_MATRIX_VxM(yT, Pi2, yT_Pi2) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing VECTOR_V_MUL_MATRIX_VxM(yT, Pi2, yT_Pi2) ; (write from 3372 to 3389)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd3372, `ADDR'd2366, `ADDR'd936, `OP'd7, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the VECTOR_V_MUL_MATRIX_VxM(yT, Pi2, yT_Pi2) ; ====");
            //$finish;
            
            $display("Start Executing the VECTOR_M_SUB(yT_Pi2, yT_Pi1_Sd, yT_Fi2) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing VECTOR_M_SUB(yT_Pi2, yT_Pi1_Sd, yT_Fi2) ; (write in MEM_2 from 0 to 17)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd3354, `ADDR'd3372, `OP'd6, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the VECTOR_M_SUB(yT_Pi2, yT_Pi1_Sd, yT_Fi2) ; ====");
            //$finish;
    
            $display("Start Generating the EQN_GEN ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing the EQN_GEN (write from 3390 to 4361)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, EQN_GEN_ADDR, `ADDR'd0, `ADDR'd0, `OP'd9, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Generating the EQN_GEN ; ====");
            //$finish;
            EQN_GEN_ADDR = EQN_GEN_ADDR + 18;
            
            $display("Start Generating the C_GEN ; (yT_Fi1 * yT) ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing the C_GEN (write from 4362 to 4413)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, C_GEN_ADDR, `ADDR'd936, `ADDR'd3302, `OP'd11, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Generating the C_GEN ; ====");
            //$finish;
        end
        
        /*================================================
        -- Copying c[i] bytes to use in the next stage;
        =================================================*/
        $display("==== Copying c[i] bytes to use in the next stage ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Start Copying c[i] bytes to use in the next stage (see from 4362 to 4379)
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd4362, `ADDR'd0, `ADDR'd4362, `OP'd17, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Copying c[i] bytes to use in the next stage ");
        //$finish;
        
        /*================================================
        -- Start Generating the LU_decompose
        =================================================*/
        
        $display("Start Generating the LU_decompose ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Executing the LU_decompose unit (write from 3390 to 4361)
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd3390, `ADDR'd3390, `ADDR'd3390, `OP'd12, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("Finished Generating the LU_decompose ====");
        //$finish;
        
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
        
        // Generating matrix Expand_mu (see address 4380 to 4401 of memory 
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd4380, `ADDR'd0, `ADDR'd6, `OP'd13, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-256 for Expand_mu");
        //$finish;
        
        /*================================================
        -- Generating salt (QRUOV_PRG2_CTX * ctx_r = PRG2_init(seed_r) ; and PRG2_yield(ctx_r, QRUOV_SALT_LEN, sig->r) ;) ;
        =================================================*/
        $display("==== Start Generating Salt ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // Generating matrix Expand_mu (see address 4402 to 4407 of memory 
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd4402, `ADDR'd0, `ADDR'd13, `OP'd14, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE128 for Generating Salt");
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
        
        // Start Buffering the mu and sig->r bytes for HASH (from addresses 4380 to 4407 comprising mu and sig->r)
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd4380, `OP'd16, `CDT'd0, `TID'd2}; 
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
        
        // Generating SHAKE256 for Generating HASH(mu, sig->r, msg) (see address 4408 to 4425 of memory )
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd4408, `ADDR'd0, `ADDR'd0, `OP'd15, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE256 for Generating HASH(mu, sig->r, msg)");
        //$finish;
        
        
        /*================================================
        -- Generating b[i] = Fq_sub(msg[i], c[i]) ;
        =================================================*/
        $display("==== Start b[i] = Fq_sub(msg[i], c[i]) ; ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // (write in MEM_2 from 18 to 35) 
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd18, `ADDR'd4362, `ADDR'd4408, `OP'd6, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: b[i] = Fq_sub(msg[i], c[i]) ;");
        //$finish;
        
        /*================================================
        -- Generating sample_a_solution(seed_sol, echelon_form, b, oil_u, b2) ;
        -- Oil part of the generated signature is in memory 1 (from addresses 4444 to 4461)
        =================================================*/
        $display("==== Start sample_a_solution(seed_sol, echelon_form, b, oil_u, b2) ; ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // (see address 4426 to 4443 for b2 and 4444 to 4461 for oil_u )
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd4426, `ADDR'd18, `ADDR'd3390, `OP'd18, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: sample_a_solution(seed_sol, echelon_form, b, oil_u, b2) ;");
        
        @(posedge clk);
        $display("==== Finished Generating Signature for QR-UOV ====");
        //$finish;
        
        /*================================================
        -- Below we are implementing the following functionstatic void 
        -- Sign SIG_GEN(oil, Sd, y, sig) ;
        =================================================*/
        
        /*================================================
        -- Generating VECTOR_M_dot_VECTOR_M(oil, Sd[i], t) ;
        =================================================*/
        $display("==== Start VECTOR_M_dot_VECTOR_M(oil, Sd[i], t) ; ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // (see address 4462 to 4513 for t )
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd4462, `ADDR'd4444, `ADDR'd0, `OP'd19, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: VECTOR_M_dot_VECTOR_M(oil, Sd[i], t) ;");
        
        @(posedge clk);
        $display("==== Finished Generating Signature for QR-UOV ====");
        //$finish;
        
        /*================================================
        -- Copying the salt (sig-r) part of the signature from MEM_1 to MEM_2 (see addresses 36 to 41)
        =================================================*/
        $display("==== Start Copying Salt (sig->r) part of the Signature from MEM_1 to MEM_2 ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // (see address 36 to 41 for salt portion of the Signature )
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd36, `ADDR'd0, `ADDR'd4402, `OP'd22, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Copying Salt (sig->r) part of the Signature from MEM_1 to MEM_2 ");
        
        /*================================================
        -- Generating vinegar part of the signature using y-t
        -- See the vinegar part of the signature in MEM_2 (from addresses 42 to 93)
        =================================================*/
        $display("==== Start generating Vinegar part of the Signature ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // (see address 42 to 93 for Vinegar portion of the Signature )
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd42, `ADDR'd4462, `ADDR'd936, `OP'd20, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: generating Vinegar part of the Signature ");
        
        
        /*================================================
        -- Generating vinegar part of the signature using y-t
        -- Copying the oil part of the signature from MEM_1 to MEM_2 (see addresses 94 to 111)
        =================================================*/
        $display("==== Start Copying Oil part of the Signature from MEM_1 to MEM_2 ====");
        // reset the internal blocks
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
        @(posedge clk);
        ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
        @(posedge clk);
        
        // (see address 94 to 111 for oil portion of the Signature )
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd94, `ADDR'd0, `ADDR'd4444, `OP'd21, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Copying Oil part of the Signature from MEM_1 to MEM_2 ");
        
        $display("==================================================================================================");
        $display("== Generated Signature is in INT_MEM_uut_2 (from addresses 36 (inclusive) to 111 (inclusive))==");
        $display("==================================================================================================");
        
        @(posedge clk);
        $display("==== Finished Generating Signature for QR-UOV ====");
        $finish;
    end
    

endmodule