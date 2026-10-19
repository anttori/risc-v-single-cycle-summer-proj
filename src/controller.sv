import riscv_pkg::*;

module controller(
	
	input logic [6:0] opcode,
	input logic [2:0] func3,
	
	input logic BrEq,
	input logic BrLt,
	
	
	output logic RegWEn,		// Register Write flag
	
	output alu_sel_e ALUSel,		// ALU inst family
	
	output logic ASel,		// Selector for ALU op_a input Mux
	
	output logic BSel,		// Selector for ALU op_b input Mux
	
	output imm_sel_e ImmSel,		// Imm Gen control signal
	
	output logic MemRW,		// DMEM Read/Write flag
	
	output logic [1:0] WBSel,		// Writeback Mux Selector
	
	output logic PCSel,		// Selector for PC input Mux
	
	output logic BrUn		// Branch unsigned comparison flag
);

	always_comb begin
		
		// Default output values
		RegWEn = 1'b0;
		ALUSel = ALU_SEL_R;
		ASel = 1'b0;
		BSel = 1'b0;
		ImmSel = IMM_I;
		MemRW = 1'b0;
		WBSel = 2'b01; 	
		PCSel = 1'b0;
		BrUn = 1'b0;
		
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
			
			
			// I-Type: JALR
			OPC_JALR: begin
				ImmSel = IMM_I;
				RegWEn = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_I;
				WBSel = 2'b10;
				PCSel = 1'b1;
			end
			
			
			// S-Type
			OPC_STORE: begin
				ImmSel = IMM_S;
				RegWEn = 1'b0;
				ALUSel = ALU_SEL_LS;
				BSel = 1'b1;
				MemRW = 1'b1;
			end
			
			
			// B-Type			
			OPC_BRANCH: begin
				ImmSel = IMM_B;
				ASel = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_B;
				
				case(func3) 
					// BEQ
					3'b000: PCSel = BrEq;
					
					// BNE
					3'b001: PCSel = ~BrEq;
					
					// BLT
					3'b100: PCSel = BrLt;
					
					// BGE
					3'b101: PCSel = ~BrLt;
					
					//BLTU
					3'b110: begin
						BrUn = 1'b1;
						PCSel = BrLt;
					end
					
					//BGEU
					3'b111: begin
						BrUn = 1'b1;
						PCSel = ~BrLt;
					end
					
					default: ;
				endcase
				
			end 
			
			
			// J-Type
			OPC_JAL: begin
				PCSel = 1'b1;
				ImmSel = IMM_J;
				RegWEn = 1'b1;
				ASel = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_J;
				WBSel = 2'b10;
			end
			
			
			// U-Type: LUI
			OPC_LUI: begin
				PCSel = 1'b0;
				ImmSel = IMM_U;
				RegWEn = 1'b1;
				BSel = 1'b1;
				ALUSel = ALU_SEL_U;
				WBSel = 2'b01;
			end
			
			default:	;	
		
		endcase
	
	end

endmodule 