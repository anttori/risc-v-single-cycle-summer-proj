// Combinational instruction ROM for the single-cycle core.
//
// MAX 10 has no MLAB, and M9K blocks need a registered read address, so an
// asynchronous-read ROM is built from logic elements. The program is small, so
// the cost is a few thousand LEs. Out-of-range fetches return a NOP.
module fpga_imem #(
	parameter int WORDS = 512,
	parameter INIT_FILE = "fpga_test.hex"
)(
	input  logic [31:0] pc,
	output logic [31:0] inst
);

	localparam int AW = $clog2(WORDS);
	localparam logic [31:0] NOP = 32'h0000_0013;	// addi x0, x0, 0

	(* ramstyle = "logic", romstyle = "logic" *) logic [31:0] rom [0:WORDS-1];

	// The image must hold exactly WORDS entries (see build.ps1 -Words)
	initial $readmemh(INIT_FILE, rom);

	assign inst = (pc[31:AW+2] == '0) ? rom[pc[AW+1:2]] : NOP;

endmodule
