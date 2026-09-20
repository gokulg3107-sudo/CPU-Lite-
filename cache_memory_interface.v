module cache_memory_interface(clk_cpu, rst, tag_miss, rx_cache_done, line_addr, rx_cache_line, updated_line_addr, updated_cache_line, fill_data, data_request);
input clk_cpu, rst, tag_miss, rx_cache_done;
input [13:0] line_addr;
input [511:0] rx_cache_line;
output reg [13:0] updated_line_addr;
output [511:0] updated_cache_line;
output fill_data, data_request;


localparam [1:0] idle = 2'd0, initiate_data_transfer = 2'd1, data_fetched = 2'd2;
reg [1:0] current_state, next_state;

always@(posedge clk_cpu or negedge rst) begin
	if(~rst) current_state <= idle;
	else current_state <= next_state;
end

always@(*)begin
	case(current_state)
	idle: next_state = tag_miss ? initiate_data_transfer : idle;
	initiate_data_transfer: next_state = rx_cache_done ? data_fetched : initiate_data_transfer;
	data_fetched: next_state = idle;
	default: next_state = idle;
	endcase
end

assign data_request = (current_state == idle) & tag_miss;
assign fill_data = current_state == data_fetched;
assign updated_cache_line = current_state == data_fetched ? rx_cache_line : 512'd0;

always@(posedge clk_cpu or negedge rst) begin
	if(~rst) updated_line_addr <= 14'd0;
	else if (current_state == idle) updated_line_addr <= line_addr;
	else updated_line_addr <= updated_line_addr;
end

endmodule
