import riscv_pkg::*;


module imm_gen(
	
	input logic [31:0] inst,		// Inst input signal
	
	input imm_sel_e ImmSel,		// Imm Sel control signal
	
	
	output logic [31:0] imm		// Generated Imm output
);


always_comb begin

	case(ImmSel)
	
		// I-Type, Load 
		IMM_I: imm = { {20{inst[31]}}, inst[31:20] };
		
		// S-Type
		IMM_S: imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };
		
		// B-Type
		IMM_B: imm = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };
		
		default: imm = '0;		// Default value
	
	endcase

end


endmodule