import riscv_pkg::*;

module datapath (
	
	input logic clk,
	input logic resetN,

	input logic [31:0] inst,		// Instruction
	
	input logic RegWEn,				// Register Write Enable flag
	input alu_states ALUCtrl,		// ALU state flag
	
	output logic [31:0] pc 		// Next instruction address
);
	
	logic [31:0] reg1_data;
	logic [31:0] reg2_data; 
	logic [31:0] alu_result;

	assign pc = 32'b0; 		// Temporary: pc zero assign 
	
	regfile u_regfile(
		.clk(clk),
		.resetN(resetN),
		.rs1(inst[19:15]),		// Bit cut-out straight from inst
		.rs2(inst[24:20]),
		.rd(inst[11:7]),
		.dataW(alu_result),		// Temporary: alu result straight to write data
		.RegWEn(RegWEn),
		.rs1_data(reg1_data),
		.rs2_data(reg2_data)
	);
	
	
	alu u_alu(
		.op_a(reg1_data),		// Temporary: regs data straight as ALU inputs
		.op_b(reg2_data),
		.ALUCtrl(ALUCtrl),
		.alu_out(alu_result)
	);	
	
	
endmodule