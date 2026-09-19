///////////////////////////////////////////////////////////////////////////////
//Basic Single Port Memory
//Active High Enable, asynchronous active low reset
//Whenever enable is asserted, based on the controler signal read_writebar
//If read_write_bar = 0 -> write operation on the given address. Else read
//operation on the given address, output is fed to data_out.
///////////////////////////////////////////////////////////////////////////////

module data_memory(clk_mem, rst, enable, read_writebar, data_in, addr, data_out);
input clk_mem, rst, enable, read_writebar;
input [31:0] data_in;
input [13:0] addr;
output reg [31:0] data_out;

reg [31:0] memory [0:16383];
integer i;


always@(posedge clk_mem or negedge rst)begin
	if(~rst) for(i = 0; i <= 16383; i = i + 1) memory[i] <= 0;
	else begin
		if(enable) begin
			if(~read_writebar) memory[addr] <= data_in;
			else data_out <= memory[addr];
		end
	end
end
endmodule
