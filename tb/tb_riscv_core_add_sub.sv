`timescale 1ns / 1ps

import riscv_pkg::*;


module tb_riscv_core_add_sub ();

// Risc V Core interface signals
logic clk;
logic resetN;
logic [31:0] inst;
logic [31:0] pc;

// Test instructions array (IMEM emulation)
logic [31:0] imem [0:7];

// add x4, x1, x2
assign imem[0] = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd4, 7'b0110011};
// sub x5, x2, x3
assign imem[1] = {7'b0100000, 5'd3, 5'd2, 3'b000, 5'd5, 7'b0110011};
// add x6, x4, x5
assign imem[2] = {7'b0000000, 5'd5, 5'd4, 3'b000, 5'd6, 7'b0110011};
// add x0, x1, x2
assign imem[3] = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd0, 7'b0110011};
// add x0, x0, x0 (nop)
assign imem[4] = {7'b0000000, 5'd0, 5'd0, 3'b000, 5'd0, 7'b0110011};
// Unused memory space (NOPs)
assign imem[5] = imem[4];
assign imem[6] = imem[4];
assign imem[7] = imem[4];


assign inst = imem[pc[31:2]];


// Device under test Instantiation
riscv_core u_riscv_core(
	.clk(clk),
	.resetN(resetN),
	.inst(inst),
	.pc(pc)
);


// Clock Generator
initial begin
	clk = 1'b0;
	forever #10 clk = ~clk;
end


// Main test
initial begin
	resetN = 1'b0;
	repeat (2) @(posedge clk);
	
	#1;		// Wait 1 ns to avoid RC
	resetN = 1'b1;

	// Emulate loading initial register values
	u_riscv_core.u_datapath.u_regfile.registers[1] = 32'd10; // x1 = 10
	u_riscv_core.u_datapath.u_regfile.registers[2] = 32'd25; // x2 = 25
	u_riscv_core.u_datapath.u_regfile.registers[3] = 32'd7;  // x3 = 7

	
	// Wait 1 cycle for inst[0] execution
	@(posedge clk);
	#1;		// Wait 1 ns to avoid RC

	// Check inst[0] exec & pc incrementation
	// add x4, x1, x2;
	assert(u_riscv_core.u_datapath.u_regfile.registers[4] === 32'd35 && u_riscv_core.pc === 32'd4)
	  $display("[PASS] Inst[0]: ADD: x1 + x2 = x4 (%0d) & PC=(%0d)",
				  u_riscv_core.u_datapath.u_regfile.registers[4], u_riscv_core.pc);
	else begin
	  $error("[FAIL] Inst[0] failed! Got x4=%0d, pc=%0d",
				u_riscv_core.u_datapath.u_regfile.registers[4], u_riscv_core.pc);
	end
	
	
	// Wait 1 cycle for inst[1] execution
	@(posedge clk);
	#1;		// Wait 1 ns to avoid RC

	// Check inst[1] exec & pc incrementation
	// sub x5, x2, x3
	assert(u_riscv_core.u_datapath.u_regfile.registers[5] === 32'd18 && u_riscv_core.pc === 32'd8)
	  $display("[PASS] Inst[1]: SUB: x2 - x3 = x5 (%0d) & PC=(%0d)",
				  u_riscv_core.u_datapath.u_regfile.registers[5], u_riscv_core.pc);
	else begin
	  $error("[FAIL] Inst[1] failed! Got x5=%0d, pc=%0d",
				u_riscv_core.u_datapath.u_regfile.registers[5], u_riscv_core.pc);
	end
	
	
	// Wait 1 cycle for inst[2] execution
	@(posedge clk);
	#1;		// Wait 1 ns to avoid RC

	// Check inst[2] exec & pc incrementation
	// add x6, x4, x5
	assert(u_riscv_core.u_datapath.u_regfile.registers[6] === 32'd53 && u_riscv_core.pc === 32'd12)
	  $display("[PASS] Inst[2]: ADD: x4 + x5 = x6 (%0d) & PC=(%0d)",
				  u_riscv_core.u_datapath.u_regfile.registers[6], u_riscv_core.pc);
	else begin
	  $error("[FAIL] Inst[2] failed! Got x6=%0d, pc=%0d",
				u_riscv_core.u_datapath.u_regfile.registers[6], u_riscv_core.pc);
	end
	
	
	// Wait 1 cycle for inst[3] execution
	@(posedge clk);
	#1;		// Wait 1 ns to avoid RC

	// Check inst[3] exec & pc incrementation
	// add x0, x1, x2
	assert(u_riscv_core.u_datapath.u_regfile.registers[0] === 32'd0 && u_riscv_core.pc === 32'd16)
	  $display("[PASS] Inst[3]: ADD: x1 + x2 = x0 (%0d) & PC=(%0d)",
				  u_riscv_core.u_datapath.u_regfile.registers[0], u_riscv_core.pc);
	else begin
	  $error("[FAIL] Inst[3] failed! Got x0=%0d, pc=%0d",
				u_riscv_core.u_datapath.u_regfile.registers[0], u_riscv_core.pc);
	end
	
	
	// Wait 1 cycle for inst[4] execution
	@(posedge clk);
	#1;		// Wait 1 ns to avoid RC

	// Check inst[4] exec & pc incrementation
	// add x0, x0, x0 (nop)
	assert(u_riscv_core.u_datapath.u_regfile.registers[0] === 32'd0 && u_riscv_core.pc === 32'd20)
	  $display("[PASS] Inst[4]: ADD: x0 + x0 = x0 (%0d) & PC=(%0d)",
				  u_riscv_core.u_datapath.u_regfile.registers[0], u_riscv_core.pc);
	else begin
	  $error("[FAIL] Inst[4] failed! Got x0=%0d, pc=%0d",
				u_riscv_core.u_datapath.u_regfile.registers[0], u_riscv_core.pc);
	end
	
	
	// Finish simulation
	#10;
	$display("\n All tests passed!");
	$stop;
	
end

endmodule
