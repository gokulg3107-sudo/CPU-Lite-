module tb;
reg clk_cpu, rst, req, rw, clk_mem;
reg [13:0] line_addr;
reg [31:0] wdata;
wire done;
wire tx_read_done;
top_mem_chain top(.*);

initial begin
    clk_cpu = 0;
    clk_mem = 0;
end
always #3 clk_cpu = ~clk_cpu;
always #6 clk_mem = ~clk_mem;

initial begin
    rst = 1'b0;
    req = 1'b0;
    rw = 1'b0;
    line_addr = 0;
    wdata = 32'hDEADBEEF;
    #30; rst = 1'b1;
    
    // Write transaction
    @(posedge clk_cpu);
    req = 1'b1;
    line_addr = 14'd0;
    rw = 1'b0;  // write
    @(posedge clk_cpu);
    req = 1'b0;
    @(posedge tx_read_done);
    #100;
      @(posedge clk_cpu);
    req = 1'b1;
    line_addr = 14'd20;
    rw = 1'b0;  // write
    @(posedge clk_cpu);
    req = 1'b0;
	@(posedge clk_cpu); wdata = 32'd20;
	@(posedge clk_cpu); wdata = 32'd20;
	@(posedge clk_cpu); wdata = 32'd31;
	@(posedge clk_cpu); wdata = 32'd33;
    @(posedge tx_read_done);
	#100;
    @(posedge clk_cpu);
    req = 1'b1;
    line_addr = 14'd30;
    rw = 1'b0;  // write
    @(posedge clk_cpu);
    req = 1'b0;
@(posedge clk_cpu); wdata = 32'd20;
        @(posedge clk_cpu); wdata = 32'd20;
        @(posedge clk_cpu); wdata = 32'd31;
        @(posedge clk_cpu); wdata = 32'd33;

    @(posedge tx_read_done);
    #100;  

 
    // Read transaction
    @(posedge clk_cpu);
    req = 1'b1;
    line_addr = 14'd0;
    rw = 1'b1;  // read
    @(posedge clk_cpu);
    req = 1'b0;
    @(posedge tx_read_done);
    #100;
@(posedge clk_cpu);
    req = 1'b1;
    line_addr = 14'd20;
    rw = 1'b1;  // read
    @(posedge clk_cpu);
    req = 1'b0;
    @(posedge tx_read_done);
    #100;
@(posedge clk_cpu);
    req = 1'b1;
    line_addr = 14'd30;
    rw = 1'b1;  // read
    @(posedge clk_cpu);
    req = 1'b0;
    @(posedge tx_read_done);
    #100;

    $finish;
end

initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
end
endmodule
