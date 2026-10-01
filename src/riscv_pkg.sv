/*

	Global package file
	
	Stores states names
	
*/

package riscv_pkg;

	typedef enum logic { ALU_ADD, ALU_SUB } alu_states;
	
	typedef enum logic [3:0] { ALU_SEL_R, ALU_SEL_I, ALU_SEL_LS, ALU_SEL_B, ALU_SEL_J, ALU_SEL_U } alu_sel_states;

endpackage