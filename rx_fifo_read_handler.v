module rx_fifo_read_handler(clk_cpu, rst, rdata, fifo_empty, ren, cache_line, done);
input clk_cpu, rst, fifo_empty;
input [31:0] rdata;
output ren;
output reg [511:0] cache_line;
output wire done;


localparam [1:0] idle = 2'd0, collecting_data = 2'd1, completion = 2'd2;
reg [1:0] current_state, next_state;

always@(posedge clk_cpu or negedge rst) begin
	if(~rst) current_state <= idle;
	else current_state <= next_state;
end
reg [4:0] count_word_collected;
always@(posedge clk_cpu or negedge rst) begin
	if(~rst) count_word_collected <= 5'd0;
	else if (current_state == collecting_data & ~fifo_empty) count_word_collected <= count_word_collected + 1'b1;
	else if(current_state == collecting_data) count_word_collected <= count_word_collected;
	else count_word_collected <= 5'd0;
end

always@(*) begin
	case(current_state) 
	idle: next_state = ~fifo_empty ? collecting_data : idle;
	collecting_data: next_state = count_word_collected == 5'd16 ? completion : collecting_data;
	completion: next_state = idle;
	default: next_state = idle;
	endcase
end

assign ren = (current_state == collecting_data) & (~fifo_empty);
assign done = (current_state == completion);

always@(posedge clk_cpu or negedge rst)begin
	if(~rst) cache_line <= 512'd0;
	else if (current_state == collecting_data & ren) cache_line <= {cache_line[479:0], rdata};
 	else cache_line <= cache_line;
end
assign done = current_state == completion;
endmodule
