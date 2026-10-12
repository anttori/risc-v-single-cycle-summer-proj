import riscv_pkg::*;


module imm_gen(
	
	input logic [31:0] inst,		// Inst input signal
	
	input imm_sel_e immSel,		// Imm Sel control signal
	
	
	output logic [31:0] imm		// Generated Imm output
);


always_comb begin

	case(immSel)
	
		// I-Type 
		IMM_I: imm_out = { 20{imm[31]}, imm[31:20] };
		
		default: imm = '0;		// Default value
	
	endcase

end


endmodule