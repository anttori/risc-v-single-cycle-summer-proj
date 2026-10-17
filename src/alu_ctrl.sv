import riscv_pkg::*;

module alu_ctrl(
	
	input logic [2:0] func3, 
	input logic [6:0] func7,
	
	input alu_sel_e ALUSel,
	
	output alu_states alu_ctrl_out
);

	always_comb begin
	
		alu_ctrl_out = ALU_ADD;		// default value
	
		case(ALUSel)
			
			// R-Type
			ALU_SEL_R: begin
				case(func3)
				
					// ADD/SUB
					3'b000: alu_ctrl_out = func7[5] ? ALU_SUB : ALU_ADD;
					
					// SLL
					3'b001: alu_ctrl_out = ALU_SLL;
					
					// SLT
					3'b010: alu_ctrl_out = ALU_SLT;
					
					// SLTU
					3'b011: alu_ctrl_out = ALU_SLTU;
					
					// XOR
					3'b100: alu_ctrl_out = ALU_XOR;
					
					// SRL/SRA
					3'b101: alu_ctrl_out = func7[5] ? ALU_SRA : ALU_SRL;
					
					// OR
					3'b110: alu_ctrl_out = ALU_OR;
					
					// AND
					3'b111: alu_ctrl_out = ALU_AND;
				
				endcase
				
			end
			
			
			// I-Type: OP_IMM
			ALU_SEL_I: begin			
				case(func3)
					
					// ADD
					3'b000: alu_ctrl_out = ALU_ADD;
					
					// SLL
					3'b001: alu_ctrl_out = ALU_SLL;
					
					// SLT
					3'b010: alu_ctrl_out = ALU_SLT;
					
					// SLTU
					3'b011: alu_ctrl_out = ALU_SLTU;
					
					// XOR
					3'b100: alu_ctrl_out = ALU_XOR;
					
					// SRL/SRA
					3'b101: alu_ctrl_out = func7[5] ? ALU_SRA : ALU_SRL;
					
					// OR
					3'b110: alu_ctrl_out = ALU_OR;
					
					// AND
					3'b111: alu_ctrl_out = ALU_AND;
					
					default: alu_ctrl_out = ALU_ADD;
					
				endcase
				
			end
			
			
			// I-Type: LOAD/STORE
			ALU_SEL_LS: begin				
				alu_ctrl_out = ALU_ADD;
			end
			
			
			default: alu_ctrl_out = ALU_ADD;		// Temporary: Add for any inst other than R-type 
		
		endcase
	
	
	end


endmodule