import riscv_pkg::*;

module riscv_core (
	input logic clk,
	input logic resetN,
	
	// IMEM Interface
	input logic [31:0] inst,		// 32-bit instruction input from IMEM
	output logic [31:0] pc,		// 32-bit instruction address output
	
	// DMEM Interface
	input logic [31:0] dmem_data,
	output logic dmem_wen,
	output logic [31:0] dmem_addr,
	output logic [31:0] dmem_wdata
	
);

	// Internal signals
	logic RegWEn;		// Register write flag
	logic BSel;		// Selector for ALU op_b input Mux
	logic [1:0] WBSel;		// Selector for writeback Mux
	
	alu_sel_e ALUSel;		// ALU inst family
	alu_states ALUCtrl;		// ALU operation type
	imm_sel_e ImmSel;		// Imm Gen control signal
	
	
	assign dmem_wdata = 32'b0; 		// TEMP
	
	
	// Controller instance 
	controller u_controller(
		.opcode(inst[6:0]),		// Bit cut-out straight from inst	
		.func3(inst[14:12]),
		.RegWEn(RegWEn),
		.ALUSel(ALUSel),
		.BSel(BSel),
		.ImmSel(ImmSel),
		.MemRW(dmem_wen),
		.WBSel(WBSel)
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
		.dmem_data(dmem_data),
		
		.RegWEn(RegWEn),
		.ALUCtrl(ALUCtrl),
		.BSel(BSel),
		.ImmSel(ImmSel),
		.WBSel(WBSel),
		
		.pc(pc),
		.dmem_addr(dmem_addr)
	);

	
endmodule