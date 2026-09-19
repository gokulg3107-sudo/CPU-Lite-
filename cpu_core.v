module cpu_core(clk_cpu, rst, instruction, isLoad, isStore, isCall, isRet, databus);
input clk_cpu, rst;
input [31:0] instruction;
output reg isLoad, isStore, isCall, isRet;
inout [31:0] databus;

reg [31:0] program_counter;
reg [31:0] general_purpose_register [0:16];
reg [3:0] processor_status_register;

localparam [2:0] instruction_fetch = 3'd0, operand_fetch = 3'd1, execute = 3'd2, memory_access = 3'd3, register_write = 3'd4;
reg [2:0] current_state, next_state;

always@(posedge clk_cpu or negedge rst)begin
	if(~rst) current_state <= idle;
	else current_state <= next_state;
end

always@(*)begin
	case(current_state)
	instruction_fetch: next_state = operand_fetch;
	operand_fetch: next_state = execute;
	execute: next_state = memory_access;
	memory_access: next_state = cache_completed ? register_write : memory_access;
	register_write: instruction_fetch;
	default: current_state = instruction_fetch;
	endcase
end
always@(*)begin
	if(current_state = 
always@(*) begin
	case(current_state) 
	instruction_fetch: begin
		instruction_address_comb = instruction_address + 1;
	end
	operand_fetch: begin
		opcode = instruction[31:24];
		destination_register = general_purpose_register[instruction[23:0]];
		operand1 = general_purpose_register[instruction[19:16]];
		operand2 = general_purpose_register[instruction[15:12]];
		immediate = instruction[11:0];
	end
	 
