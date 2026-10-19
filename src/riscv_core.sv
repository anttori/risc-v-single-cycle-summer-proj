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
	output logic [31:0] dmem_wdata,
	output logic [3:0] dmem_data_en
	
);

	// Internal signals
	logic RegWEn;		// Register write flag
	logic ASel;		// Selector for ALU op_a input Mux
	logic BSel;		// Selector for ALU op_b input Mux
	logic [1:0] WBSel;		// Selector for writeback Mux
	logic BrEq;
	logic BrLt;
	logic PCSel;
	logic BrUn;
	
	alu_sel_e ALUSel;		// ALU inst family
	alu_states ALUCtrl;		// ALU operation type
	imm_sel_e ImmSel;		// Imm Gen control signal
	
	
	// Controller instance 
	controller u_controller(
		.opcode(inst[6:0]),		// Bit cut-out straight from inst	
		.func3(inst[14:12]),
		.BrEq(BrEq),
		.BrLt(BrLt),
		
		.RegWEn(RegWEn),
		.ALUSel(ALUSel),
		.ASel(ASel), 	
		.BSel(BSel),
		.ImmSel(ImmSel),
		.MemRW(dmem_wen),
		.WBSel(WBSel),
		.PCSel(PCSel),
		.BrUn(BrUn)
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
		.ASel(ASel),
		.BSel(BSel),
		.ImmSel(ImmSel),
		.WBSel(WBSel),
		.MemRW(dmem_wen),
		.BrUn(BrUn),
		.PCSel(PCSel),
		
		.pc(pc),
		
		.dmem_addr(dmem_addr),
		.dmem_wdata(dmem_wdata),
		.dmem_data_en(dmem_data_en),
		
		.BrEq(BrEq),
		.BrLt(BrLt)
	);

	
endmodule