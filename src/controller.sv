import riscv_pkg::*;

module controller(
	
	input logic [6:0] opcode,
	
	input logic [2:0] func3,
	
	
	output logic RegWEn,		// Register Write flag
	
	output alu_sel_e ALUSel,		// ALU inst family
	
	output logic BSel,		// Selector for ALU op_b input Mux
	
	output imm_sel_e ImmSel		// Imm Gen control signal
);

	always_comb begin
		
		// Default output values
		RegWEn = 1'b0;
		ALUSel = ALU_SEL_R;
		BSel = 1'b0;
		ImmSel = IMM_I;
		
		case(opcode)
			
			// R-Type
			OPC_OP: begin
				RegWEn = 1'b1;
				ALUSel = ALU_SEL_R;
			end
			
			OPC_OP_IMM: begin
				RegWEn = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_I;
			end
		
			default:	;	
		
		endcase
	
	end

endmodule 