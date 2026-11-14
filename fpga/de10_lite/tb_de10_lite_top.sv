`timescale 1ns / 1ps

// Self-checking system testbench for de10_lite_top running fpga_test.
// Use a fast firmware build (-DANIM_STEP_ITERS=20) and run from a directory that
// contains it as fpga_test_sim.hex.
module tb_de10_lite_top;

	logic        clk50 = 1'b0;
	logic [1:0]  key   = 2'b11;
	logic [9:0]  sw    = 10'h000;
	wire  [9:0]  ledr;
	wire  [7:0]  hex0, hex1, hex2, hex3, hex4, hex5;

	int errors = 0;

	de10_lite_top #(
		.IMEM_INIT_FILE("fpga_test_sim.hex")
	) dut (
		.MAX10_CLK1_50 (clk50),
		.KEY           (key),
		.SW            (sw),
		.LEDR          (ledr),
		.HEX0          (hex0),
		.HEX1          (hex1),
		.HEX2          (hex2),
		.HEX3          (hex3),
		.HEX4          (hex4),
		.HEX5          (hex5)
	);

	always #10 clk50 = ~clk50;

	// Independent active-low 7-segment reference (HEX[6:0] = {g..a}, HEX[7] = DP)
	function automatic logic [7:0] seg_ref(input logic [3:0] v, input logic blank);
		logic [6:0] s;
		case (v)
			0: s = 7'h3F; 1: s = 7'h06; 2: s = 7'h5B; 3: s = 7'h4F;
			4: s = 7'h66; 5: s = 7'h6D; 6: s = 7'h7D; 7: s = 7'h07;
			8: s = 7'h7F; 9: s = 7'h6F; 10: s = 7'h77; 11: s = 7'h7C;
			12: s = 7'h39; 13: s = 7'h5E; 14: s = 7'h79; default: s = 7'h71;
		endcase
		return blank ? 8'hFF : {1'b1, ~s};
	endfunction

	// 'digits' holds six nibbles {HEX5..HEX0}; 'blank' bit i blanks HEXi
	task automatic check_display(input string name, input logic [9:0] exp_ledr,
	                             input logic [23:0] digits, input logic [5:0] blank);
		logic [7:0] exp_seg [6];
		for (int i = 0; i < 6; i++) exp_seg[i] = seg_ref(digits[4*i +: 4], blank[i]);

		if (ledr !== exp_ledr) begin
			errors++;
			$display("[FAIL] %s: LEDR=%03h expected %03h", name, ledr, exp_ledr);
		end
		if ({hex5, hex4, hex3, hex2, hex1, hex0} !== {exp_seg[5], exp_seg[4], exp_seg[3], exp_seg[2], exp_seg[1], exp_seg[0]}) begin
			errors++;
			$display("[FAIL] %s: HEX5..0=%02h %02h %02h %02h %02h %02h expected %02h %02h %02h %02h %02h %02h", name,
			         hex5, hex4, hex3, hex2, hex1, hex0,
			         exp_seg[5], exp_seg[4], exp_seg[3], exp_seg[2], exp_seg[1], exp_seg[0]);
		end
		else $display("[ OK ] %s: LEDR=%03h HEX5..0=%02h %02h %02h %02h %02h %02h", name, ledr, hex5, hex4, hex3, hex2, hex1, hex0);
	endtask

	// Phase 1 monitor: LEDR must step through the one-hot sequence 1,2,4,...,0x200
	logic [9:0] last_ledr = 10'h000;
	int         anim_idx  = 0;

	always @(ledr) begin
		if (key[0] && anim_idx < 10 && ledr !== 10'hxxx && ledr !== last_ledr) begin
			if (ledr !== (10'h001 << anim_idx)) begin
				errors++;
				$display("[FAIL] animation step %0d: LEDR=%03h", anim_idx, ledr);
			end
			anim_idx++;
		end
		last_ledr = ledr;
	end

	task automatic wait_core_cycles(input int n);
		repeat (2 * n) @(posedge clk50);
	endtask

	initial begin
		key = 2'b00;
		wait_core_cycles(4);
		check_display("reset", 10'h000, 24'h0, 6'h3F);
		key = 2'b11;

		// Phase 1 + 2 take well under 20k core cycles with the fast build
		wait_core_cycles(20000);
		if (anim_idx != 10) begin
			errors++;
			$display("[FAIL] animation produced %0d steps, expected 10", anim_idx);
		end

		// v[0] = 0x00C0FFEE, v[1] = 0xFEE1600D after decryption
		sw = 10'b00_0000_0000; wait_core_cycles(100);
		check_display("SW=00 v0 low24", 10'h200, 24'hC0FFEE, 6'b000000);

		sw = 10'b00_0000_0001; wait_core_cycles(100);
		check_display("SW=01 v0 top byte", 10'h200, 24'h000000, 6'b111100);

		sw = 10'b00_0000_0010; wait_core_cycles(100);
		check_display("SW=10 v1 low24", 10'h3FE, 24'hE1600D, 6'b000000);

		sw = 10'b00_0000_0011; wait_core_cycles(100);
		check_display("SW=11 v1 top byte", 10'h3FE, 24'h0000FE, 6'b111100);

		// Reset in the middle of operation clears the outputs and restarts the program
		key[0] = 1'b0; wait_core_cycles(4);
		check_display("reset again", 10'h000, 24'h0, 6'h3F);
		key[0] = 1'b1; wait_core_cycles(20000);
		sw = 10'b00_0000_0010; wait_core_cycles(100);
		check_display("after reset SW=10", 10'h3FE, 24'hE1600D, 6'b000000);

		if (errors == 0) $display("\n>>> [PASS] de10_lite_top system test passed <<<\n");
		else             $display("\n>>> [FAIL] %0d error(s) <<<\n", errors);
		$stop;
	end

endmodule
