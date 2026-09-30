
`include "header_file.h"

// Small self-checking testbench for store_stack / stack_retrieve on
// memory_interface (the top module with the cache_start fix). Not covered
// by tb_cpu_lite_top.v, which explicitly skips stack ops, and cpu_lite_top
// itself is stale (no cache_start) so it isn't the target here.

module tb_stack_ops;

parameter real    CPU_HALF = 3.333;   // clk_cpu 150 MHz
parameter real    MEM_HALF = 7.143;   // clk_mem  70 MHz
parameter integer TIMEOUT  = 3000;

reg         clk_cpu, clk_mem, rst;
reg         start;
reg  [1:0]  control_signals;
reg  [13:0] cpu_addr;
reg  [31:0] data_drv;
wire [31:0] data_bus_out;
wire        cpu_done;
reg [13:0] addr1, addr2;
reg [13:0] addrA, addrB;   // from T3/T4
reg [13:0] addrC, addrD;   // new
integer bad;               // new
memory_interface dut(
    .clk_cpu(clk_cpu), .clk_mem(clk_mem), .rst(rst),
    .start(start), .cpu_done(cpu_done),
    .control_signals(control_signals),
    .cpu_addr(cpu_addr),
    .data_bus_in(data_drv), .data_bus_out(data_bus_out)
);

initial clk_cpu = 1'b0;
initial clk_mem = 1'b0;
always #CPU_HALF clk_cpu = ~clk_cpu;
always #MEM_HALF clk_mem = ~clk_mem;

integer pass_count, fail_count;
integer i, cycles;
reg [31:0] w    [0:15];
reg [31:0] got  [0:15];

function [13:0] make_addr;
    input [4:0] tag;
    input [4:0] index;
    input [3:0] offs;
    begin
        make_addr = {tag, index, offs};
    end
endfunction

task check;
    input cond;
    input [8*80-1:0] msg;
    begin
        if (cond) begin
            pass_count = pass_count + 1;
            $display("[PASS] %0s", msg);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] %0s", msg);
        end
    end
endtask

// Feed w[0..15] one per cycle during fill_line, then wait for cpu_done.
task stack_store;
    input [13:0] addr;
    integer k;
    begin
        @(posedge clk_cpu); #1;
        cpu_addr = addr;
        control_signals = `store_stack;
        start = 1'b1;
        @(posedge clk_cpu); #1;
        start = 1'b0;
        for (k = 0; k < 16; k = k + 1) begin
            data_drv = w[k];
            @(posedge clk_cpu); #1;
        end
        data_drv = 32'd0;
        cycles = 0;
        while (!cpu_done && cycles < TIMEOUT) begin
            @(posedge clk_cpu); #1;
            cycles = cycles + 1;
        end
        check(cpu_done, "stack_store reached cpu_done");
        @(posedge clk_cpu); #1;
    end
endtask

// Pulse start, wait for cpu_done, then sample data_bus_out for 16 cycles
// while cpu_done stays high (done lingers for stack_retrieve).
task stack_retrieve;
    input [13:0] addr;
    integer k;
    begin
        @(posedge clk_cpu); #1;
        cpu_addr = addr;
        control_signals = `stack_retrieve;
        start = 1'b1;
        @(posedge clk_cpu); #1;
        start = 1'b0;
        cycles = 0;
        while (!cpu_done && cycles < TIMEOUT) begin
            @(posedge clk_cpu); #1;
            cycles = cycles + 1;
        end
        check(cpu_done, "stack_retrieve reached cpu_done");
        for (k = 0; k < 16; k = k + 1) begin
            got[k] = data_bus_out;
            @(posedge clk_cpu); #1;
        end
    end
endtask

// One load_data word, blocking, returns via `got_word`.
reg [31:0] got_word;
task load_word;
    input [13:0] addr;
    begin
        @(posedge clk_cpu); #1;
        cpu_addr = addr;
        control_signals = `load_data;
        start = 1'b1;
        @(posedge clk_cpu); #1;
        start = 1'b0;
        cycles = 0;
        while (!cpu_done && cycles < TIMEOUT) begin
            @(posedge clk_cpu); #1;
            cycles = cycles + 1;
        end
        got_word = data_bus_out;
    end
endtask

reg [13:0] addr1, addr2;
reg [13:0] addrA, addrB;

