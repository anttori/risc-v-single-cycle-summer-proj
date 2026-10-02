import riscv_pkg::*;

module controller(
	
	input logic [6:0] opcode,
	input logic [2:0] func3,
	
	output logic RegWEn,		// Register Write flag
	output alu_sel_e ALUSel		// ALU inst family
);

	always_comb begin
		
		// Default output values
		RegWEn = 1'b0;
		ALUSel = ALU_SEL_R;
		
		case(opcode)
			
			// R-Type
			OPC_OP: begin
				RegWEn = 1'b1;
				ALUSel = ALU_SEL_R;
			end
		
			default:	;	
		
		endcase
	
	end

endmodule 