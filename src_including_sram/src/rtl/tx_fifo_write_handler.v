////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////


module tx_fifo_write_handler(clk_cpu, rst, req, rw, line_addr, wdata, tx_fifo_write_data, wen, done);
input clk_cpu, rst, req, rw;
input [13:0] line_addr;
input [31:0] wdata;
output reg wen;
output done;
output reg [31:0] tx_fifo_write_data;

localparam [2:0] idle = 3'd0, send_control_signals = 3'd1, send_start_address = 3'd2, send_word = 3'd3, data_loaded_into_fifo = 3'd4;
reg [2:0] current_state, next_state;
//4bit Upcounter to keep count of number of words pushed into the TX FIFO
//during the "send_word" FSM State. After 16 words are loaded into the FIFO
//FSM moves onto the next state
reg [3:0] count_words_sent;
always@(posedge clk_cpu or negedge rst)begin
	if(~rst) count_words_sent <= 0;
	else if (current_state == send_word) count_words_sent <= count_words_sent + 1;
	else count_words_sent <= 0;
end
//State Transittion Logic
always@(posedge clk_cpu or negedge rst)begin
	if(~rst) current_state <= idle;
	else current_state <= next_state;
end

always@(*)begin
	case(current_state)
	idle: next_state = req ? send_control_signals : idle;
	send_control_signals: next_state = send_start_address;
	send_start_address: next_state = ~rw ? send_word : data_loaded_into_fifo;
	send_word: next_state = count_words_sent == 4'd15 ? data_loaded_into_fifo : send_word;
	data_loaded_into_fifo: next_state = idle;
	default: next_state = idle;
	endcase
end

//Output Logic 
//During state send control signals, we first load the control signals into
//the fifo. Then we send the start address into the fifo. In case of writing
//into the data memory, 16 words of data wil then be pushed into the FIFO
//which has to be written into the data memory sequentially starting from the
//"starting address"
always@(*)begin
	case(current_state)
	idle: begin wen = 0; tx_fifo_write_data = 0; end
	send_control_signals: begin wen = 1'b1; tx_fifo_write_data = {31'd0, rw}; end
	send_start_address: begin wen = 1'b1; tx_fifo_write_data = {18'd0, line_addr}; end
	send_word: begin wen = 1'b1; tx_fifo_write_data = wdata; end	
	data_loaded_into_fifo: begin wen = 1'b0; tx_fifo_write_data = 32'd0; end
	default: begin wen = 1'b0; tx_fifo_write_data = 32'd0; end
	endcase
end

//Whenever data is loaded into the FIFO a done signal is sent back to L1
//cache.
assign done = current_state == data_loaded_into_fifo;

endmodule
