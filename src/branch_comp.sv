module branch_comp (
	input logic [31:0] data_a,
	input logic [31:0] data_b,
	
	input logic br_un,
	
	output logic br_eq,
	output logic br_lt
);


always_comb begin

	br_eq = (data_a == data_b); 	
	
	if(br_un) br_lt = (data_a < data_b);		// Unsigned comp		
	
	else br_lt = ($signed(data_a) < $signed(data_b));		// Signed comp
	
end

endmodule