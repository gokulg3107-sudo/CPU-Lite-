`include "header_file.h"
// Runs whatever is in Program_Memory.hex until HALT, dumps registers and checks them.
module tb_cpu_lite_hex;
parameter real CPU_HALF = 3.333, MEM_HALF = 7.143;
parameter integer TIMEOUT = 2000000;
reg clk_cpu, clk_mem, rst;
cpu_lite dut(.clk_cpu(clk_cpu), .clk_mem(clk_mem), .rst(rst));
initial clk_cpu = 1'b0;
initial clk_mem = 1'b0;
always #CPU_HALF clk_cpu = ~clk_cpu;
always #MEM_HALF clk_mem = ~clk_mem;
integer cycles, i, pass_count, fail_count;
reg [31:0] exp [0:15];
initial begin
    pass_count = 0; fail_count = 0;
    exp[0]=32'h00004100; exp[1]=32'h00000140; exp[2]=32'h00000000; exp[3]=32'h0000033F; exp[4]=32'h000000BF; exp[5]=32'h00001820; exp[6]=32'h00000D94; exp[7]=32'h00000D94; exp[8]=32'h000017E0; exp[9]=32'h00002920; exp[10]=32'h000017E0; exp[11]=32'h000002D0; exp[12]=32'h043FE482; exp[13]=32'h0000000D; exp[14]=32'h00003FFF; exp[15]=32'h000000BF;
    rst = 1'b0; #50 rst = 1'b1;
    cycles = 0;
    while (dut.cpu.halted !== 1'b1 && cycles < TIMEOUT) begin @(posedge clk_cpu); cycles = cycles + 1; end
    if (dut.cpu.halted !== 1'b1) $display("[FAIL] no HALT within %0d cycles (pc=%0d)", TIMEOUT, dut.cpu.pc);
    else $display("HALT after %0d cycles", cycles);
    repeat (20) @(posedge clk_cpu); #1;
    for (i = 0; i < 16; i = i + 1) begin
        if (dut.cpu.general_purpose_register[i] === exp[i]) begin pass_count = pass_count + 1; $display("[PASS] R%0d = 0x%h", i, exp[i]); end
        else begin fail_count = fail_count + 1; $display("[FAIL] R%0d = 0x%h, expected 0x%h", i, dut.cpu.general_purpose_register[i], exp[i]); end
    end
    $display("TOTAL: %0d  PASS: %0d  FAIL: %0d", pass_count+fail_count, pass_count, fail_count);
    $finish;
end
endmodule
