`timescale 1ns / 1ps
`include"signal_sizes.vh"

/*========================================================================
--  SL-III Verify Address Map
--
--  Parameters:
--      V = 76
--      M = 26
--      O = 78
--      salt words = 24 bytes / 3 = 8
--      signature words = salt + N = 8 + (V+M) = 8 + 102 = 110
--
--  Formulas:
--      Pi1        = V*(V+1)/2        = 76*77/2    = 2926
--      Pi2        = M*V              = 26*76      = 1976
--      t          = V                = 76
--      u          = V                = 76
--      t+t temp   = V                = 76
--      t+u        = V                = 76
--      Pi3*t      = M                = 26
--      T          = O                = 78
--      U          = O                = 78
--      msg_i vec  = O                = 78
--      copied cmp = M                = 26
--
--  Notes:
--      Expand_mu output size is kept the same style as your other test files:
--          Expand_mu : 22 addresses
--      HASH(mu, sig->r, msg) output size equals M = 26 addresses.
--
--  MEM1 / internal working address ranges used in this testbench:
--      Expand_mu        :    0 -- 21
--      Signature        :   22 -- 131   (8 salt + 102 signature words = 110)
--      HASH(msg_i)      :  132 -- 157   (26 addresses)
--      Pi1              :  158 -- 3083  (2926 addresses)
--      Pi2              : 3084 -- 5059  (1976 addresses)
--      t                : 5060 -- 5135  (76 addresses)
--      u                : 5136 -- 5211  (76 addresses)
--      t_plus_u         : 5212 -- 5287  (76 addresses)
--      Pi3_dot_oil_t    : 5288 -- 5313  (26 addresses)
--      T                : 5314 -- 5391  (78 addresses)
--      U                : 5392 -- 5469  (78 addresses)
--      copied compare   : 5470 -- 5495  (26 addresses)
--
--  MEM2 address ranges used in this testbench:
--      t_plus_t temp    : 52728 -- 52803  (O*M*M = 78*26*26 = 52728)
--      msg_i vector     :     0 -- 77
--
--  Signature layout loaded at MEM1[22..131]:
--      sig[0..7]        = sig->r (salt)
--      sig[8..83]       = vinegar part s[0..75]
--      sig[84..109]     = oil part s[76..101]
========================================================================*/

