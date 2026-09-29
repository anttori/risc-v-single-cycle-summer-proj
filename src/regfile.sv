module regfile ( 
	
	input logic clk,
	input logic resetN,
	
	input logic [4:0] rs1,		// Read reg 1
	input logic [4:0] rs2,		// Read reg 2
	input logic [4:0] rd,		// Write reg
	
	input logic [31:0] dataW,		// Data to write
	input logic RegWEn, 		// Flag allowing reg write
	
	output logic [31:0] rs1_data,		// Reg 1 data out
	output logic [31:0] rs2_data		// Reg 2 data out
);

	logic [31:0] registers [32];		// 32 Bit Registers array


	always_comb begin

		rs1_data = (rs1 == 5'h0) ? 32'b0 : registers[rs1];		// Asynch reg 1 data out assign
		rs2_data = (rs2 == 5'h0) ? 32'b0 : registers[rs2];		// Asynch reg 2 data out assign
		
	end


	always_ff @(posedge clk or negedge resetN) begin

		if(!resetN) begin
			// Reset all reg values to zero
			registers <= '{default: '0}; 
		end
		else begin
			
			if(RegWEn && rd != 5'h0) begin		// Check if write flag is up and reg number isn't zero
				registers[rd] <= dataW;						// Write data into a reg
			end
			
		end
		
	end

endmodule


