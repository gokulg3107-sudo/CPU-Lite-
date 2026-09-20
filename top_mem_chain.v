module top_mem_chain(clk_cpu, clk_mem, rst, req, rw, line_addr, wdata, done, tx_read_done, cache_line, rx_cache_done);
input clk_cpu, rst, req, rw, clk_mem;
input [13:0] line_addr;
input [31:0] wdata;
output done;
output wire tx_read_done;
output wire [511:0] cache_line;
output wire rx_cache_done;

wire [31:0] tx_fifo_write_data;
wire tx_wen;
wire tx_done;
wire tx_ren;
wire [31:0] tx_read_dataout;
wire tx_empty;
wire tx_full;

wire [31:0] rx_fifo_write_data;
wire rx_wen;
wire rx_ren;
wire [31:0] rx_read_dataout;
wire rx_empty;
wire rx_full;

wire [31:0] mem_dataout;
wire [13:0] mem_addr;
wire mem_en;
wire mem_rwbar;
wire [31:0] mem_datain;

// TX FIFO write handler (CPU domain)
tx_fifo_write_handler writer(
    .clk_cpu(clk_cpu), .rst(rst), .req(req), .rw(rw),
    .line_addr(line_addr), .wdata(wdata),
    .tx_fifo_write_data(tx_fifo_write_data),
    .wen(tx_wen), .done(tx_done)
);

// TX FIFO (CPU -> MEM)
async_fifo #(.ADDR_WIDTH(5), .DATA_WIDTH(32)) tx(
    .wclk(clk_cpu), .rclk(clk_mem),
    .wrst(rst), .rrst(rst),
    .wen(tx_wen), .ren(tx_ren),
    .write_datain(tx_fifo_write_data),
    .read_dataout(tx_read_dataout),
    .empty(tx_empty), .full(tx_full)
);

// TX FIFO read handler (MEM domain)
tx_fifo_read_handler reader(
    .clk_mem(clk_mem), .rst(rst),
    .fifo_empty(tx_empty),
    .fifo_read_data(tx_read_dataout),
    .mem_dataout(mem_dataout),
    .ren(tx_ren),
    .mem_addr(mem_addr), .mem_en(mem_en), .mem_rwbar(mem_rwbar),
    .wen(rx_wen), .mem_datain(mem_datain),
    .rx_fifo_write_data(rx_fifo_write_data),
    .done(tx_read_done)
);

// Data memory
data_memory mem(
    .clk_mem(clk_mem), .rst(rst),
    .enable(mem_en), .read_writebar(mem_rwbar),
    .data_in(mem_datain), .addr(mem_addr),
    .data_out(mem_dataout)
);

// RX FIFO (MEM -> CPU)
async_fifo #(.ADDR_WIDTH(5), .DATA_WIDTH(32)) rx(
    .wclk(clk_mem), .rclk(clk_cpu),
    .wrst(rst), .rrst(rst),
    .wen(rx_wen), .ren(rx_ren),
    .write_datain(rx_fifo_write_data),
    .read_dataout(rx_read_dataout),
    .empty(rx_empty), .full(rx_full)
);

// RX FIFO read handler (CPU domain): assembles 16 x 32-bit words read back
// from memory into one 512-bit cache line.
rx_fifo_read_handler cpu_reader(
    .clk_cpu(clk_cpu), .rst(rst),
    .rdata(rx_read_dataout),
    .fifo_empty(rx_empty),
    .ren(rx_ren),
    .cache_line(cache_line),
    .done(rx_cache_done)
);

assign done = tx_done;

endmodule
