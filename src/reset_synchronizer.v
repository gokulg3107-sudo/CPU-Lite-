module reset_synchronizer(clk, rst, rst_sync);
input clk, rst;
output rst_sync;
reg sync1, sync2;
always@(posedge clk or negedge rst) begin
	if(~rst) begin
	 	sync1 <= 1'b0;
		sync2 <= 1'b0;
	end
	else begin
		sync1 <= 1'b1;
		sync2 <= sync1;
	end
end
assign rst_sync = sync2;
endmodule
