module tb;
reg clk_cpu, rst, req, rw, clk_mem;
reg [13:0] line_addr;
reg [31:0] wdata;
wire done;
wire tx_read_done;
wire rx_cache_done;
wire [511:0] cache_line;

top_mem_chain top(.*);

initial begin
    clk_cpu = 0;
    clk_mem = 0;
end
always #3 clk_cpu = ~clk_cpu;
always #6 clk_mem = ~clk_mem;

integer error_count;
integer test_count;
reg [511:0] expected_line [0:2];
reg [13:0]  test_addr    [0:2];
reg [511:0] readback;

// Writes a full 16-word cache line at 'addr' using base_val, base_val+1, ...
// base_val+15 as the word pattern. We wait for the write FSM (top.writer)
// to actually reach send_word before driving wdata, so the 16 words we
// push line up exactly with the 16 words the DUT captures, regardless of
// how many control/address cycles precede send_word.
task write_line(input [13:0] addr, input [31:0] base_val, output [511:0] expected);
    integer i;
    reg [31:0] word [0:15];
    begin
        @(posedge clk_cpu);
        req = 1'b1; rw = 1'b0; line_addr = addr;
        @(posedge clk_cpu);
        req = 1'b0;
        wait(top.writer.current_state == top.writer.send_word);
        for (i = 0; i < 16; i = i + 1) begin
            word[i] = base_val + i;
            wdata = word[i];
            @(posedge clk_cpu);
        end
        @(posedge tx_read_done);
        // rx_fifo_read_handler shifts words in MSB-first as they arrive, so
        // word[0] (written/read first) ends up in the top 32 bits.
        expected = {word[0],  word[1],  word[2],  word[3],
                    word[4],  word[5],  word[6],  word[7],
                    word[8],  word[9],  word[10], word[11],
                    word[12], word[13], word[14], word[15]};
    end
endtask

// Issues a read request for 'addr' and waits for the RX side to finish
// assembling the 512-bit cache line before sampling it.
task read_line(input [13:0] addr, output [511:0] result);
    begin
        @(posedge clk_cpu);
        req = 1'b1; rw = 1'b1; line_addr = addr;
        @(posedge clk_cpu);
        req = 1'b0;
        @(posedge rx_cache_done);
        result = cache_line;
    end
endtask

task check_line(input [13:0] addr, input [511:0] expected, input [511:0] actual);
    begin
        test_count = test_count + 1;
        if (actual === expected) begin
            $display("[PASS] line_addr=%0d readback matches", addr);
        end else begin
            error_count = error_count + 1;
            $display("[FAIL] line_addr=%0d", addr);
            $display("       expected = %h", expected);
            $display("       actual   = %h", actual);
        end
    end
endtask

initial begin
    error_count = 0;
    test_count  = 0;
    rst = 1'b0;
    req = 1'b0;
    rw = 1'b0;
    line_addr = 0;
    wdata = 32'd0;
    #30; rst = 1'b1;

    // 16-word-aligned, non-overlapping line starts. line_addr is a raw word
    // address that auto-increments for 16 words per transaction, so lines
    // must be spaced >= 16 apart or they'll clobber each other's data.
    test_addr[0] = 14'd0;
    test_addr[1] = 14'd16;
    test_addr[2] = 14'd32;

    // Write three distinct lines with distinct, known word patterns.
    write_line(test_addr[0], 32'h0000_0000, expected_line[0]);
    #100;
    write_line(test_addr[1], 32'h0000_1000, expected_line[1]);
    #100;
    write_line(test_addr[2], 32'h0000_2000, expected_line[2]);
    #100;

    // Read each line back and check it against what was actually written.
    read_line(test_addr[0], readback);
    check_line(test_addr[0], expected_line[0], readback);
    #100;

    read_line(test_addr[1], readback);
    check_line(test_addr[1], expected_line[1], readback);
    #100;

    read_line(test_addr[2], readback);
    check_line(test_addr[2], expected_line[2], readback);
    #100;

    #50;
    $display("----------------------------------------");
    $display("Tests run: %0d, Failures: %0d", test_count, error_count);
    if (error_count == 0) $display("RESULT: ALL TESTS PASSED");
    else                  $display("RESULT: %0d TEST(S) FAILED", error_count);
    $finish;
end

initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
end
endmodule
