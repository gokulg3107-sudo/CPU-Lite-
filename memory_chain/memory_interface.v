module memory_interface(clk_cpu, clk_mem, rst, start, cpu_done, control_signals, cpu_addr, data_bus_in, data_bus_out);
input clk_cpu, clk_mem, rst, start;
output wire cpu_done;
input [1:0] control_signals;
input [13:0] cpu_addr;
input [31:0] data_bus_in;
output [31:0] data_bus_out;

wire [31:0] cpu_data_in;
wire [31:0] cache_data_out;
wire [13:0] lookup_addr;
wire [511:0] line_bus_in, line_bus_out;
wire cache_start, cache_done;

cpu_cache_interface interface1(
    .clk_cpu(clk_cpu), .rst(rst),
    .start(start), .cache_done(cache_done),
    .control_signals(control_signals),
    .cache_data_out(cache_data_out),
    .cpu_addr(cpu_addr),
    .data_bus_in(data_bus_in), .data_bus_out(data_bus_out),
    .lookup_addr(lookup_addr),
    .cpu_data_in(cpu_data_in),
    .line_bus_in(line_bus_in), .line_bus_out(line_bus_out),
    .cpu_done(cpu_done), .cache_start(cache_start)
);

wire tag_miss, cache_valid, cache_dirty, tag_hit, fill_data;
wire [13:0] tag_addr;
wire [511:0] updated_cache_line;

//l1_cache.line_bus_in is fed by memory (on a miss-fill) or by the CPU's
//assembled stack line (on a store_stack hit) - never both at once.
wire [511:0] l1_line_in = fill_data ? updated_cache_line : line_bus_out;

l1_cache direct_mapped_cache(
    .clk_cpu(clk_cpu), .rst(rst),
    .fill_data(fill_data), .start(cache_start),
    .tag_miss(tag_miss), .cache_valid(cache_valid), .cache_dirty(cache_dirty),
    .tag_addr(tag_addr),
    .control_signals(control_signals),
    .lookup_addr(lookup_addr),
    .cpu_data_in(cpu_data_in),
    .tag_hit(tag_hit),
    .line_addr(),
    .line_data(line_bus_in),
    .line_bus_in(l1_line_in),
    .data_out(cache_data_out),
    .cache_done(cache_done)
);

wire tx_fifo_empty, rx_cache_done, data_request, rw;
wire [13:0] mem_line_addr;
wire [31:0] wdata;
wire [511:0] rx_cache_line;

cache_memory_interface cache_mem(
    .clk_cpu(clk_cpu), .rst(rst),
    .tag_miss(tag_miss),
    .tx_fifo_empty(tx_fifo_empty),
    .rx_cache_done(rx_cache_done),
    .cache_valid(cache_valid), .cache_dirty(cache_dirty),
    .start(tag_miss),
    .lookup_addr(lookup_addr), .tag_addr(tag_addr),
    .rx_cache_line(rx_cache_line),
    .evict_line(line_bus_in),
    .updated_cache_line(updated_cache_line),
    .fill_data(fill_data),
    .data_request(data_request), .rw(rw),
    .line_addr(mem_line_addr), .wdata(wdata)
);

top_mem_chain mem_chain(
    .clk_cpu(clk_cpu), .clk_mem(clk_mem), .rst(rst),
    .req(data_request), .rw(rw),
    .line_addr(mem_line_addr), .wdata(wdata),
    .done(), .tx_read_done(),
    .cache_line(rx_cache_line),
    .rx_cache_done(rx_cache_done),
    .tx_empty(tx_fifo_empty)
);

endmodule
