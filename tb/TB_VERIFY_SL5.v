`timescale 1ns / 1ps
`include"signal_sizes.vh"

/*=======================================================================
--  The generated PUBLIC-KEY resides at addresses 5122--5445 and 5770--6093
=========================================================================*/

module TB_VERIFY_SL5;

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
    
    reg [`DWIDTH-1:0] seed_sk [3:0];
    reg [`DWIDTH-1:0] seed_pk [3:0];
    reg [`DWIDTH-1:0] seed_y  [3:0];
    reg [`DWIDTH-1:0] message [8:0];
    reg [`DWIDTH-1:0] seed_r  [3:0];
    reg [`DATA-1:0]   sig     [147:0];
    reg [`ADDR-1:0] i;
    reg [`ADDR-1:0] addr_ext;
    
    integer j;
    reg [`IV-1:0] iv0, iv1, EQN_GEN_ADDR;
    reg [`ADDR-1:0] ADDR_Pi3, T, U;


    initial begin
        seed_sk[0] = 64'hAA9476B0A035997C;
        seed_sk[1] = 64'hDD1A6BDBE4106D0C;
        seed_sk[2] = 64'h0348B1CC251AD82F;
        seed_sk[3] = 64'h2D7F73369973CD2D;
        
        // *** FIXED: Corrected seed_pk values ***
        seed_pk[0] = 64'h081451D479ED2686;
        seed_pk[1] = 64'h21F856B9593BE000;
        seed_pk[2] = 64'hDC137D406760550E;
        seed_pk[3] = 64'h8FFB2B878B9EFA90;
        
        seed_y[0]  = 64'hA4BBBEA5F7037C14;
        seed_y[1]  = 64'h137F4D87E1FAC806;
        seed_y[2]  = 64'h74A8A9A379FE0EC8;
        seed_y[3]  = 64'h157699F676FE09CC;

        // Little Endian Format (correct byte order for Keccak):
        message[0] = 64'h081451D479ED2686;  // seed_pk bytes 0-7
        message[1] = 64'h21F856B9593BE000;  // seed_pk bytes 8-15
        message[2] = 64'hDC137D406760550E;  // seed_pk bytes 16-23
        message[3] = 64'h8FFB2B878B9EFA90;  // seed_pk bytes 24-31
        message[4] = 64'hFBCB4F738D4D1CD8;  // message bytes 0-7
        message[5] = 64'hAA9F038A3F3DDEEA;  // message bytes 8-15
        message[6] = 64'h55AD35E857992C2A;  // message bytes 16-23
        message[7] = 64'h6A55BB57BF752EB2;  // message bytes 24-31
        message[8] = 64'h00000000000000C8;  // message bytes 32-32
        
        seed_r[0] = 64'hFE85DDA650E02CC8;
        seed_r[1] = 64'hB146F16A65D03DA6;
        seed_r[2] = 64'h922C07C0AB910F88;
        seed_r[3] = 64'h61469C767817DAA9;
        
        // generated signature (unpacked format)
        // 0-based addressing:
		// sig[0]..sig[10]  = 32-byte public seed
		// sig[11]..sig[147] = s[0]..s[136]
		//
		// If you are counting addresses as 1..N in comments,
		// then this means "initial 11 addresses" and s starts at address 12.

		sig[  0] = 24'h8C297C;
		sig[  1] = 24'hF332E9;
		sig[  2] = 24'h4EF4CE;
		sig[  3] = 24'hE8633F;
		sig[  4] = 24'h6907B7;
		sig[  5] = 24'h02FA7B;
		sig[  6] = 24'h5424FA;
		sig[  7] = 24'h4C3621;
		sig[  8] = 24'hEB3FAF;
		sig[  9] = 24'h854140;
		sig[ 10] = 24'h0004BA; // last salt (sig->r) seed bytes
		sig[ 11] = 24'h707B7A; // signature bytes generated 
		sig[ 12] = 24'h706731;
		sig[ 13] = 24'h4D2651;
		sig[ 14] = 24'h280210;
		sig[ 15] = 24'h3A2634;
		sig[ 16] = 24'h0D203D;
		sig[ 17] = 24'h383168;
		sig[ 18] = 24'h2D195C;
		sig[ 19] = 24'h1E3E0D;
		sig[ 20] = 24'h5A7B6F;
		sig[ 21] = 24'h516C43;
		sig[ 22] = 24'h7D711B;
		sig[ 23] = 24'h030E09;
		sig[ 24] = 24'h58131F;
		sig[ 25] = 24'h006F1D;
		sig[ 26] = 24'h43500D;
		sig[ 27] = 24'h3A353A;
		sig[ 28] = 24'h51522B;
		sig[ 29] = 24'h102F11;
		sig[ 30] = 24'h1C6732;
		sig[ 31] = 24'h1E6C72;
		sig[ 32] = 24'h79033E;
		sig[ 33] = 24'h4C4B74;
		sig[ 34] = 24'h501467;
		sig[ 35] = 24'h084911;
		sig[ 36] = 24'h4F1F55;
		sig[ 37] = 24'h390D18;
		sig[ 38] = 24'h527745;
		sig[ 39] = 24'h49430D;
		sig[ 40] = 24'h0C277D;
		sig[ 41] = 24'h4D4473;
		sig[ 42] = 24'h0C5D3D;
		sig[ 43] = 24'h23557B;
		sig[ 44] = 24'h774C22;
		sig[ 45] = 24'h1E4B66;
		sig[ 46] = 24'h396A4F;
		sig[ 47] = 24'h243272;
		sig[ 48] = 24'h42655E;
		sig[ 49] = 24'h467809;
		sig[ 50] = 24'h6D6C4B;
		sig[ 51] = 24'h080053;
		sig[ 52] = 24'h357D72;
		sig[ 53] = 24'h745929;
		sig[ 54] = 24'h695039;
		sig[ 55] = 24'h3E355F;
		sig[ 56] = 24'h05493B;
		sig[ 57] = 24'h6D6E1E;
		sig[ 58] = 24'h68624A;
		sig[ 59] = 24'h3B6F46;
		sig[ 60] = 24'h5A2D4E;
		sig[ 61] = 24'h1F0474;
		sig[ 62] = 24'h320552;
		sig[ 63] = 24'h486E14;
		sig[ 64] = 24'h610F6E;
		sig[ 65] = 24'h147B3F;
		sig[ 66] = 24'h2F7172;
		sig[ 67] = 24'h326F6C;
		sig[ 68] = 24'h5F2751;
		sig[ 69] = 24'h334F64;
		sig[ 70] = 24'h4C4628;
		sig[ 71] = 24'h4C5064;
		sig[ 72] = 24'h711C30;
		sig[ 73] = 24'h187516;
		sig[ 74] = 24'h4E7879;
		sig[ 75] = 24'h526F65;
		sig[ 76] = 24'h0F1174;
		sig[ 77] = 24'h7B030A;
		sig[ 78] = 24'h2B4361;
		sig[ 79] = 24'h5E5E1F;
		sig[ 80] = 24'h65005C;
		sig[ 81] = 24'h554465;
		sig[ 82] = 24'h1D514F;
		sig[ 83] = 24'h3F130B;
		sig[ 84] = 24'h30496F;
		sig[ 85] = 24'h261760;
		sig[ 86] = 24'h13784B;
		sig[ 87] = 24'h0A7D7B;
		sig[ 88] = 24'h6A5C37;
		sig[ 89] = 24'h4B5906;
		sig[ 90] = 24'h26123C;
		sig[ 91] = 24'h730066;
		sig[ 92] = 24'h274B43;
		sig[ 93] = 24'h740C1F;
		sig[ 94] = 24'h5B0F7A;
		sig[ 95] = 24'h571147;
		sig[ 96] = 24'h5C1705;
		sig[ 97] = 24'h5F5432;
		sig[ 98] = 24'h517147;
		sig[ 99] = 24'h1A1E53;
		sig[100] = 24'h625C15;
		sig[101] = 24'h361975;
		sig[102] = 24'h3A4536;
		sig[103] = 24'h4B7B69;
		sig[104] = 24'h7C6751;
		sig[105] = 24'h42247C;
		sig[106] = 24'h64235A;
		sig[107] = 24'h7C6F79;
		sig[108] = 24'h2C7B07;
		sig[109] = 24'h41406E;
		sig[110] = 24'h42283D;
		sig[111] = 24'h0D4F6E;
		sig[112] = 24'h64511C;
		sig[113] = 24'h483F37;
		sig[114] = 24'h203E4A;
		sig[115] = 24'h0D1A47;
		sig[116] = 24'h710130;
		sig[117] = 24'h6E1614;
		sig[118] = 24'h157671;
		sig[119] = 24'h2B1C78;
		sig[120] = 24'h41741D;
		sig[121] = 24'h363A02;
		sig[122] = 24'h054943;
		sig[123] = 24'h636C32;
		sig[124] = 24'h251176;
		sig[125] = 24'h452A36;
		sig[126] = 24'h271216;
		sig[127] = 24'h20095F;
		sig[128] = 24'h595305;
		sig[129] = 24'h645B16;
		sig[130] = 24'h0E1346;
		sig[131] = 24'h1E0833;
		sig[132] = 24'h7D5116;
		sig[133] = 24'h611E4A;
		sig[134] = 24'h2B104B;
		sig[135] = 24'h5D426F;
		sig[136] = 24'h5B2B1D;
		sig[137] = 24'h143226;
		sig[138] = 24'h457504;
		sig[139] = 24'h5E471D;
		sig[140] = 24'h23767A;
		sig[141] = 24'h4D652D;
		sig[142] = 24'h422E48;
		sig[143] = 24'h29030B;
		sig[144] = 24'h777E20;
		sig[145] = 24'h681E39;
		sig[146] = 24'h6A2120;
		sig[147] = 24'h173535; 
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
        for (i=0; i<=3; i=i+1) begin
            @(posedge clk);
            addr_ext = i;
            din_ext  = seed_sk[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_sk Finished ====");
        
        // Loading seed_pk
        $display("==== Load seed_pk Started ====");
        for (i=0; i<=3; i=i+1) begin
            @(posedge clk);
            addr_ext = i+4;
            din_ext  = seed_pk[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_pk Finished ====");
        
        // Loading seed_y
        $display("==== Load seed_y Started ====");
        for (i=0; i<=3; i=i+1) begin
            @(posedge clk);
            addr_ext = i+8;
            din_ext  = seed_y[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_y Finished ====");
        
        // Loading concatenated message with seed_pk
        $display("==== Load concatenated message Started ====");
        for (i=0; i<=11; i=i+1) begin
            @(posedge clk);
            addr_ext = i+12;
            din_ext  = message[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load concatenated message Finished ====");
        
        // Loading seed_r
        $display("==== Load seed_r Started ====");
        for (i=0; i<=3; i=i+1) begin
            @(posedge clk);
            addr_ext = i+21;
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
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd12, `OP'd13, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-256 for Expand_mu");
        //$finish;
        
        /*================================================
        -- Loading sig_r into Memory (see addresses 22 to 169)
        =================================================*/
        
        $display("==== Load sig Started ====");
        for (i=0; i<=147; i=i+1) begin
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
        
        // Start Buffering the mu and sig->r bytes for HASH (from addresses 96 bytes comprising mu (64 bytes) and sig->r (salt 32 bytes))
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
        
        // Generating SHAKE256 for Generating HASH(mu, sig->r, msg) (see address 170 to 204 of memory )
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd170, `ADDR'd0, `ADDR'd0, `OP'd15, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-256 for Generating HASH(mu, sig->r, msg)");
        //$finish;
        
        
        for(j=0; j<105; j=j+1) 
        begin
            /*================================================
            -- Expand seed_pk
            =================================================*/
            $display("==== Start Expanding the Public Key (Expand_pk) ====");
            
            iv0         = 2*j;
            iv1         = (2*j) + 1'b1;
            ADDR_Pi3    = (35*35)*j; // M = 18 (its offset of 324 = 18 x 18) This means that the matrix of size 18x18 is passed for verify
            T           = 9369 + j;
            U           = 9474 + j;
            //C_GEN_ADDR = 4362 + j;
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            
            // Generating matrix Pi1 (see address 205 to 5457 of memory )
            ins = {`RTYPE'd3, iv0, `WE'd0, `ADDR'd205, `ADDR'd0, `ADDR'd4, `OP'd3, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-256 and RejSAMP (in-parallel) for Pi1 matrix generation");
            //$finish;
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Generating matrix Pi2 (see address 5458 to 9027 of memory (writing 3569 bytes))
            ins = {`RTYPE'd3, iv1, `WE'd0, `ADDR'd5458, `ADDR'd0, `ADDR'd4, `OP'd4, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-1256 and RejSAMP (in-parallel) for Pi2 matrix generation");
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
            
            // (see address 9028 to 9129 for t )
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd9028, `ADDR'd135, `ADDR'd5458, `OP'd19, `CDT'd0, `TID'd2}; // oil variables contains from address 135 to 169
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
            
            // (see address 9130 to 9231 for u )
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd9130, `ADDR'd205, `ADDR'd33, `OP'd23, `CDT'd0, `TID'd2}; // venegar variables contains from address 33 to 134
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
            
            // (see address in mem_2 from 1,28,625 to 1,28,726 for  t + t)
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd128625, `ADDR'd9028, `ADDR'd9028, `OP'd9, `CDT'd0, `TID'd2}; 
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
            
            // (see address 9232 to 9333 for  t + u)
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd9232, `ADDR'd9130, `ADDR'd128625, `OP'd24, `CDT'd0, `TID'd2}; 
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
            
            // (see address 9334 to 9368 )
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd9334, `ADDR'd135, ADDR_Pi3, `OP'd25, `CDT'd0, `TID'd2}; 
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
            
            // (see address 9369 to 9472 for t )
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, T, `ADDR'd9232, `ADDR'd33, `OP'd26, `CDT'd0, `TID'd2}; 
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
            
            // (see address 9474 to 9578 for u )
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, U, `ADDR'd9334, `ADDR'd135, `OP'd27, `CDT'd0, `TID'd2}; 
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
            
        // (see address 0 to 103 of mem-2 for sum of overall addition of the computed vectors for msg comparison)
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd9474, `ADDR'd9369, `OP'd28, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Computing the msg_i == Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ;");
        $finish;
        
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
        
        // Copying bytes (loading address 0 to 103 from mem-2 and store on mem-1 on addresses from 9577 to 9611)
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd9577, `ADDR'd0, `ADDR'd0, `OP'd17, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Copying Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ; bytes to exact comparison with msg_i ");
        $finish;
        
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
        
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd9577, `ADDR'd170, `OP'd30, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Comparing msg_i ");
        $finish;

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