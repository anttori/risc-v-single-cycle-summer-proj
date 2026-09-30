import riscv_pkg::*;

module alu (

	input logic [31:0] op_a,		// input operand A
	input logic [31:0] op_b,		// input operand B
	
	input alu_states ALUCtrl,		// ALU state flag
	
	
	output logic [31:0] alu_out			// ALU result output
);

	always_comb begin

		case(ALUCtrl)
		
			ALU_SUB: alu_out = op_a - op_b;		// Substraction
			
			default: alu_out = op_a + op_b;		// Addition
		
		endcase

	end
	
endmodule