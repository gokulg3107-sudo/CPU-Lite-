module cache_memory_interface(clk_cpu, rst, tag_miss, tx_fifo_empty, rx_cache_done, cache_valid, cache_dirty, evict_line, start, lookup_addr, tag_addr, rx_cache_line, updated_cache_line, fill_data, data_request, rw, line_addr, wdata);
input clk_cpu, rst, tag_miss, tx_fifo_empty, rx_cache_done, cache_valid, cache_dirty, start;
input [13:0] lookup_addr, tag_addr;
input [511:0] rx_cache_line, evict_line;
output [511:0] updated_cache_line;
output fill_data, data_request, rw;
output [31:0] wdata;
output reg [13:0] line_addr;
localparam [2:0] idle = 3'd0, send_control_signal = 3'd1, send_starting_address = 3'd2, write_line_to_memory = 3'd3, wait_before_reading = 3'd4, load_new_line = 3'd5, transaction_done = 3'd6;
reg [2:0] current_state, next_state;
reg [3:0] count_word_sent;
reg isWritten;
always@(posedge clk_cpu or negedge rst) begin
	if(~rst) current_state <= idle;
	else current_state <= next_state;
end

always@(*) begin
	case(current_state)
	idle: next_state = start ? send_control_signal : idle;
	send_control_signal: next_state = send_starting_address;
	send_starting_address: next_state = (isWritten || ~(cache_valid & cache_dirty)) ? load_new_line : write_line_to_memory;
	write_line_to_memory: next_state = count_word_sent == 4'd15 ? wait_before_reading : write_line_to_memory;
	wait_before_reading: next_state = tx_fifo_empty ? send_control_signal : wait_before_reading;
	load_new_line: next_state = rx_cache_done ? transaction_done : load_new_line;
	transaction_done: next_state = idle;
	default: next_state = idle;
	endcase
end

assign data_request = ((current_state == idle) & start) | ((current_state == wait_before_reading) & tx_fifo_empty);
assign rw = ~(~isWritten & cache_valid & cache_dirty);
assign fill_data = current_state == transaction_done;
assign updated_cache_line = current_state == transaction_done ? rx_cache_line : 512'd0;
always@(*) begin
	case(current_state)
	idle, transaction_done, wait_before_reading: line_addr = 14'd0;
	send_starting_address: line_addr = (isWritten | ~(cache_valid & cache_dirty)) ? lookup_addr : tag_addr;
	send_control_signal: line_addr = 14'd0; // don't-care / hold
	write_line_to_memory: line_addr = tag_addr;
	load_new_line: line_addr = lookup_addr;
 	default: line_addr = 14'd0;
	endcase
end	
always@(posedge clk_cpu or negedge rst) begin
	if(~rst) isWritten <= 1'b0;
	else begin
		if(current_state == write_line_to_memory) isWritten <= 1'b1;	
		else if(current_state == idle) isWritten <= 1'b0;
		else isWritten <= isWritten;
	end
end
//Count number of words sent 
always@(posedge clk_cpu or negedge rst) begin
	if(~rst) count_word_sent <= 0;
	else if (current_state == write_line_to_memory) count_word_sent <= count_word_sent + 1'b1;
	else count_word_sent <= 4'd0;
end

assign wdata = (current_state == write_line_to_memory) ? evict_line[(15-count_word_sent)*32 +: 32] : 32'd0;
endmodule
