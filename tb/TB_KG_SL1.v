`timescale 1ns / 1ps
`include"signal_sizes.vh"

/*=======================================================================
--  The generated PUBLIC-KEY resides at addresses 5122--5445 and 5770--6093
=========================================================================*/

module TB_KG_SL1;

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
    reg [`ADDR-1:0] i;
    reg [`ADDR-1:0] addr_ext;
    
    reg [`ADDR-1:0] addr_init_Pi3;
    
    integer j;
    reg [`IV-1:0] iv0, iv1;


    initial begin
        seed_sk[0] = 64'hAA9476B0A035997C;
        seed_sk[1] = 64'hDD1A6BDBE4106D0C;
        seed_sk[2] = 64'h5EB54C6514222891;
        seed_sk[3] = 64'h4D601939D5AC2C7C;
        
        seed_pk[0] = 64'h5EB54C6514222891;
        seed_pk[1] = 64'h4D601939D5AC2C7C;
        seed_pk[2] = 64'h0000016D35976060;
        seed_pk[3] = 64'h00007FF794120058;
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
        rst = 0; 
        
        @(posedge clk);
        algo_select = 2'd1;    
        
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
        
        @(posedge clk);
        $display("==== Load Input Data Finished ====");
        
        /*=======================================================================
        --  PHASE 2: Start KeyGen
        =========================================================================*/
                
        /*================================================
        -- Expand seed_sk
        =================================================*/
        $display("==== Start Expanding the Secret Key (Expand_sk) ====");
        // Generating matrix SD (see address 0 to 935 of memory (2808/3 = 936))
        @(posedge clk);
        ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd2, `CDT'd0, `TID'd2}; // operating shake-128 in parallel with sampling rejection (write from addr 4 to 925)
        @(posedge clk); 
        wait (TOD == `TOD'd1);
        $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for SD matrix generation");
        
        @(posedge clk);
        $display("==== Finished Expanding the Secret Key (Expand_sk) ====");
        //$finish;
        
        /*================================================
        -- Expand seed_pk
        =================================================*/
        $display("==== Start Expanding the Public Key (Expand_pk) ====");
        
        for(j=0; j<54; j=j+1) begin
        
            iv0 = 2*j;
            iv1 = (2*j) + 1'b1;
            addr_init_Pi3 = 936 + (j*324);
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            
            // Generating matrix Pi1 (see address 936 to 2313 of memory (4134/3=1378))
            ins = {`RTYPE'd2, iv0, `WE'd0, `ADDR'd936, `ADDR'd0, `ADDR'd4, `OP'd3, `CDT'd0, `TID'd2}; // before here, `IV'd0 was
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
            
            // Generating matrix Pi2 (see address 2314 to 3249 of memory (writing 2808 bytes))
            ins = {`RTYPE'd2, iv1, `WE'd0, `ADDR'd2314, `ADDR'd0, `ADDR'd4, `OP'd4, `CDT'd0, `TID'd0}; // before here, `IV'd1 was
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("DONE: SHAKE-128 and RejSAMP (in-parallel) for Pi2 matrix generation");
            //$finish;
    
            $display("==== Finished Expanding the Public Key (Expand_pk) ====");
            
            $display("==== Start Executing the MATRIX_MxV_MUL_SYMMETRIC_MATRIX_VxV (SdT,Pi1,TMP); ====");
            
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing MATRIX_MxV_MUL_SYMMETRIC_MATRIX_VxV (SdT,Pi1,TMP); (see addresses from 3250 to 4185 )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd3250, `ADDR'd936, `ADDR'd0, `OP'd5, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the MATRIX_MxV_MUL_SYMMETRIC_MATRIX_VxV (SdT,Pi1,TMP); ====");
            //$finish;
            
            $display("Start Executing the MATRIX_SUB_MxV(Pi2T,TMP,TMP) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing MATRIX_SUB_MxV(Pi2T,TMP,TMP) ; (write in mem2 from addresses 0 to 935)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd3250, `ADDR'd2314, `OP'd6, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the MATRIX_SUB_MxV(Pi2T,TMP,TMP) ; ====");
            //$finish;
            
            $display("Start Executing the MATRIX_MUL_MxV_VxM(TMP,Sd,P3[i]) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing MATRIX_MUL_MxV_VxM(TMP,Sd,P3[i]) ; (write from 4186 to 4509 )
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd4186, `ADDR'd0, `ADDR'd0, `OP'd7, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the MATRIX_MUL_MxV_VxM(TMP,Sd,P3[i]) ; ====");
            //$finish;
            
            $display("Start Executing the MATRIX_MUL_ADD_MxV_VxM(SdT,Pi2,P3[i]) ; ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing MATRIX_MUL_ADD_MxV_VxM(SdT,Pi2,P3[i]) ; (write from 4510 to 4833)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, `ADDR'd4510, `ADDR'd2314, `ADDR'd0, `OP'd8, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the MATRIX_MUL_ADD_MxV_VxM(SdT,Pi2,P3[i]) ; ====");
            //$finish;
            
            $display("Start Executing the Remaining Pi,3 Bytes (last operation, i.e., addition) ====");
            // reset the internal blocks
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2}; 
            @(posedge clk);
            ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd2};
            @(posedge clk);
            
            // Executing last addition (write in mem2 addresses from 936 to 18,431)
            ins = {`RTYPE'd2, `IV'd0, `WE'd0, addr_init_Pi3, `ADDR'd4186, `ADDR'd4510, `OP'd9, `CDT'd0, `TID'd2}; 
            @(posedge clk); 
            wait (TOD == `TOD'd1);
            $display("Finished Executing the Remaining Pi,3 Bytes (last operation, i.e., addition) ====");
            //$finish;
        end
    
    $display("KeyGen() has been finished --> Pi3 for Verify() block is in mem2 from addresses 936 to 18,431 ====");    
    @(posedge clk);
    ins = {`RTYPE'd0, `IV'd0, `WE'd0, `ADDR'd0, `ADDR'd0, `ADDR'd0, `OP'd0, `CDT'd0, `TID'd0};
    $finish;
        
    end
    
    

endmodule
