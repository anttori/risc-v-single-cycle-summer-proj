// Hex digit to DE10-Lite 7-segment decoder.
// seg_n[6:0] = {g,f,e,d,c,b,a} and seg_n[7] = decimal point. The displays are
// active-low, so 0 lights a segment. 'blank' switches every segment (and the
// decimal point) off.
module hex7seg (
	input  logic [3:0] value,
	input  logic       blank,
	output logic [7:0] seg_n
);

	logic [6:0] seg;		// Active-high {g,f,e,d,c,b,a}

	always_comb begin
		case (value)
			4'h0: seg = 7'b0111111;
			4'h1: seg = 7'b0000110;
			4'h2: seg = 7'b1011011;
			4'h3: seg = 7'b1001111;
			4'h4: seg = 7'b1100110;
			4'h5: seg = 7'b1101101;
			4'h6: seg = 7'b1111101;
			4'h7: seg = 7'b0000111;
			4'h8: seg = 7'b1111111;
			4'h9: seg = 7'b1101111;
			4'hA: seg = 7'b1110111;
			4'hB: seg = 7'b1111100;
			4'hC: seg = 7'b0111001;
			4'hD: seg = 7'b1011110;
			4'hE: seg = 7'b1111001;
			4'hF: seg = 7'b1110001;
		endcase

		seg_n = blank ? 8'hFF : {1'b1, ~seg};
	end

endmodule
