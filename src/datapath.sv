import riscv_pkg::*;

module datapath (
	
	input logic clk,
	input logic resetN,

	input logic [31:0] inst,		// Instruction
	
	input logic [31:0] dmem_data,		// DMEM word input
	
	input logic RegWEn,				// Register Write Enable flag
	input alu_states ALUCtrl,		// ALU state flag
	input logic BSel,				// Selector for ALU op_b input mux
	input imm_sel_e ImmSel,		// Imm Gen control signal
	input logic [1:0] WBSel,		// Writeback mux selector
	input logic MemRW,		// DMEM Read/Write flag
	
	output logic [31:0] pc, 		// Next instruction address
	
	output logic [31:0] dmem_addr,		// DMEM Read/Write word address
	output logic [31:0] dmem_wdata,		// DMEM Data to store
	output logic [3:0] dmem_data_en 	// DMEM Write mask
);
	
	// Internal datapath signals
	logic [31:0] pc_plus_4;
	
	logic [31:0] reg1_data;
	logic [31:0] reg2_data; 
	logic [31:0] wb_data;
	
	logic [31:0] alu_result;

	logic [31:0] imm;
	
	logic [31:0] alu_op_b;
	
	logic [31:0] le_data;		// Load Extender writeback data

	
	always_comb begin
		// Next instruction address logic (PC+4)
		pc_plus_4 = pc + 32'h4;
		
		// ALU op_b mux
		alu_op_b = BSel ? imm : reg2_data;
		
		// ALU result is DMEM address
		dmem_addr = alu_result;		//CHECK THIS
	
		// Register File Writeback Mux
		case(WBSel)
			2'b01: wb_data = alu_result;		// 1: Data from ALU	
			2'b00: wb_data = le_data;		// 2: Data from DMEM
			// 2'b10: TODO		// 3: Reserved for JAL/JALR
			
			default: wb_data = alu_result;	
		endcase
	end

	
	// Program counter instance
	pc #(
		.BOOT_ADDR(32'h0)
	) u_pc (
		.clk(clk),
		.resetN(resetN),
		.pc_next(pc_plus_4),
		.pc_out(pc)
	);
	
	
	// Register File instance
	regfile u_regfile(
		.clk(clk),
		.resetN(resetN),
		.rs1(inst[19:15]),		// Bit cut-out straight from inst
		.rs2(inst[24:20]),
		.rd(inst[11:7]),
		.dataW(wb_data),
		.RegWEn(RegWEn),
		.rs1_data(reg1_data),
		.rs2_data(reg2_data)
	);
	
	
	// ALU instance
	alu u_alu(
		.op_a(reg1_data),		// Temporary: reg1 data straight as ALU op_a input 
		.op_b(alu_op_b),
		.ALUCtrl(ALUCtrl),
		.alu_out(alu_result)
	);	
	
	
	// Imm Gen instance
	imm_gen u_imm_gen(
		.inst(inst),
		.ImmSel(ImmSel),
		.imm(imm)
	);
	
	
	// Load Extender instance
	load_extender u_load_extender(
		.dmem_data(dmem_data),
		.addr(alu_result[1:0]),		
		.func3(inst[14:12]),		
		.le_data_out(le_data)
	);
	
	
	// Store Formatter instance
	store_formatter u_store_formatter(
		.data(reg2_data),
		.addr(alu_result[1:0]),
		.func3(inst[14:12]),
		.MemRW(MemRW),
		.dmem_wdata(dmem_wdata),
		.dmem_data_en(dmem_data_en)
	);
	
endmodule