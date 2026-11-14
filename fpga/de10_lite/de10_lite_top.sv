// Top level for the Terasic DE10-Lite (MAX 10, 10M50DAF484C7G).
//
// RV32I single-cycle core + IMEM + DMEM + MMIO. Core clock = 25 MHz (50 MHz / 2).
//
// Data address map:
//   0x0000_0C00 - 0x0000_0FFF  DMEM (1 KB, top of the 4 KB data window; stack top = 0x1000)
//   0x0000_1000 - 0x0000_100F  MMIO (see de10_lite_mmio.sv)
//   anything else              reads as 0, writes ignored
module de10_lite_top #(
	parameter int IMEM_WORDS = 512,
	parameter IMEM_INIT_FILE = "fpga_test.hex",
	parameter int DMEM_WORDS = 256,
	parameter logic [31:0] DMEM_BASE = 32'h0000_0C00
)(
	input  logic        MAX10_CLK1_50,
	input  logic [1:0]  KEY,		// KEY[0]: active-low reset, KEY[1]: unused
	input  logic [9:0]  SW,
	output logic [9:0]  LEDR,
	output logic [7:0]  HEX0,
	output logic [7:0]  HEX1,
	output logic [7:0]  HEX2,
	output logic [7:0]  HEX3,
	output logic [7:0]  HEX4,
	output logic [7:0]  HEX5
);

	localparam int DMEM_AW = $clog2(DMEM_WORDS);

	// ---------------------------------------------------------------
	// Clock divider: 50 MHz -> 25 MHz
	// ---------------------------------------------------------------
	logic clk25 = 1'b0;

	always_ff @(posedge MAX10_CLK1_50) clk25 <= ~clk25;

	// ---------------------------------------------------------------
	// Reset: KEY[0] asserts asynchronously, releases synchronously
	// ---------------------------------------------------------------
	logic [1:0] rst_sync;
	logic       resetN;

	always_ff @(posedge clk25 or negedge KEY[0]) begin
		if (!KEY[0]) rst_sync <= 2'b00;
		else         rst_sync <= {rst_sync[0], 1'b1};
	end

	assign resetN = rst_sync[1];

	// ---------------------------------------------------------------
	// Core and memories
	// ---------------------------------------------------------------
	logic [31:0] pc, inst;
	logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
	logic [3:0]  dmem_be;
	logic        dmem_wen;

	riscv_core u_core (
		.clk          (clk25),
		.resetN       (resetN),
		.inst         (inst),
		.pc           (pc),
		.dmem_data    (dmem_rdata),
		.dmem_wen     (dmem_wen),
		.dmem_addr    (dmem_addr),
		.dmem_wdata   (dmem_wdata),
		.dmem_data_en (dmem_be)
	);

	fpga_imem #(
		.WORDS     (IMEM_WORDS),
		.INIT_FILE (IMEM_INIT_FILE)
	) u_imem (
		.pc   (pc),
		.inst (inst)
	);

	// ---------------------------------------------------------------
	// Data bus address decoding
	// ---------------------------------------------------------------
	logic        ram_sel, mmio_sel;
	logic [31:0] ram_rdata, mmio_rdata;

	assign ram_sel = (dmem_addr[31:DMEM_AW+2] == DMEM_BASE[31:DMEM_AW+2]);

	fpga_dmem #(
		.WORDS (DMEM_WORDS)
	) u_dmem (
		.clk   (clk25),
		.we    (dmem_wen && ram_sel),
		.be    (dmem_be),
		.addr  (dmem_addr),
		.wdata (dmem_wdata),
		.rdata (ram_rdata)
	);

	// Read data mux: the core always sees the selected target's data
	always_comb begin
		if (ram_sel)       dmem_rdata = ram_rdata;
		else if (mmio_sel) dmem_rdata = mmio_rdata;
		else               dmem_rdata = 32'h0;
	end

	// ---------------------------------------------------------------
	// MMIO
	// ---------------------------------------------------------------
	logic [23:0] hex_value;
	logic [5:0]  hex_blank;

	de10_lite_mmio u_mmio (
		.clk       (clk25),
		.resetN    (resetN),
		.wen       (dmem_wen),
		.be        (dmem_be),
		.addr      (dmem_addr),
		.wdata     (dmem_wdata),
		.rdata     (mmio_rdata),
		.sel       (mmio_sel),
		.sw        (SW),
		.ledr      (LEDR),
		.hex_value (hex_value),
		.hex_blank (hex_blank)
	);

	// ---------------------------------------------------------------
	// 7-segment decoders (active-low outputs)
	// ---------------------------------------------------------------
	logic [7:0] hex_seg_n [6];

	genvar i;

	generate
		for (i = 0; i < 6; i++) begin : g_hex
			hex7seg u_hex7seg (
				.value (hex_value[4*i +: 4]),
				.blank (hex_blank[i]),
				.seg_n (hex_seg_n[i])
			);
		end
	endgenerate

	assign HEX0 = hex_seg_n[0];
	assign HEX1 = hex_seg_n[1];
	assign HEX2 = hex_seg_n[2];
	assign HEX3 = hex_seg_n[3];
	assign HEX4 = hex_seg_n[4];
	assign HEX5 = hex_seg_n[5];

endmodule
