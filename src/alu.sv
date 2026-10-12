import riscv_pkg::*;

module alu (

	input logic [31:0] op_a,		// input operand A
	input logic [31:0] op_b,		// input operand B
	
	input alu_states ALUCtrl,		// ALU control signal
	
	
	output logic [31:0] alu_out			// ALU result output
);

	always_comb begin

		case(ALUCtrl)
		
			ALU_ADD: alu_out = op_a + op_b;		// Addition
		
			ALU_SUB: alu_out = op_a - op_b;		// Subtraction
			
			
			// According to Risc-V standards, only 5 lower bits of op_b are used as shift size. 
			// Shifting more than 31 bits is meaningless in 32 bit architecture.
			
			ALU_SLL: alu_out = op_a << op_b[4:0];		// Shift Left Logical
			
			ALU_SRL: alu_out = op_a >> op_b[4:0];		// Shift Right Logical
			
			ALU_SRA: alu_out = $signed(op_a) >>> op_b[4:0];		// Shift Right Arithmetic
			
			
			ALU_SLT: alu_out = {31'b0, $signed(op_a) < $signed(op_b)};		// Set Less Than (signed)
			
			ALU_SLTU: alu_out = {31'b0, op_a < op_b};		// Set Less Than (unsigned)
			
			ALU_XOR: alu_out = op_a ^ op_b;		// Bitwise XOR
			
			ALU_OR: alu_out = op_a | op_b;		// Bitwise OR
			
			ALU_AND: alu_out = op_a & op_b;		// Bitwise AND
			
			
			default: alu_out = '0;		// Default
		
		endcase

	end
	
endmodule