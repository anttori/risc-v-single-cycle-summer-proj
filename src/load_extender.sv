module load_extender(
	input logic [31:0] dmem_data,		// Raw 4-byte data word from DMEM 
	
	input logic [1:0] addr,		// Byte number inside received 4-byte word (dmem_data)
	
	input logic [2:0] func3,	
	
	output logic [31:0] le_data_out
);


always_comb begin
	le_data_out = dmem_data;		// Default value
	
	case(func3) 
		
		// LB - Load Byte
		3'b000: begin
			case(addr)
			
				// First byte
				2'b00: le_data_out = { {24{dmem_data[7]}}, dmem_data[7:0] };
				
				// Second byte
				2'b01: le_data_out = { {24{dmem_data[15]}}, dmem_data[15:8] };
				
				// Third byte
				2'b10: le_data_out = { {24{dmem_data[23]}}, dmem_data[23:16] };
				
				// Fourth byte
				2'b11: le_data_out = { {24{dmem_data[31]}}, dmem_data[31:24] };
				
			endcase
		end
		
		// LH - Load Half
		3'b001: begin
			case(addr[1])
			
				// First half
				1'b0: le_data_out = { {16{dmem_data[15]}}, dmem_data[15:0] };
				
				// Last half
				1'b1: le_data_out = { {16{dmem_data[31]}}, dmem_data[31:16] };
				
			endcase
		end
		
		// LW - Load Word
		3'b010: le_data_out = dmem_data;
			
		// LBU - Load Byte Unsigned
		3'b100: begin
			case(addr)
			
				// First byte
				2'b00: le_data_out = { 24'b0, dmem_data[7:0] };
				
				// Second byte
				2'b01: le_data_out = { 24'b0, dmem_data[15:8] };
				
				// Third byte
				2'b10: le_data_out = { 24'b0, dmem_data[23:16] };
				
				// Fourth byte
				2'b11: le_data_out = { 24'b0, dmem_data[31:24] };
				
			endcase
		end
		
		// LHU - Load Half unsigned
		3'b101: begin
			case(addr[1])
			
				// First half
				1'b0: le_data_out = { 16'b0, dmem_data[15:0] };
				
				// Last half
				1'b1: le_data_out = { 16'b0, dmem_data[31:16] };
				
			endcase
		end
		
		default: ;
	
	endcase

end


endmodule