// Memory-mapped I/O block of the DE10-Lite system.
//
//   0x0000_1000  W  LEDR[9:0]        (active-high)
//   0x0000_1004  W  HEX value[23:0]  (6 hex digits, HEX5..HEX0)
//   0x0000_1008  W  HEX_BLANK[5:0]   (1 = digit off)
//   0x0000_100C  R  SW[9:0]          (zero-extended)
//
// Writes honour the byte enables. Reads of the write-only registers return 0.
// 'sel' is asserted for any access inside the 16-byte MMIO window.
module de10_lite_mmio (
	input  logic        clk,
	input  logic        resetN,

	// Core data bus
	input  logic        wen,
	input  logic [3:0]  be,
	input  logic [31:0] addr,
	input  logic [31:0] wdata,
	output logic [31:0] rdata,
	output logic        sel,

	// Board side
	input  logic [9:0]  sw,
	output logic [9:0]  ledr,
	output logic [23:0] hex_value,
	output logic [5:0]  hex_blank
);

	localparam logic [31:0] MMIO_BASE = 32'h0000_1000;

	localparam logic [1:0] REG_LEDR  = 2'd0;	// 0x1000
	localparam logic [1:0] REG_HEX   = 2'd1;	// 0x1004
	localparam logic [1:0] REG_BLANK = 2'd2;	// 0x1008
	localparam logic [1:0] REG_SW    = 2'd3;	// 0x100C

	logic [1:0]  reg_idx;
	logic [31:0] ledr_ext, hex_ext, blank_ext;
	logic [31:0] ledr_nxt, hex_nxt, blank_nxt;
	logic [9:0]  sw_meta, sw_sync;

	assign sel     = (addr[31:4] == MMIO_BASE[31:4]);
	assign reg_idx = addr[3:2];

	// Zero-extended register views merged with the new data per byte enable
	assign ledr_ext  = {22'b0, ledr};
	assign hex_ext   = {8'b0, hex_value};
	assign blank_ext = {26'b0, hex_blank};

	always_comb begin
		for (int b = 0; b < 4; b++) begin
			ledr_nxt [8*b +: 8] = be[b] ? wdata[8*b +: 8] : ledr_ext [8*b +: 8];
			hex_nxt  [8*b +: 8] = be[b] ? wdata[8*b +: 8] : hex_ext  [8*b +: 8];
			blank_nxt[8*b +: 8] = be[b] ? wdata[8*b +: 8] : blank_ext[8*b +: 8];
		end
	end

	// Slide switches are asynchronous to the core clock
	always_ff @(posedge clk) begin
		sw_meta <= sw;
		sw_sync <= sw_meta;
	end

	always_ff @(posedge clk or negedge resetN) begin
		if (!resetN) begin
			ledr      <= 10'h000;
			hex_value <= 24'h000000;
			hex_blank <= 6'h3F;		// Displays dark until software enables them
		end
		else if (wen && sel) begin
			case (reg_idx)
				REG_LEDR:  ledr      <= ledr_nxt[9:0];
				REG_HEX:   hex_value <= hex_nxt[23:0];
				REG_BLANK: hex_blank <= blank_nxt[5:0];
				default: ;
			endcase
		end
	end

	always_comb begin
		rdata = 32'h0;
		if (sel && reg_idx == REG_SW) rdata = {22'b0, sw_sync};
	end

endmodule
