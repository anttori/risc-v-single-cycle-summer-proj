module pc #(
	parameter logic [31:0] BOOT_ADDR = 32'h0;
)(
	
	input logic clk,
	input logic resetN,
	
	input logic [31:0] pc_next,
	
	output logic [31:0] pc_out
);


	always_ff @(posedge clk or negedge resetN) begin

		if(!resetN) pc_out <= BOOT_ADDR;
		
		else pc_out <= pc_next;

	end

endmodule