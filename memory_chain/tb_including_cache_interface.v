// Self-checking integration test for cache_memory_interface + top_mem_chain.
//
// A cache line is 16 x 32-bit words. Word 0 is stored at line_addr and is the
// top 32 bits of the 512-bit line; word 15 is stored at line_addr+15 and is
// the bottom 32 bits. That matches both writers:
//   cache_memory_interface sends evict_line[511:480] first
//   rx_fifo_read_handler shifts each returning word in at the LSB
//
// Stimulus never touches data_memory except to plant a known line before a
// fetch. Stores are checked by reading the array back after the transaction,
// so a reversed bus cannot pass just because write and read share the bug.

module tb_cache_mem;
    reg         clk_cpu;
    reg         clk_mem;
    reg         rst;
    reg         tag_miss;
    reg         cache_valid;
    reg         cache_dirty;
    reg         start;
    reg  [13:0] lookup_addr;
    reg  [13:0] tag_addr;
    reg  [511:0] evict_line;

    wire [511:0] updated_cache_line;
    wire [511:0] cache_line;
    wire         fill_data;
    wire         data_request;
    wire         rw;
    wire [13:0]  line_addr;
    wire [31:0]  wdata;
    wire         tx_write_done;
    wire         tx_read_done;
    wire         rx_cache_done;
    wire         tx_fifo_empty;

    integer error_count;
    integer test_count;

    cache_memory_interface u_cache (
        .clk_cpu(clk_cpu),
        .rst(rst),
        .tag_miss(tag_miss),
        .tx_fifo_empty(tx_fifo_empty),
        .rx_cache_done(rx_cache_done),
        .cache_valid(cache_valid),
        .cache_dirty(cache_dirty),
        .evict_line(evict_line),
        .start(start),
        .lookup_addr(lookup_addr),
        .tag_addr(tag_addr),
        .rx_cache_line(cache_line),
        .updated_cache_line(updated_cache_line),
        .fill_data(fill_data),
        .data_request(data_request),
        .rw(rw),
        .line_addr(line_addr),
        .wdata(wdata)
    );

    top_mem_chain u_mem (
        .clk_cpu(clk_cpu),
        .clk_mem(clk_mem),
        .rst(rst),
        .req(data_request),
        .rw(rw),
        .line_addr(line_addr),
        .wdata(wdata),
        .done(tx_write_done),
        .tx_read_done(tx_read_done),
        .cache_line(cache_line),
        .rx_cache_done(rx_cache_done)
    );

    assign tx_fifo_empty = u_mem.tx_empty;

    initial begin
        clk_cpu = 1'b0;
        clk_mem = 1'b0;
    end
    // Unrelated periods so the async FIFO is crossed on purpose.
    always #5  clk_cpu = ~clk_cpu;
    always #8  clk_mem = ~clk_mem;

    function [511:0] make_line;
        input [31:0] base;
        integer i;
        reg [511:0] tmp;
        begin
            tmp = 512'd0;
            for (i = 0; i < 16; i = i + 1)
                tmp[(15 - i) * 32 +: 32] = base + i;
            make_line = tmp;
        end
    endfunction

    task poke_line;
        input [13:0] addr;
        input [511:0] line;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                u_mem.mem.memory[addr + i] = line[(15 - i) * 32 +: 32];
        end
    endtask

    task peek_line;
        input  [13:0] addr;
        output [511:0] line;
        integer i;
        reg [511:0] tmp;
        begin
            tmp = 512'd0;
            for (i = 0; i < 16; i = i + 1)
                tmp[(15 - i) * 32 +: 32] = u_mem.mem.memory[addr + i];
            line = tmp;
        end
    endtask

    task show_words;
        input [511:0] expected;
        input [511:0] actual;
        integer i;
        reg [31:0] exp_w;
        reg [31:0] got_w;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                exp_w = expected[(15 - i) * 32 +: 32];
                got_w = actual[(15 - i) * 32 +: 32];
                if (exp_w !== got_w)
                    $display("         word[%0d] expected %h  got %h", i, exp_w, got_w);
            end
        end
    endtask

    task check_line;
        input [8*48-1:0] label;
        input [13:0] addr;
        input [511:0] expected;
        input [511:0] actual;
        begin
            test_count = test_count + 1;
            if (actual === expected) begin
                $display("[PASS] %0s  (addr %0d)", label, addr);
            end else begin
                error_count = error_count + 1;
                $display("[FAIL] %0s  (addr %0d)", label, addr);
                $display("         expected %h", expected);
                $display("         actual   %h", actual);
                show_words(expected, actual);
            end
        end
    endtask

    task show_status;
        begin
            $display("  t=%0t cache=%0d writer=%0d reader=%0d rx=%0d tx_empty=%b rx_empty=%b fill=%b req=%b rw=%b isWritten=%b",
                $time,
                u_cache.current_state,
                u_mem.writer.current_state,
                u_mem.reader.current_state,
                u_mem.cpu_reader.current_state,
                u_mem.tx_empty,
                u_mem.rx_empty,
                fill_data,
                data_request,
                rw,
                u_cache.isWritten);
        end
    endtask

    // Pulse start for one CPU cycle, then wait until the cache presents the
    // filled line. cache_valid/dirty/addresses/evict_line must already be set.
    task run_transaction;
        output [511:0] filled;
        output integer timed_out;
        integer cycles;
        begin
            timed_out = 0;
            filled = {512{1'bx}};
            @(posedge clk_cpu);
            start = 1'b1;
            @(posedge clk_cpu);
            start = 1'b0;

            cycles = 0;
            while ((fill_data !== 1'b1) && (cycles < 20000)) begin
                @(posedge clk_cpu);
                cycles = cycles + 1;
            end

            if (fill_data !== 1'b1) begin
                timed_out = 1;
                error_count = error_count + 1;
                test_count  = test_count + 1;
                $display("[FAIL] timeout waiting for fill_data");
                show_status;
            end else begin
                filled = updated_cache_line;
                @(posedge clk_cpu);
            end
            repeat (6) @(posedge clk_cpu);
        end
    endtask

    reg [511:0] line_a;
    reg [511:0] line_b;
    reg [511:0] line_c;
    reg [511:0] line_d;
    reg [511:0] line_e;
    reg [511:0] poison;
    reg [511:0] sentinel;
    reg [511:0] filled;
    reg [511:0] mem_image;
    integer     timed_out;
    integer     k;

    initial begin
        error_count  = 0;
        test_count   = 0;
        rst          = 1'b0;
        start        = 1'b0;
        tag_miss     = 1'b1;
        cache_valid  = 1'b0;
        cache_dirty  = 1'b0;
        lookup_addr  = 14'd0;
        tag_addr     = 14'd0;
        evict_line   = 512'd0;

        #100;
        rst = 1'b1;
        repeat (4) @(posedge clk_cpu);

        line_a   = make_line(32'hA000_0000);
        line_b   = make_line(32'hB000_1000);
        line_c   = make_line(32'hC000_2000);
        line_d   = make_line(32'hD000_3000);
        line_e   = make_line(32'hE000_4000);
        poison   = make_line(32'hDEAD_BE00);
        sentinel = make_line(32'h5151_0000);

        // ------------------------------------------------------------------
        // 1. Fetch of memory that reset cleared. No writeback (invalid line).
        // ------------------------------------------------------------------
        lookup_addr  = 14'd48;
        tag_addr     = 14'd80;
        cache_valid  = 1'b0;
        cache_dirty  = 1'b0;
        evict_line   = poison;
        poke_line(14'd80, sentinel);
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fetch of reset line", 14'd48, 512'd0, filled);
            peek_line(14'd80, mem_image);
            check_line("no store on invalid miss", 14'd80, sentinel, mem_image);
        end

        // ------------------------------------------------------------------
        // 2. Fetch a line planted in memory. Independent of the store path.
        // ------------------------------------------------------------------
        poke_line(14'd16, line_a);
        lookup_addr = 14'd16;
        tag_addr    = 14'd96;
        cache_valid = 1'b1;
        cache_dirty = 1'b0;
        evict_line  = poison;
        poke_line(14'd96, sentinel);
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fetch preloaded line", 14'd16, line_a, filled);
            peek_line(14'd96, mem_image);
            check_line("no store when clean", 14'd96, sentinel, mem_image);
        end

        // ------------------------------------------------------------------
        // 3. valid=0, dirty=1 must not write the victim back.
        // ------------------------------------------------------------------
        poke_line(14'd64, line_b);
        lookup_addr = 14'd64;
        tag_addr    = 14'd160;
        cache_valid = 1'b0;
        cache_dirty = 1'b1;
        evict_line  = poison;
        poke_line(14'd160, sentinel);
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fetch while dirty-but-invalid", 14'd64, line_b, filled);
            peek_line(14'd160, mem_image);
            check_line("no store when invalid", 14'd160, sentinel, mem_image);
        end

        // ------------------------------------------------------------------
        // 4. Dirty miss: store evict_line at the victim, fill from lookup.
        // ------------------------------------------------------------------
        poke_line(14'd256, line_c);
        poke_line(14'd320, sentinel);
        lookup_addr = 14'd256;
        tag_addr    = 14'd320;
        cache_valid = 1'b1;
        cache_dirty = 1'b1;
        evict_line  = line_d;
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fill after dirty miss", 14'd256, line_c, filled);
            peek_line(14'd320, mem_image);
            check_line("store evicted line", 14'd320, line_d, mem_image);
            peek_line(14'd256, mem_image);
            check_line("lookup line not clobbered", 14'd256, line_c, mem_image);
            // One word past each end of the stored line must stay 0.
            test_count = test_count + 1;
            if ((u_mem.mem.memory[319] === 32'd0) && (u_mem.mem.memory[336] === 32'd0))
                $display("[PASS] store stayed inside the 16-word line");
            else begin
                error_count = error_count + 1;
                $display("[FAIL] store spilled  mem[319]=%h mem[336]=%h",
                    u_mem.mem.memory[319], u_mem.mem.memory[336]);
            end
        end

        // ------------------------------------------------------------------
        // 5. Fetch the line just stored, through the read path only.
        // ------------------------------------------------------------------
        lookup_addr = 14'd320;
        tag_addr    = 14'd400;
        cache_valid = 1'b1;
        cache_dirty = 1'b0;
        evict_line  = poison;
        poke_line(14'd400, sentinel);
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fetch previously stored line", 14'd320, line_d, filled);
            peek_line(14'd400, mem_image);
            check_line("clean fetch left victim alone", 14'd400, sentinel, mem_image);
        end

        // ------------------------------------------------------------------
        // 6. Write and read the same address: fill must observe the store.
        // ------------------------------------------------------------------
        lookup_addr = 14'd640;
        tag_addr    = 14'd640;
        cache_valid = 1'b1;
        cache_dirty = 1'b1;
        evict_line  = line_e;
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fill sees same-address store", 14'd640, line_e, filled);
            peek_line(14'd640, mem_image);
            check_line("memory holds same-address store", 14'd640, line_e, mem_image);
        end

        // ------------------------------------------------------------------
        // 7. Last legal line in the 16K-word memory.
        // ------------------------------------------------------------------
        lookup_addr = 14'd16368;
        tag_addr    = 14'd16368;
        cache_valid = 1'b1;
        cache_dirty = 1'b1;
        evict_line  = line_a;
        run_transaction(filled, timed_out);
        if (!timed_out) begin
            check_line("fill at top of memory", 14'd16368, line_a, filled);
            peek_line(14'd16368, mem_image);
            check_line("store at top of memory", 14'd16368, line_a, mem_image);
        end

        // ------------------------------------------------------------------
        // 8. Two dirty misses back to back, then fetch both victims.
        // ------------------------------------------------------------------
        poke_line(14'd512, line_b);
        poke_line(14'd768, line_c);
        lookup_addr = 14'd512;
        tag_addr    = 14'd1024;
        cache_valid = 1'b1;
        cache_dirty = 1'b1;
        evict_line  = line_d;
        run_transaction(filled, timed_out);
        if (!timed_out)
            check_line("first back-to-back fill", 14'd512, line_b, filled);

        lookup_addr = 14'd768;
        tag_addr    = 14'd2048;
        cache_valid = 1'b1;
        cache_dirty = 1'b1;
        evict_line  = line_e;
        run_transaction(filled, timed_out);
        if (!timed_out)
            check_line("second back-to-back fill", 14'd768, line_c, filled);

        peek_line(14'd1024, mem_image);
        check_line("first victim kept its line", 14'd1024, line_d, mem_image);
        peek_line(14'd2048, mem_image);
        check_line("second victim stored its line", 14'd2048, line_e, mem_image);

        lookup_addr = 14'd1024;
        tag_addr    = 14'd1280;
        cache_valid = 1'b0;
        cache_dirty = 1'b0;
        evict_line  = 512'd0;
        run_transaction(filled, timed_out);
        if (!timed_out)
            check_line("fetch first victim", 14'd1024, line_d, filled);

        lookup_addr = 14'd2048;
        run_transaction(filled, timed_out);
        if (!timed_out)
            check_line("fetch second victim", 14'd2048, line_e, filled);

        // Every word of a stored line occupies the index it was given.
        test_count = test_count + 1;
        begin : word_index_check
            integer mismatches;
            mismatches = 0;
            for (k = 0; k < 16; k = k + 1) begin
                if (u_mem.mem.memory[1024 + k] !== (32'hD000_3000 + k))
                    mismatches = mismatches + 1;
            end
            if (mismatches == 0)
                $display("[PASS] stored words sit at addr+index");
            else begin
                error_count = error_count + 1;
                $display("[FAIL] %0d stored words are at the wrong index", mismatches);
            end
        end

        #50;
        $display("----------------------------------------");
        $display("Tests run: %0d, Failures: %0d", test_count, error_count);
        if (error_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: %0d TEST(S) FAILED", error_count);
        $finish;
    end

    initial begin
        $dumpfile("tb_cache_mem.vcd");
        $dumpvars(1, tb_cache_mem);
        $dumpvars(0, u_cache);
    end
endmodule