// One store_data word, data held on data_drv until cpu_done.
task store_word;
    input [13:0] addr;
    input [31:0] data;
    begin
        @(posedge clk_cpu); #1;
        cpu_addr = addr;
        control_signals = `store_data;
        data_drv = data;
        start = 1'b1;
        @(posedge clk_cpu); #1;
        start = 1'b0;
        cycles = 0;
        while (!cpu_done && cycles < TIMEOUT) begin
            @(posedge clk_cpu); #1;
            cycles = cycles + 1;
        end
        data_drv = 32'd0;
        @(posedge clk_cpu); #1;
    end
endtask
initial begin
    pass_count = 0; fail_count = 0;
    start = 1'b0; control_signals = 2'b00; cpu_addr = 14'd0; data_drv = 32'd0;
    rst = 1'b0;
    #50 rst = 1'b1;
    @(posedge clk_cpu); #1;

    addr1 = make_addr(5'd1, 5'd0, 4'd0);  // tag 1, index 0
    addr2 = make_addr(5'd2, 5'd0, 4'd0);  // tag 2, same index -> evicts addr1

    // ------------------------------------------------------------
    // T1: cold store_stack (miss, allocate) then immediate retrieve
    // (hit). Retrieve reads line_data directly, so word order must
    // come back exactly as fed.
    // ------------------------------------------------------------
    for (i = 0; i < 16; i = i + 1) w[i] = 32'hAB000000 + i;
    stack_store(addr1);
    stack_retrieve(addr1);
    for (i = 0; i < 16; i = i + 1)
        check(got[i] === w[i], "T1 round-trip word matches store order");

    // ------------------------------------------------------------
    // T2: store_stack to the same index with a different tag - this
    // evicts addr1's dirty line. cache_memory_interface writes the
    // evicted line back using l1_cache's normal offset convention
    // (offset 0 = data_array bits[511:480]), while store_stack packed
    // word 0 into bits[31:0] - so the word order landing in memory is
    // reversed relative to the order fed into store_stack.
    // ------------------------------------------------------------
    for (i = 0; i < 16; i = i + 1) w[i] = 32'hCD000000 + i;
    stack_store(addr2);
    for (i = 0; i < 16; i = i + 1) begin
        load_word(addr1 + i);
        check(got_word === (32'hAB000000 + (15 - i)),
              "T2 evicted stack line landed in memory (reversed word order)");
    end
	    // ------------------------------------------------------------
    // T3: store_data hit must set dirty and use the same word
    // mapping as load_data. Evicting it (load of addr2) must write
    // the modified word back to memory; reload addr1 to check.
    // ------------------------------------------------------------
    store_word(addr1 + 3, 32'h11112222);
    load_word(addr1 + 3);
    check(got_word === 32'h11112222, "T3 store_data hit read back by load_data");
    load_word(addr2);
    load_word(addr1 + 3);
    check(got_word === 32'h11112222, "T3 store_data line written back on eviction");
    load_word(addr1 + 4);
    check(got_word === (32'hAB000000 + 11), "T3 neighbouring word untouched");

    // ------------------------------------------------------------
    // T4: two different indexes with different tags must not
    // disturb each other (per-index valid/dirty/tag).
    // ------------------------------------------------------------
    addrA = make_addr(5'd3, 5'd1, 4'd0);
    addrB = make_addr(5'd4, 5'd2, 4'd0);
    for (i = 0; i < 16; i = i + 1) w[i] = 32'hEF000000 + i;
    stack_store(addrA);
    for (i = 0; i < 16; i = i + 1) w[i] = 32'h12000000 + i;
    stack_store(addrB);
    stack_retrieve(addrA);
    for (i = 0; i < 16; i = i + 1)
        check(got[i] === (32'hEF000000 + i), "T4 index 1 line intact after index 2 store");
    stack_retrieve(addrB);
    for (i = 0; i < 16; i = i + 1)
        check(got[i] === (32'h12000000 + i), "T4 index 2 line intact");

    // ------------------------------------------------------------
    // T5: reset clears valid but not tag/data. Memory resets to 0,
    // so if valid were ignored the stale tag would hit and return
    // old cache data instead of 0.
    // ------------------------------------------------------------
    rst = 1'b0; #20; rst = 1'b1;
    @(posedge clk_cpu); #1;
    load_word(addr1 + 3);
    check(got_word === 32'd0, "T5 valid cleared by reset (stale tag must miss)");
    // ------------------------------------------------------------
    // T6: clean eviction must NOT write back. Fill addrC (clean),
    // then change its memory copy so cache and memory differ. Evict
    // it by loading addrD (same index, other tag). If the design
    // wrongly writes back, the sentinel is overwritten with the
    // cache's stale data.
    // ------------------------------------------------------------
    addrC = make_addr(5'd5, 5'd3, 4'd0);
    addrD = make_addr(5'd6, 5'd3, 4'd0);
    load_word(addrC);                              // cold miss -> clean fill
    for (i = 0; i < 16; i = i + 1)
        dut.mem_chain.mem.memory[addrC + i] = 32'h5EED0000 + i;
    load_word(addrD);                              // clean eviction of addrC
    repeat (10) @(posedge clk_cpu);
    bad = 0;
    for (i = 0; i < 16; i = i + 1)
        if (dut.mem_chain.mem.memory[addrC + i] !== (32'h5EED0000 + i)) bad = bad + 1;
    check(bad == 0, "T6 clean eviction did not write back");
    $display("==== SUMMARY ====");
	
    $display("TOTAL: %0d  PASS: %0d  FAIL: %0d", pass_count + fail_count, pass_count, fail_count);
    if (fail_count == 0)
        $display("RESULT: ALL TESTS PASSED");
    else
        $display("RESULT: %0d TEST(S) FAILED", fail_count);
    $finish;
end
initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_stack_ops);
end
endmodule

