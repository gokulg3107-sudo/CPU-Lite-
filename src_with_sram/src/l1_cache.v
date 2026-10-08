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
//valid_array/dirty_array: one bit per line, reset to 0. Tag array (SRAM2RW32x8): address bits [13:9] of the
//line held at each index, no reset needed since it is only trusted when valid_array[index] is 1.
//Index (addr[8:4]) is the array address itself and offset (addr[3:0]) selects the word, so neither is stored.
reg [31:0] valid_array, dirty_array;
wire [4:0] tag_rd;   //tag of the line at index, read from the tag SRAM (valid one clock after index settles)

localparam [2:0] idle = 3'd0, start_lookup = 3'd1, address_present = 3'd2, address_absent = 3'd3, cache_updated = 3'd4;
reg [2:0] current_state, next_state;

//In direct map, a particular line can exist only in a given index location in the
//cache. Since our cache has 32 lines, index is address bits [8:4] directly - NOT
//a mod-32 of the whole address, which would fold tag bits into the index.
assign index = lookup_addr[8:4];
assign offset = lookup_addr[3:0];

always@(*)begin
        if(valid_array[index]) begin
                if(lookup_addr[13:9] == tag_rd) tag_hit = 1'b1;
                else tag_hit = 1'b0;
        end
        else tag_hit = 1'b0;
end

