import riscv_pkg::*;

module alu_ctrl(
	
	input logic [2:0] func3, 
	input logic [6:0] func7,
	
	input alu_sel_e ALUSel,
	
	output alu_states alu_ctrl_out
);

	always_comb begin
	
		case(ALUSel)
			
			// R-Type
			ALU_SEL_R: begin
				
				case(func3)
				
					// ADD/SUB
					3'b000: alu_ctrl_out = func7[5] ? ALU_SUB : ALU_ADD;
					
					default: alu_ctrl_out = ALU_ADD;		// Temporary: Add for any R-type inst other than Add/Sub
				
				endcase
				
			end
			
			
			default: alu_ctrl_out = ALU_ADD;		// Temporary: Add for any inst other than R-type 
		
		endcase
	
	
	end


endmodule