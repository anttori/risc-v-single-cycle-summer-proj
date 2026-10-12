/*

	Global package file
	
	Stores states names
	
*/

package riscv_pkg;

	typedef enum logic [3:0] { ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU, ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND} alu_states;
	
	typedef enum logic [3:0] { ALU_SEL_R, ALU_SEL_I, ALU_SEL_LS, ALU_SEL_B, ALU_SEL_J, ALU_SEL_U } alu_sel_e;
	
	typedef enum logic [6:0] {
		OPC_OP = 7'b0110011,
		OPC_OP_IMM = 7'b0010011,
		OPC_LOAD = 7'b0000011,
		OPC_STORE = 7'b0100011,
		OPC_BRANCH = 7'b1100011,
		OPC_JALR = 7'b1100111,
		OPC_JAL = 7'b1101111,
		OPC_LUI = 7'b0110111,
		OPC_AUIPC = 7'b1110111,
		OPC_SYSTEM = 7'b1110011
	} opcode_e;

endpackage