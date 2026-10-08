`include "header_file.h"
module cpu_lite(clk_cpu, clk_mem, rst, program_memory_data, program_memory_addr);
input clk_cpu, clk_mem, rst;
input [31:0] program_memory_data;
input [11:0] program_memory_addr;
wire rst_mem;
reg reset_in;
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) reset_in <= 1'b0;
        else reset_in <= 1'b1;
end

reset_synchronizer rdc(.clk(clk_mem), .rst(rst), .reset_in(reset_in), .rst_sync(rst_mem));
wire cache_start, cache_done;
wire [31:0] cache_data_bus, cache_data_in;
wire [13:0] cache_addr;
wire [1:0] cache_control;

cpu_core cpu(.clk_cpu(clk_cpu), .rst(rst), .program_memory_data(program_memory_data), .program_memory_addr(program_memory_addr), .cache_done(cache_done), .cache_start(cache_start), .cache_control(cache_control), .cache_addr(cache_addr), .cache_data_bus(cache_data_bus), .cache_data_in(cache_data_in), .halted(halted));

memory_interface memory_module(.clk_cpu(clk_cpu), .clk_mem(clk_mem), .rst(rst), .rst_sync(rst_mem), .start(cache_start), .cpu_done(cache_done), .control_signals(cache_control), .cpu_addr(cache_addr), .data_bus_in(cache_data_bus), .data_bus_out(cache_data_in));


endmodule
 
