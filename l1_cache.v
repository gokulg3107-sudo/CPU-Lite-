`include "header_file.h"
module l1_cache(clk_cpu, rst, fill_data, start, control_signals, lookup_addr, tag_hit, tag_miss, line_data, line_addr, bidirectional_line_bus, data_out, cpu_data_in);
input clk_cpu, rst, fill_data, start;
input [1:0] control_signals;
input [13:0] lookup_addr;
input [31:0] cpu_data_in;
output reg tag_hit;
output tag_miss;
output [13:0] line_addr;
output [511:0] line_data;
inout [511:0] bidirectional_line_bus;
output reg [31:0] data_out;

wire [4:0] index;
wire [3:0] offset;
reg [511:0] data_array [0:31];
//tag_array[15] -> Valid bit, tag_array[14] -> Dirty bit, tag[13:9] Tag Address, tag[8:4] -> Index, tag [3:0] Offset
reg [15:0] tag_array [0:31];

localparam [2:0] idle = 3'd0, start_lookup = 3'd1, address_present = 3'd2, address_absent = 3'd3, cache_updated = 3'd4;
reg [2:0] current_state, next_state;

//In direct map, a particular line can exist only in a given index location in the
//cache. Since our cache has 32 lines, index is address bits [8:4] directly - NOT
//a mod-32 of the whole address, which would fold tag bits into the index.
assign index = lookup_addr[8:4];
assign offset = lookup_addr[3:0];

always@(*)begin
        if(tag_array[index][`valid_bit]) begin
                if(lookup_addr[13:9] == tag_array[index][`tag_bits]) tag_hit = 1'b1;
                else tag_hit = 1'b0;
        end
        else tag_hit = 1'b0;
end

assign tag_miss = ~tag_hit & (current_state == start_lookup | current_state == address_absent);
assign line_addr = lookup_addr;
assign line_data = data_array[index];

//On a dirty eviction we drive the outgoing (old) line onto the bus for writeback.
//On a fill, the memory side drives the incoming line onto the bus and we latch it
//below - so we release the bus (high-Z) whenever we're not the one evicting.
assign bidirectional_line_bus = (current_state == address_absent & tag_array[index][`dirty_bit]) ? data_array[index] : {512{1'bz}};

integer i;
//Upon Reset all the entries in the tag array are invalid and dirty bit should
//be deasserted
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                for(i = 0; i < 32; i = i + 1) tag_array[i][`valid_bit : `dirty_bit] <= 2'b00;
                data_out <= 32'd0;
        end
        else begin
                if(current_state == address_present) begin
                        if(control_signals == `load_data) data_out <= data_array[index][offset*32 +: 32];
                        else if(control_signals == `store_data) begin
                                data_array[index][offset*32 +: 32] <= cpu_data_in;
                                tag_array[index][`dirty_bit] <= 1'b1;
                        end
                end
                else if(current_state == address_absent & fill_data) begin
                        //Line has arrived from memory via the CDC path - install it and
                        //mark the line valid/clean, tagged to this lookup address.
                        data_array[index] <= bidirectional_line_bus;
                        tag_array[index][`valid_bit] <= 1'b1;
                        tag_array[index][`dirty_bit] <= 1'b0;
                        tag_array[index][`tag_bits] <= lookup_addr[13:9];
                end
        end
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
endmodule
