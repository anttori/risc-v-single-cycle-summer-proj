// Data RAM with asynchronous read, synchronous byte-enable write.
//
// The load path of the single-cycle core needs read data in the same cycle as
// the address, which M9K blocks cannot provide, so the RAM is built from
// logic elements and kept small (default 1 KB).
module fpga_dmem #(
	parameter int WORDS = 256
)(
	input  logic        clk,
	input  logic        we,
	input  logic [3:0]  be,			// Byte enables
	input  logic [31:0] addr,		// Byte address; only the word index is used
	input  logic [31:0] wdata,
	output logic [31:0] rdata
);

	localparam int AW = $clog2(WORDS);

	(* ramstyle = "logic" *) logic [31:0] mem [0:WORDS-1];

	initial begin
		for (int i = 0; i < WORDS; i++) mem[i] = 32'h0;
	end

	// Plain 'always' (not always_ff) because 'mem' is also written by the initial block
	always @(posedge clk) begin
		if (we) begin
			for (int b = 0; b < 4; b++) begin
				if (be[b]) mem[addr[AW+1:2]][8*b +: 8] <= wdata[8*b +: 8];
			end
		end
	end

	assign rdata = mem[addr[AW+1:2]];

endmodule
