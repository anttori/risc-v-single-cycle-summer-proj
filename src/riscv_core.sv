import riscv_pkg::*;

module riscv_core (
	input logic clk,
	input logic resetN,
	
	input logic [31:0] inst,		// 32-bit instruction input from IMEM
	
	output logic [31:0] pc		// 32-bit instruction address output
);

	// Internal signals
	logic RegWEn;		// Register write flag
	alu_sel_e ALUSel;		// ALU inst family
	alu_states ALUCtrl;		// ALU operation type
	logic BSel;		// Selector for ALU op_b input mux
	imm_sel_e ImmSel;		// Imm Gen control signal
	
	
	// Controller instance 
	controller u_controller(
		.opcode(inst[6:0]),		// Bit cut-out straight from inst	
		.func3(inst[14:12]),
		.RegWEn(RegWEn),
		.ALUSel(ALUSel),
		.BSel(BSel),
		.ImmSel(ImmSel)
	);
	
	
	// ALU Controller instance
	alu_ctrl u_alu_ctrl(
		.func3(inst[14:12]),
		.func7(inst[31:25]),
		.ALUSel(ALUSel),
		.alu_ctrl_out(ALUCtrl)
	);
	
	
	// Datapath instance
	datapath u_datapath(
		.clk(clk),
		.resetN(resetN),
		.inst(inst),
		
		.RegWEn(RegWEn),
		.ALUCtrl(ALUCtrl),
		.BSel(BSel),
		.ImmSel(ImmSel),
		
		.pc(pc)
	);

	
endmodule