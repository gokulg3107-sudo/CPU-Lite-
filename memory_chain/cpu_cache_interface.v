`include "header_file.h"
module cpu_cache_interface(clk_cpu, rst, start, cache_done, control_signals, cache_data_out, cpu_addr, data_bus, lookup_addr, cpu_data_in, bidirectional_line_bus, cpu_done);
input clk_cpu, rst, start, cache_done;
input [1:0] control_signals;
input [13:0] cpu_addr;
inout [31:0] data_bus;
output reg [13:0] lookup_addr;
output [31:0] cpu_data_in;
inout [511:0] bidirectional_line_bus;
input [31:0] cache_data_out;
output cpu_done;


localparam [2:0] idle = 3'd0, single_word = 3'd1, fill_line = 3'd2, stack_control_signal = 3'd3, done = 3'd4;
reg [2:0] current_state, next_state;
reg [511:0] line_buf;

always@(posedge clk_cpu or negedge rst) begin
        if(~rst) current_state <= idle;
        else current_state <= next_state;
end

//Latch the CPU address on start so lookup_addr stays stable for the whole
//transaction (l1_cache and cache_memory_interface both use it).
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) lookup_addr <= 14'd0;
        else if(current_state == idle & start) lookup_addr <= cpu_addr;
end

reg [3:0] count_word_collect;
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) count_word_collect <= 4'd0;
        else if(current_state == fill_line | (current_state == done & control_signals == `stack_retrieve)) count_word_collect <= count_word_collect + 1'b1;
        else count_word_collect <= 4'd0;
end
always@(*) begin
        case(current_state)
        idle: begin
                if(start) begin
                        if(control_signals == `load_data | control_signals == `store_data) next_state = single_word;
                        else if(control_signals == `store_stack) next_state = fill_line;
                        else next_state = stack_control_signal;
                end
                else next_state = idle;
        end
        single_word: next_state = cache_done ? done : single_word;
        fill_line: next_state = count_word_collect == 4'd15 ? stack_control_signal : fill_line;
        stack_control_signal: next_state = cache_done ? done : stack_control_signal;
        done: begin
                if(control_signals != `stack_retrieve) next_state = idle;
                else next_state = (count_word_collect == 4'd15) ? idle : done;
        end
        default: next_state = idle;
        endcase
end

//Line buffer. store_stack: 16 CPU words are shifted in (first word ends up in
//[31:0]). stack_retrieve: line is captured from the bus when the cache is done,
//then shifted out 32 bits per cycle starting from [31:0], same order as stored.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) line_buf <= 512'd0;
        else if(current_state == fill_line) line_buf <= {data_bus, line_buf[511:32]};
        else if(current_state == stack_control_signal & control_signals == `stack_retrieve & cache_done) line_buf <= bidirectional_line_bus;
        else if(current_state == done & control_signals == `stack_retrieve) line_buf <= {32'd0, line_buf[511:32]};
end

//Line bus is driven only while pushing a stored stack line to the cache;
//released (high-Z) otherwise so it never fights the cache's eviction/fill drive.
assign bidirectional_line_bus = (current_state == stack_control_signal & control_signals == `store_stack) ? line_buf : {512{1'bz}};

//CPU data bus is driven only in done: load returns the cache word, stack_retrieve
//streams the line. Otherwise high-Z so the CPU can drive it (store / fill_line).
assign data_bus = (current_state == done & control_signals == `load_data) ? cache_data_out : (current_state == done & control_signals == `stack_retrieve) ? line_buf[31:0] : 32'bz;

//Store word goes to the cache from the CPU bus; held by the CPU until cache_done.
assign cpu_data_in = (current_state == single_word) ? data_bus : 32'd0;

assign cpu_done = current_state == done;

endmodule