assign tag_miss = ~tag_hit & (current_state == start_lookup | current_state == address_absent);
assign line_addr = lookup_addr;
//line_data = whole line at index, read from the 16 SRAM banks (bank j holds bits [j*32 +: 32])
assign cache_valid = valid_array[index];
assign cache_dirty = dirty_array[index];
assign tag_addr = {tag_rd, index, 4'b0000};

//The outgoing (old) line for a dirty writeback leaves on line_data. The incoming
//line arrives on line_bus_in and is latched below on fill_data.

//Upon Reset all the entries are invalid and the dirty bits are deasserted
//NOTE: data_array is removed from this block because it has no reset.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                valid_array <= 32'd0;
                dirty_array <= 32'd0;
                data_out <= 32'd0;
        end
        else begin
                //Load data is captured in cache_updated, not address_present: after a miss fill the
                //SRAM only shows the new line one clock after the write, so this is the first
                //cycle where line_data is guaranteed correct. Interface uses data_out in its done state.
                if(current_state == cache_updated & control_signals == `load_data) data_out <= line_data[(15-offset)*32 +: 32];
                if(current_state == address_present) begin
                        if(control_signals == `store_data) begin
                                dirty_array[index] <= 1'b1;
                        end
                        else if(control_signals == `store_stack) begin
                                valid_array[index] <= 1'b1;
                                dirty_array[index] <= 1'b1;
                         end
                end
               else if(current_state == address_absent & fill_data) begin
                        //Line has arrived from memory via the CDC path - install it and
                        //mark the line valid/clean, tagged to this lookup address.
                        valid_array[index] <= 1'b1;
                        dirty_array[index] <= 1'b0;
                end
        end
end

//Data array: 32 lines x 512 bit built from 16 x SRAM2RW32x32 (32 deep x 32 wide, port 1 used, port 2 parked).
//Bank j holds word slice j (bits [j*32 +: 32]) of every line, address = index.
//CE1 is the SRAM clock. CSB1 is tied low so the bank always reads data[index] (output is registered
//inside the macro and holds its value, so line_data follows index one clock later).
//NOTE: the simulation model does NOT show written data on O after a write; O only updates on the
//next read, i.e. one clock after the write. Nothing here relies on write-through.
//Word offset o lives in bank 15-o (same mapping as (15-offset)*32 +: 32 before).
wire write_line, write_word;
assign write_line = (current_state == address_present & control_signals == `store_stack) | (current_state == address_absent & fill_data);
assign write_word = (current_state == address_present & control_signals == `store_data);
wire [3:0] word_bank;
assign word_bank = 4'd15 - offset;
wire [15:0] bank_web;
wire [511:0] bank_din;
assign bank_web[0] = ~(write_line | (write_word & (word_bank == 4'd0)));
assign bank_web[1] = ~(write_line | (write_word & (word_bank == 4'd1)));
assign bank_web[2] = ~(write_line | (write_word & (word_bank == 4'd2)));
assign bank_web[3] = ~(write_line | (write_word & (word_bank == 4'd3)));
assign bank_web[4] = ~(write_line | (write_word & (word_bank == 4'd4)));
assign bank_web[5] = ~(write_line | (write_word & (word_bank == 4'd5)));
assign bank_web[6] = ~(write_line | (write_word & (word_bank == 4'd6)));
assign bank_web[7] = ~(write_line | (write_word & (word_bank == 4'd7)));
assign bank_web[8] = ~(write_line | (write_word & (word_bank == 4'd8)));
assign bank_web[9] = ~(write_line | (write_word & (word_bank == 4'd9)));
assign bank_web[10] = ~(write_line | (write_word & (word_bank == 4'd10)));
assign bank_web[11] = ~(write_line | (write_word & (word_bank == 4'd11)));
assign bank_web[12] = ~(write_line | (write_word & (word_bank == 4'd12)));
assign bank_web[13] = ~(write_line | (write_word & (word_bank == 4'd13)));
assign bank_web[14] = ~(write_line | (write_word & (word_bank == 4'd14)));
assign bank_web[15] = ~(write_line | (write_word & (word_bank == 4'd15)));
assign bank_din = write_line ? line_bus_in : {16{cpu_data_in}};

SRAM2RW32x32 data_sram0(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[0]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[0 +: 32]), .I2(32'd0), .O1(line_data[0 +: 32]), .O2());
SRAM2RW32x32 data_sram1(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[1]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[32 +: 32]), .I2(32'd0), .O1(line_data[32 +: 32]), .O2());
SRAM2RW32x32 data_sram2(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[2]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[64 +: 32]), .I2(32'd0), .O1(line_data[64 +: 32]), .O2());
SRAM2RW32x32 data_sram3(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[3]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[96 +: 32]), .I2(32'd0), .O1(line_data[96 +: 32]), .O2());
SRAM2RW32x32 data_sram4(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[4]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[128 +: 32]), .I2(32'd0), .O1(line_data[128 +: 32]), .O2());
SRAM2RW32x32 data_sram5(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[5]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[160 +: 32]), .I2(32'd0), .O1(line_data[160 +: 32]), .O2());
SRAM2RW32x32 data_sram6(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[6]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[192 +: 32]), .I2(32'd0), .O1(line_data[192 +: 32]), .O2());
SRAM2RW32x32 data_sram7(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[7]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[224 +: 32]), .I2(32'd0), .O1(line_data[224 +: 32]), .O2());
SRAM2RW32x32 data_sram8(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[8]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[256 +: 32]), .I2(32'd0), .O1(line_data[256 +: 32]), .O2());
SRAM2RW32x32 data_sram9(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[9]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[288 +: 32]), .I2(32'd0), .O1(line_data[288 +: 32]), .O2());
SRAM2RW32x32 data_sram10(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[10]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[320 +: 32]), .I2(32'd0), .O1(line_data[320 +: 32]), .O2());
SRAM2RW32x32 data_sram11(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[11]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[352 +: 32]), .I2(32'd0), .O1(line_data[352 +: 32]), .O2());
SRAM2RW32x32 data_sram12(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[12]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[384 +: 32]), .I2(32'd0), .O1(line_data[384 +: 32]), .O2());
SRAM2RW32x32 data_sram13(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[13]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[416 +: 32]), .I2(32'd0), .O1(line_data[416 +: 32]), .O2());
SRAM2RW32x32 data_sram14(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[14]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[448 +: 32]), .I2(32'd0), .O1(line_data[448 +: 32]), .O2());
SRAM2RW32x32 data_sram15(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(bank_web[15]), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1(bank_din[480 +: 32]), .I2(32'd0), .O1(line_data[480 +: 32]), .O2());

//Tag array: SRAM2RW32x8 (5 of 8 bits used), written on the same two events that install a line (write_line),
//read every other cycle exactly like the data banks. Port 2 parked.
wire [2:0] tag_unused;
SRAM2RW32x8 tag_sram(.A1(index), .A2(5'd0), .CE1(clk_cpu), .CE2(1'b0), .WEB1(~write_line), .WEB2(1'b1), .OEB1(1'b0), .OEB2(1'b1), .CSB1(1'b0), .CSB2(1'b1), .I1({3'b000, lookup_addr[13:9]}), .I2(8'd0), .O1({tag_unused, tag_rd}), .O2());

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
