import riscv_pkg::*;

module controller(
	
	input logic [6:0] opcode,
	
	input logic [2:0] func3,
	
	
	output logic RegWEn,		// Register Write flag
	
	output alu_sel_e ALUSel,		// ALU inst family
	
	output logic BSel,		// Selector for ALU op_b input Mux
	
	output imm_sel_e ImmSel,		// Imm Gen control signal
	
	output logic MemRW,		// DMEM Read/Write flag
	
	output logic [1:0] WBSel		// Writeback Mux Selector
);

	always_comb begin
		
		// Default output values
		RegWEn = 1'b0;
		ALUSel = ALU_SEL_R;
		BSel = 1'b0;
		ImmSel = IMM_I;
		MemRW = 1'b0;
		WBSel = 2'b01; 	
		
		case(opcode)
			
			// R-Type: OP
			OPC_OP: begin
				RegWEn = 1'b1;
				ALUSel = ALU_SEL_R;
			end
			
			
			// I-Type: OP_IMM
			OPC_OP_IMM: begin
				RegWEn = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_I;
			end
			
			
			// I-Type: LOAD
			OPC_LOAD: begin
				ImmSel = IMM_I;
				RegWEn = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_LS;
				WBSel = 2'b00;
			end
			
			default:	;	
		
		endcase
	
	end

endmodule 