module TB_VERIFY_SL3;

    // Clock and reset
    reg clk = 0;
    reg rst;
    
    // select algorithm (KeyGen, Sign or Verify)
    reg  [1:0] algo_select;
    
    // Other Inputs to DUT
    reg  [`INS-1:0]    ins;
    reg  [`DWIDTH-1:0] din_ext;    // 64 bit data input
    // Outputs from DUT
    wire [`DWIDTH-1:0] dout_ext;   // 64 bit data output
    wire [`TOD-1:0]    TOD;        // 0: IDLE, 1: done_load_input_data, 2: done_compute, 3: done_retrieve_output_data
    wire sig_pf;                   // A one bit signal indicatin signature pass or failed
    
    reg [`DWIDTH-1:0] seed_sk [2:0];
    reg [`DWIDTH-1:0] seed_pk [2:0];
    reg [`DWIDTH-1:0] seed_y  [2:0];
    reg [`DWIDTH-1:0] message [7:0];
    reg [`DWIDTH-1:0] seed_r  [2:0];
    reg [`DATA-1:0]   sig     [109:0];
    reg [`ADDR-1:0] i;
    reg [`ADDR-1:0] addr_ext;
    
    integer j;
    reg [`IV-1:0] iv0, iv1, EQN_GEN_ADDR;
    reg [`ADDR-1:0] ADDR_Pi3, T, U;


    initial begin
        seed_sk[0] = 64'hAA9476B0A035997C;
        seed_sk[1] = 64'hDD1A6BDBE4106D0C;
        seed_sk[2] = 64'h0348B1CC251AD82F;
        
        seed_pk[0] = 64'h081451D479ED2686;
        seed_pk[1] = 64'h21F856B9593BE000;
        seed_pk[2] = 64'hDC137D406760550E;
        
        seed_y[0]  = 64'hA4BBBEA5F7037C14;
        seed_y[1]  = 64'h137F4D87E1FAC806;
        seed_y[2]  = 64'h74A8A9A379FE0EC8;

        // Concatenated input = seed_pk (24 bytes) || message (33 bytes)
        message[0] = 64'h081451D479ED2686;  // seed_pk bytes 0-7
        message[1] = 64'h21F856B9593BE000;  // seed_pk bytes 8-15
        message[2] = 64'hDC137D406760550E;  // seed_pk bytes 16-23
        message[3] = 64'hFBCB4F738D4D1CD8;  // message bytes 0-7
        message[4] = 64'hAA9F038A3F3DDEEA;  // message bytes 8-15
        message[5] = 64'h55AD35E857992C2A;  // message bytes 16-23
        message[6] = 64'h6A55BB57BF752EB2;  // message bytes 24-31
        message[7] = 64'h00000000000000C8;  // message bytes 32-32
        
        seed_r[0]  = 64'hFE85DDA650E02CC8;
        seed_r[1]  = 64'hB146F16A65D03DA6;
        seed_r[2]  = 64'h922C07C0AB910F88;
        
        // generated signature (unpacked format)
        // sig[0..7] = sig->r  (24 bytes)
        // sig[8..109] = s[0..101]
        sig[0]  = 24'h0FDAFD;
        sig[1]  = 24'hBCBB48;
        sig[2]  = 24'h374C69;
        sig[3]  = 24'h600CD9;
        sig[4]  = 24'h9AB14D;
        sig[5]  = 24'h81F2A3;
        sig[6]  = 24'h8929A6;
        sig[7]  = 24'h163C9B;
        sig[8]  = 24'h5E1534;
        sig[9]  = 24'h441B21;
        sig[10] = 24'h296164;
        sig[11] = 24'h59125E;
        sig[12] = 24'h596A33;
        sig[13] = 24'h0C6D03;
        sig[14] = 24'h005347;
        sig[15] = 24'h0A6264;
        sig[16] = 24'h420529;
        sig[17] = 24'h297C46;
        sig[18] = 24'h330F17;
        sig[19] = 24'h613763;
        sig[20] = 24'h3C121C;
        sig[21] = 24'h2C681D;
        sig[22] = 24'h1A5C08;
        sig[23] = 24'h40225B;
        sig[24] = 24'h287925;
        sig[25] = 24'h587910;
        sig[26] = 24'h52617B;
        sig[27] = 24'h127378;
        sig[28] = 24'h1D0917;
        sig[29] = 24'h0F5F1D;
        sig[30] = 24'h0F5A55;
        sig[31] = 24'h2A6669;
        sig[32] = 24'h282A0B;
        sig[33] = 24'h493060;
        sig[34] = 24'h7E404A;
        sig[35] = 24'h564720;
        sig[36] = 24'h532620;
        sig[37] = 24'h760D68;
        sig[38] = 24'h3B474A;
        sig[39] = 24'h27367A;
        sig[40] = 24'h187B71;
        sig[41] = 24'h164D66;
        sig[42] = 24'h793073;
        sig[43] = 24'h042535;
        sig[44] = 24'h6A605F;
        sig[45] = 24'h7B3A0A;
        sig[46] = 24'h7D597B;
        sig[47] = 24'h4A2849;
        sig[48] = 24'h02656B;
        sig[49] = 24'h331C14;
        sig[50] = 24'h2C4524;
        sig[51] = 24'h567A66;
        sig[52] = 24'h5C7230;
        sig[53] = 24'h647E26;
        sig[54] = 24'h19727D;
        sig[55] = 24'h3B5612;
        sig[56] = 24'h332D03;
        sig[57] = 24'h217678;
        sig[58] = 24'h15793D;
        sig[59] = 24'h00760F;
        sig[60] = 24'h656639;
        sig[61] = 24'h727363;
        sig[62] = 24'h692843;
        sig[63] = 24'h243C70;
        sig[64] = 24'h242D6C;
        sig[65] = 24'h096532;
        sig[66] = 24'h111829;
        sig[67] = 24'h614346;
        sig[68] = 24'h134204;
        sig[69] = 24'h095864;
        sig[70] = 24'h3F6651;
        sig[71] = 24'h231C74;
        sig[72] = 24'h2D482F;
        sig[73] = 24'h43776F;
        sig[74] = 24'h5D476F;
        sig[75] = 24'h3C360F;
        sig[76] = 24'h2F1836;
        sig[77] = 24'h6F7476;
        sig[78] = 24'h7B6634;
        sig[79] = 24'h1E4F3C;
        sig[80] = 24'h6B7E73;
        sig[81] = 24'h235C23;
        sig[82] = 24'h654F2F;
        sig[83] = 24'h2F3D6D;
        sig[84] = 24'h53104B;
        sig[85] = 24'h10627B;
        sig[86] = 24'h6D3066;
        sig[87] = 24'h0D7932;
        sig[88] = 24'h1F5806;
        sig[89] = 24'h320D27;
        sig[90] = 24'h3E3E5F;
        sig[91] = 24'h144241;
        sig[92] = 24'h124B3D;
        sig[93] = 24'h53505A;
        sig[94] = 24'h493933;
        sig[95] = 24'h59780C;
        sig[96] = 24'h41560F;
        sig[97] = 24'h414966;
        sig[98] = 24'h58424F;
        sig[99] = 24'h350C5D;
        sig[100] = 24'h655D24;
        sig[101] = 24'h62385F;
        sig[102] = 24'h375F3E;
        sig[103] = 24'h4B542A;
        sig[104] = 24'h3F262E;
        sig[105] = 24'h356A65;
        sig[106] = 24'h4A1128;
        sig[107] = 24'h371351;
        sig[108] = 24'h131022;
        sig[109] = 24'h59790A;
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
        for (i=0; i<=2; i=i+1) begin
            @(posedge clk);
            addr_ext = i;
            din_ext  = seed_sk[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_sk Finished ====");
        
        // Loading seed_pk
        $display("==== Load seed_pk Started ====");
        for (i=0; i<=2; i=i+1) begin
            @(posedge clk);
            addr_ext = i+3;
            din_ext  = seed_pk[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_pk Finished ====");
        
        // Loading seed_y
        $display("==== Load seed_y Started ====");
        for (i=0; i<=2; i=i+1) begin
            @(posedge clk);
            addr_ext = i+6;
            din_ext  = seed_y[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_y Finished ====");
        
        // Loading concatenated message with seed_pk
        $display("==== Load concatenated message Started ====");
        for (i=0; i<=7; i=i+1) begin
            @(posedge clk);
            addr_ext = i+9;
            din_ext  = message[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load concatenated message Finished ====");
        
        // Loading seed_r
        $display("==== Load seed_r Started ====");
        for (i=0; i<=2; i=i+1) begin
            @(posedge clk);
            addr_ext = i+17;
            din_ext  = seed_r[i];
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd1};
        end
        $display("==== Load seed_r Finished ====");
        
        @(posedge clk);
        $display("==== Load Input Data Finished ====");
        
        /*=======================================================================
        --  PHASE 2: Start Verify
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
        
        // Generating matrix Expand_mu (see address 0 to 21 of memory)
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd9, `OP'd13, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-256 for Expand_mu");
        
        /*================================================
        -- Loading sig_r into Memory (see addresses 22 to 131)
        =================================================*/
        
        $display("==== Load sig Started ====");
        for (i=0; i<=109; i=i+1) begin
            @(posedge clk);
            addr_ext = i+22;
            din_ext  = {{40'b0}, sig[i]}; 
            ins = {`RTYPE'd0, `IV'd0, `WE'd1, addr_ext, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd1, `TID'd1};
        end
        $display("==== Load sig Finished ====");
        @(posedge clk);
        @(posedge clk);
        
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
        
        // Start Buffering the mu and sig->r bytes for HASH (from addresses 0 to 29 comprising mu and sig->r)
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd16, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Buffering the mu and sig->r bytes for HASH");
        
        /*================================================
        -- Generating Hash(mu, sig->r, msg) ;
        =================================================*/
        $display("==== Start Generating HASH ====");
        @(posedge clk);
        
        // Generating SHAKE256 for Generating HASH(mu, sig->r, msg) (see address 132 to 157 of memory )
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd132, `ADDR'd0, `ADDR'd0, `OP'd15, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE256 for Generating HASH(mu, sig->r, msg)");
        
        
        for(j=0; j<78; j=j+1) 
        begin
            /*================================================
            -- Expand seed_pk
            =================================================*/
            $display("==== Start Expanding the Public Key (Expand_pk) ====");
            
            iv0         = 2*j;
            iv1         = (2*j) + 1'b1;
            ADDR_Pi3    = (26*26)*j; // M = 26 (offset of 676 = 26 x 26)
            T           = 5314 + j;
            U           = 5392 + j;
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Generating matrix Pi1 (see address 158 to 3083 of memory)
            ins = {`RTYPE'd3, iv0, `WE'd0, `ADDR'd158, `ADDR'd0, `ADDR'd3, `OP'd3, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-256 and RejSAMP (in-parallel) for Pi1 matrix generation");
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Generating matrix Pi2 (see address 3084 to 5059 of memory)
            ins = {`RTYPE'd3, iv1, `WE'd0, `ADDR'd3084, `ADDR'd0, `ADDR'd3, `OP'd4, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-256 and RejSAMP (in-parallel) for Pi2 matrix generation");
            $display("==== Finished Expanding the Public Key (Expand_pk) ====");
            
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
            
            // oil variables contain from address 106 to 131, t occupies 5060 to 5135
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd5060, `ADDR'd106, `ADDR'd3084, `OP'd19, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_M_dot_VECTOR_M(oil, Pi2[j], t) ;");
            
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
            
            // vinegar variables contain from address 30 to 105, u occupies 5136 to 5211
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd5136, `ADDR'd158, `ADDR'd30, `OP'd23, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_V_dot_VECTOR_V(vineger, Pi1[j], u) ;");
            
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
            
            // temp t+t stored in mem_2 from 52728 to 52803 (O*M*M = 78*26*26 = 52728)
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd52728, `ADDR'd5060, `ADDR'd5060, `OP'd9, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: t + t ");
            
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
            
            // t + u occupies 5212 to 5287
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd5212, `ADDR'd5136, `ADDR'd52728, `OP'd24, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: t + u ");
            
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
            
            // Pi3 contribution t occupies 5288 to 5313
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd5288, `ADDR'd106, ADDR_Pi3, `OP'd25, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_M_dot_VECTOR_M(oil, Pi3[j], t) ;");
            
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
            
            // T occupies 5314 to 5391
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, T, `ADDR'd5212, `ADDR'd30, `OP'd26, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_V_dot_VECTOR_V(vineger, tmp_v, t) ;");
            
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
            
            // U occupies 5392 to 5469
            ins = {`RTYPE'd3, `IV'd0, `WE'd0, U, `ADDR'd5288, `ADDR'd106, `OP'd27, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: VECTOR_M_dot_VECTOR_M(oil    , tmp_o, u) ;");
   
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
            
        // see address 0 to 77 of mem-2 for sum of overall addition of the computed vectors for msg comparison
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd5392, `ADDR'd5314, `OP'd28, `CDT'd0, `TID'd2}; 
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
        
        // Copying bytes (loading address 0 to 77 from mem-2 and store on mem-1 on addresses from 5470 to 5495)
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd5470, `ADDR'd0, `ADDR'd0, `OP'd17, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Copying Fq_add(t[QRUOV_perm(0)],u[QRUOV_perm(0)]) ; bytes to exact comparison with msg_i ");
        
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
        
        ins = {`RTYPE'd3, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd5470, `ADDR'd132, `OP'd30, `CDT'd0, `TID'd2}; 
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: Comparing msg_i ");

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
