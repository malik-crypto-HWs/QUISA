`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Research-Lab:    CSIT @ Queen's University Belfast, Northern Ireland, UK
// Developer:       Malik Imran
//////////////////////////////////////////////////////////////////////////////////
module qruov_parameters (
    input   [3:0]  SECAP,       // SECAP (Security and Algorithm Parameters selector)
    output  [6:0]  q,           // modulus q
    output  [10:0] v,           // vinegar variable
    output  [7:0]  m,           // oil variable
    output  [3:0]  l,           // extension degree
    output  [10:0] n,           // message length
    output  [7:0]  N,           // total variables = v + o
    output  [7:0]  V,           // vinegar vars (same as v)
    output  [5:0]  M,           // number of equations (same as m)
    output  [16:0] tau1,        // tau_1
    output  [15:0] tau2,        // tau_2
    output  [8:0]  tau3,        // tau_3
    output  [7:0]  tau4         // tau_4
);
	
	/*===================================================================
	-- when SECAP == 4'd0              :	IDLE (not to do any thing)
	-- when SECAP == 4'd1  to 4'd4     :	load SL-I   parameters
	-- when SECAP == 4'd5  to 4'd8     :	load SL-III parameters
	-- when SECAP == 4'd9 to 4'd12     :	load SL-V   parameters
	====================================================================*/
	
	assign	q =  (SECAP == 4'd1 || SECAP == 4'd5 || SECAP == 4'd9) ? 7'd127 :
			     7'd0;
				
	assign	v =  (SECAP == 4'd1)  ? 11'd156  :
			     (SECAP == 4'd5)  ? 11'd228  :
			     (SECAP == 4'd9)  ? 11'd306  :
			     11'd0;
			
	assign	m =  (SECAP == 4'd1)  ? 8'd54  :
			     (SECAP == 4'd5)  ? 8'd78  :
			     (SECAP == 4'd9)  ? 8'd105 :
			     8'd0;
			
	assign	l =  (SECAP == 4'd1 || SECAP == 4'd5 || SECAP == 4'd9) ? 4'd3 :
			     4'd0;
			   
    // Auxiliary Parameters from Table 3 of the specification document of QU-ROV round-2
    assign n  = (SECAP == 4'd1)  ? 11'd210  :
                (SECAP == 4'd5)  ? 11'd306  :
                (SECAP == 4'd9)  ? 11'd411  :
                11'd0;

    assign N  = (SECAP == 4'd1)  ? 8'd70  :
                (SECAP == 4'd5)  ? 8'd102 :
                (SECAP == 4'd9)  ? 8'd137 :
                8'd0;
                
     assign	V =  (SECAP == 4'd1)  ? 8'd52  :
			     (SECAP == 4'd5)  ? 8'd76  :
			     (SECAP == 4'd9)  ? 8'd102 :
			     8'd0;
			
	assign	M =  (SECAP == 4'd1)  ? 6'd18 :
			     (SECAP == 4'd5)  ? 6'd26 :
			     (SECAP == 4'd9)  ? 6'd35 :
			     6'd0;
			    
    assign tau1 = (SECAP == 4'd1)? 17'd4267  :
                (SECAP == 4'd5)  ? 17'd9020  :
                (SECAP == 4'd9)  ? 17'd16144 :
                17'd0;
                
    assign tau2 = (SECAP == 4'd1)? 16'd2916  :
                (SECAP == 4'd5)  ? 16'd6123  :
                (SECAP == 4'd9)  ? 16'd11018 :
                16'd0;    
                
     assign tau3 = (SECAP == 4'd1)  ? 9'd192  :
                (SECAP == 4'd5)  ? 9'd283 :
                (SECAP == 4'd9)  ? 9'd380 :
                9'd0; 
    
      assign tau4 = (SECAP == 4'd1)  ? 8'd82  :
                (SECAP == 4'd5)  ? 8'd120 :
                (SECAP == 4'd9)  ? 8'd162 :
                8'd0; 
    
endmodule

