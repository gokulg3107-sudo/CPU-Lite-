`include "header_file.h"
module cpu_lite(clk_cpu, clk_mem, rst);
input clk_cpu, clk_mem, rst;
wire rst_mem;


reset_synchronizer rdc(.clk(clk_mem), .rst(rst), .rst_sync(rst_mem));
wire [31:0] program_memory_data;
wire [11:0] program_memory_addr;
wire cache_start, cache_done;
wire [31:0] cache_data_bus, cache_data_in;
wire [13:0] cache_addr;
wire [1:0] cache_control;
cpu_core cpu(.clk_cpu(clk_cpu), .rst(rst), .program_memory_data(program_memory_data), .program_memory_addr(program_memory_addr), .cache_done(cache_done), .cache_start(cache_start), .cache_control(cache_control), .cache_addr(cache_addr), .cache_data_bus(cache_data_bus), .cache_data_in(cache_data_in), .halted(halted));

memory_interface memory_module(.clk_cpu(clk_cpu), .clk_mem(clk_mem), .rst(rst), .rst_sync(rst_mem), .start(cache_start), .cpu_done(cache_done), .control_signals(cache_control), .cpu_addr(cache_addr), .data_bus_in(cache_data_bus), .data_bus_out(cache_data_in));

program_memory program_instruction(.program_memory_data(program_memory_data), .pc(program_memory_addr));

endmodule
 
