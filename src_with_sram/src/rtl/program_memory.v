module program_memory(pc, program_memory_data);
input [11:0] pc;
output [31:0] program_memory_data;

reg [31:0] program_mem [0:4095];
integer i;
initial begin
        //Words not covered by the hex file default to NOP (opcode 00) instead of X
        for(i = 0; i < 4096; i = i + 1) program_mem[i] = 32'd0;
        $readmemh("program_memory.hex", program_mem);
end
assign program_memory_data = program_mem[pc];
endmodule

