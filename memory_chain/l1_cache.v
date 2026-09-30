`include "header_file.h"
module l1_cache(clk_cpu, rst, fill_data, start, control_signals, lookup_addr, tag_hit, line_data, line_addr, line_bus_in, data_out, cpu_data_in, cache_done, tag_miss, cache_valid, cache_dirty, tag_addr);
input clk_cpu, rst, fill_data, start;
output tag_miss, cache_valid, cache_dirty;
output [13:0] tag_addr;
input [1:0] control_signals;
input [13:0] lookup_addr;
input [31:0] cpu_data_in;
output reg tag_hit;
output [13:0] line_addr;
output [511:0] line_data;
input [511:0] line_bus_in;
output reg [31:0] data_out;
output cache_done;
wire [4:0] index;
wire [3:0] offset;
reg [511:0] data_array [0:31];
//valid_array/dirty_array: one bit per line, reset to 0. tag_array: address bits [13:9] of the
//line held at each index, no reset needed since it is only trusted when valid_array[index] is 1.
//Index (addr[8:4]) is the array address itself and offset (addr[3:0]) selects the word, so neither is stored.
reg [31:0] valid_array, dirty_array;
reg [4:0] tag_array [0:31];

localparam [2:0] idle = 3'd0, start_lookup = 3'd1, address_present = 3'd2, address_absent = 3'd3, cache_updated = 3'd4;
reg [2:0] current_state, next_state;

//In direct map, a particular line can exist only in a given index location in the
//cache. Since our cache has 32 lines, index is address bits [8:4] directly - NOT
//a mod-32 of the whole address, which would fold tag bits into the index.
assign index = lookup_addr[8:4];
assign offset = lookup_addr[3:0];

always@(*)begin
        if(valid_array[index]) begin
                if(lookup_addr[13:9] == tag_array[index]) tag_hit = 1'b1;
                else tag_hit = 1'b0;
        end
        else tag_hit = 1'b0;
end

assign tag_miss = ~tag_hit & (current_state == start_lookup | current_state == address_absent);
assign line_addr = lookup_addr;
assign line_data = data_array[index];
assign cache_valid = valid_array[index];
assign cache_dirty = dirty_array[index];
assign tag_addr    = {tag_array[index], index, 4'b0000};

//The outgoing (old) line for a dirty writeback leaves on line_data. The incoming
//line arrives on line_bus_in and is latched below on fill_data.

//Upon Reset all the entries are invalid and the dirty bits are deasserted
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                valid_array <= 32'd0;
                dirty_array <= 32'd0;
                data_out <= 32'd0;
        end
        else begin
                if(current_state == address_present) begin
                        if(control_signals == `load_data) data_out <= data_array[index][(15-offset)*32 +: 32];
                        else if(control_signals == `store_data) begin
                                data_array[index][(15-offset)*32 +: 32] <= cpu_data_in;
                                dirty_array[index] <= 1'b1;
                        end
                        else if(control_signals == `store_stack) begin
                                data_array[index] <= line_bus_in;
                                valid_array[index] <= 1'b1;
                                dirty_array[index] <= 1'b1;
                         end
                end
               else if(current_state == address_absent & fill_data) begin
                        //Line has arrived from memory via the CDC path - install it and
                        //mark the line valid/clean, tagged to this lookup address.
                        data_array[index] <= line_bus_in;
                        valid_array[index] <= 1'b1;
                        dirty_array[index] <= 1'b0;
                end
        end
end

//Tag array has no reset, written on the same two events that install a line.
always@(posedge clk_cpu) begin
        if((current_state == address_present & control_signals == `store_stack) | (current_state == address_absent & fill_data))
                tag_array[index] <= lookup_addr[13:9];
end

always@(posedge clk_cpu or negedge rst) begin
        if(~rst) current_state <= idle;
        else current_state <= next_state;
end

always@(*)begin
        case(current_state)
        idle: next_state = start ? start_lookup : idle;
        start_lookup: next_state = tag_hit ? address_present : address_absent;
        address_present: next_state = cache_updated;
        address_absent: next_state = fill_data ? address_present : address_absent;
        cache_updated: next_state = idle;
        default: next_state = idle;
        endcase
end
assign cache_done = current_state == cache_updated;
endmodule
