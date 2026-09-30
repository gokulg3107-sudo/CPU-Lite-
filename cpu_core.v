`include "header_file.h"
module cpu_core(clk_cpu, rst, program_memory_data, cache_done, cache_start, cache_data_bus);
input clk_cpu, rst, cache_done;
input [31:0] program_memory_data;
output cache_start;
output reg [31:0] cache_data_bus;

//stall : downstream (EX) is not ready -> hold PC, IF/OF and OF/EX
//load_use_stall : OF must wait for load data -> hold PC and IF/OF, push a bubble into OF/EX
//flush : branch/jump taken in EX -> redirect PC, clear IF/OF and OF/EX
wire stall, flush, load_use_stall;

//Driven by the hazard unit (to be instantiated)
wire hazard_detected, forward_opa, forward_opb;
wire [31:0] hazard_forwarded_value_opa, hazard_forwarded_value_opb;

//Driven by the RW stage (register file write port)
wire rw_wen;
wire [3:0] rw_waddr;
wire [31:0] rw_wdata;

reg [11:0] branch_target;
reg [11:0] pc;
reg [31:0] if_of_instruction;
reg [11:0] if_of_pc;

reg [7:0] of_ex_opcode;
reg [31:0] of_ex_operanda, of_ex_operandb;
reg [11:0] of_ex_branch_target;   //registered - belongs to the instruction now in EX
reg [11:0] of_ex_pc;
reg [3:0] of_ex_destination_register;   //registered - Rd of the instruction now in EX
reg of_ex_reg_write;              //1 only if the instruction in EX writes a register

integer i;
reg [31:0] general_purpose_register[0:15];
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                for (i = 0; i < 16; i = i + 1) general_purpose_register[i] <= 0;
                general_purpose_register[14] <= 32'h3FFF;       //SP = top of data memory
        end
        else begin
                if(rw_wen) general_purpose_register[rw_waddr] <= rw_wdata;
        end
end

//Register read with write-through: if RW is writing the register on this same
//edge, OF sees the new value instead of the stale one.
function [31:0] gpr_read;
        input [3:0] addr;
        begin
                gpr_read = (rw_wen && (rw_waddr == addr)) ? rw_wdata : general_purpose_register[addr];
        end
endfunction

//PC: flush redirects (flush has priority over stall). RET/JMP_REG take the
//target from EX operand A (already forwarded), everything else from the
//registered branch target. Otherwise fetch the next sequential instruction
//unless the front end is being held.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) pc <= 12'd0;
        else begin
                if(flush) pc <= (of_ex_opcode == `ret || of_ex_opcode == `jmp_reg) ? of_ex_operanda[11:0] : of_ex_branch_target;
                else if(~stall & ~load_use_stall) pc <= pc + 1'b1;
                else pc <= pc;
        end
end

//IF/OF pipeline register
//flush: the instruction on program_memory_data was fetched off the
//pre-redirect pc, so it is wrong-path - latch a bubble (NOP) instead.
//stall / load_use_stall: hold the latch so the instruction OF has not consumed is not lost.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                if_of_pc <= 12'd0;
                if_of_instruction <= 32'd0;
        end
        else begin
                if(flush) begin
                        if_of_pc <= 12'd0;
                        if_of_instruction <= 32'd0;
                end
                else if(~stall & ~load_use_stall) begin
                        if_of_pc <= pc;
                        if_of_instruction <= program_memory_data;
                end
        end
end

wire [7:0]  opcode;
assign opcode = if_of_instruction[`opcode];
reg [31:0] operand_a, operand_b;
wire [11:0] immediate_addr;
assign immediate_addr = if_of_instruction[`immediate_address];
always@(*) begin
        branch_target = 12'd0;
        case(opcode)
        `jmp, `jmp_if, `beq, `bne, `blt, `bge, `bltu, `bgeu, `call: branch_target  = immediate_addr;
        default: branch_target = 12'd0;
        endcase
end
always@(*) begin
        operand_a = 32'd0;
        operand_b = 32'd0;
        case(opcode)
        //Rd <- Rs1 op Rs2 (CMP has no write-back, EX/RW handle that)
        `add, `sub, `mul, `and_gate, `or_gate, `xor_gate, `cmp, `eq, `shl, `shr, `sar, `rol, `ror, `slt, `sltu: begin
                operand_a = gpr_read(if_of_instruction[`operand_a]);
                operand_b = gpr_read(if_of_instruction[`operand_b]);
        end
        //Single register source: NOT, MOV, LOAD_IND (address), JMP_IF (condition), JMP_REG (target)
        `not_gate, `mov, `load_ind, `jmp_if, `jmp_reg: operand_a = gpr_read(if_of_instruction[`operand_a]);
        //ADDI/SUBI sign-extend the immediate
        `addi, `subi: begin
                operand_a = gpr_read(if_of_instruction[`operand_a]);
                operand_b = {{20{immediate_addr[11]}}, immediate_addr};
        end
        //ANDI/ORI/XORI zero-extend the immediate
        `andi, `ori, `xori: begin
                operand_a = gpr_read(if_of_instruction[`operand_a]);
                operand_b = {20'd0, immediate_addr};
        end
        //LUI/LOAD_IMM: immediate goes on operand B, zero-extended
        `lui, `load_imm: operand_b = {20'd0, immediate_addr};
        //Direct LOAD: address on operand A
        `load: operand_a = {20'd0, immediate_addr};
        //Direct STORE: address on operand A, data (Rd) on operand B
        `store: begin
                operand_a = {20'd0, immediate_addr};
                operand_b = gpr_read(if_of_instruction[`destination_register]);
        end
        //STORE_IND: address is Rs2, data is Rd
        `store_ind: begin
                operand_a = gpr_read(if_of_instruction[`operand_b]);
                operand_b = gpr_read(if_of_instruction[`destination_register]);
        end
        //RET: target comes from LR (R15)
        `ret: operand_a = gpr_read(4'd15);
        //NOP, HALT, JMP, BEQ/BNE/BLT/BGE/BLTU/BGEU, CALL: no register operands
        default: begin operand_a = 0; operand_b = 0; end
        endcase
end

//Which register (if any) each operand slot actually reads. The hazard unit
//compares these against EX/MEM destinations, so an immediate in the operand
//field (ADDI etc.) is never mistaken for a register source.
reg [3:0] src_a_reg, src_b_reg;
reg       src_a_used, src_b_used;
always@(*) begin
        src_a_reg = 4'd0;
        src_b_reg = 4'd0;
        src_a_used = 1'b0;
        src_b_used = 1'b0;
        case(opcode)
        `add, `sub, `mul, `and_gate, `or_gate, `xor_gate, `cmp, `eq, `shl, `shr, `sar, `rol, `ror, `slt, `sltu: begin
                src_a_reg = if_of_instruction[`operand_a];
                src_b_reg = if_of_instruction[`operand_b];
                src_a_used = 1'b1;
                src_b_used = 1'b1;
        end
        `not_gate, `mov, `load_ind, `jmp_if, `jmp_reg, `addi, `subi, `andi, `ori, `xori: begin
                src_a_reg = if_of_instruction[`operand_a];
                src_a_used = 1'b1;
        end
        //STORE: data is Rd on operand B
        `store: begin
                src_b_reg = if_of_instruction[`destination_register];
                src_b_used = 1'b1;
        end
        //STORE_IND: address is Rs2 on operand A, data is Rd on operand B
        `store_ind: begin
                src_a_reg = if_of_instruction[`operand_b];
                src_b_reg = if_of_instruction[`destination_register];
                src_a_used = 1'b1;
                src_b_used = 1'b1;
        end
        //RET: source is LR
        `ret: begin
                src_a_reg = 4'd15;
                src_a_used = 1'b1;
        end
        default: begin
                src_a_used = 1'b0;
                src_b_used = 1'b0;
        end
        endcase
end

//Forward only into operand slots that really hold a register value
wire fwd_a, fwd_b;
assign fwd_a = forward_opa & src_a_used;
assign fwd_b = forward_opb & src_b_used;

//Destination register / write-enable for the instruction now in OF.
//CMP, STORE*, branches, JMP*, RET, HALT, NOP do not write a register.
//CALL writes LR (R15), not the Rd field.
reg [3:0] decoded_dest;
reg       reg_write;
always@(*) begin
        decoded_dest = if_of_instruction[`destination_register];
        reg_write = 1'b0;
        case(opcode)
        `add, `sub, `mul, `and_gate, `or_gate, `xor_gate, `eq, `shl, `shr, `sar, `rol, `ror, `slt, `sltu,
        `not_gate, `mov, `addi, `subi, `andi, `ori, `xori,
        `lui, `load_imm, `load, `load_ind: reg_write = 1'b1;
        `call: begin reg_write = 1'b1; decoded_dest = 4'd15; end
        default: reg_write = 1'b0;
        endcase
end

//OF/EX control latch
//flush and load_use_stall both insert a bubble (NOP, no register write).
//stall holds the latch as is.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                of_ex_branch_target <= 12'd0;
                of_ex_pc <= 12'd0;
                of_ex_opcode <= 8'd0;
                of_ex_destination_register <= 4'd0;
                of_ex_reg_write <= 1'b0;
        end
        else begin
                if(flush) begin
                        of_ex_pc <= 12'd0;
                        of_ex_branch_target <= 12'd0;
                        of_ex_opcode <= 8'd0;
                        of_ex_destination_register <= 4'd0;
                        of_ex_reg_write <= 1'b0;
                end
                else if(~stall) begin
                        if(load_use_stall) begin
                                of_ex_pc <= 12'd0;
                                of_ex_branch_target <= 12'd0;
                                of_ex_opcode <= 8'd0;
                                of_ex_destination_register <= 4'd0;
                                of_ex_reg_write <= 1'b0;
                        end
                        else begin
                                of_ex_pc <= if_of_pc;
                                of_ex_branch_target <= branch_target;
                                of_ex_opcode <= opcode;
                                of_ex_destination_register <= decoded_dest;
                                of_ex_reg_write <= reg_write;
                        end
                end
        end
end

//OF/EX operand latch (same hold/bubble rules as the control latch)
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin  
                of_ex_operanda <= 0;
                of_ex_operandb <= 0;
        end
        else begin
                if(flush) begin
                        of_ex_operanda <= 0;
                        of_ex_operandb <= 0;
                end 
                else if(~stall) begin
                        if(load_use_stall) begin
                                of_ex_operanda <= 0;
                                of_ex_operandb <= 0;
                        end
                        else if(hazard_detected) begin
                                of_ex_operanda <= fwd_a ? hazard_forwarded_value_opa : operand_a;
                                of_ex_operandb <= fwd_b ? hazard_forwarded_value_opb : operand_b;
                        end
                        else begin 
                                of_ex_operanda <= operand_a;
                                of_ex_operandb <= operand_b;
                        end
                end
        end
end 
//PSR bit positions (spec 2.3): Z=[0] N=[1] C=[2] V=[3]

reg [3:0] psr_temp;
reg [31:0] alu_result;
reg [63:0] rotate_temp;
wire [4:0] shift_amount;
assign shift_amount = of_ex_operandb[4:0];   //shifts/rotates take the amount from Rs2[4:0]

//Execute Stage
always@(*) begin
        psr_temp = ex_of_program_status_register;
        alu_result = 32'd0;
        rotate_temp = 64'd0;
        case(of_ex_opcode)
        //ADD/ADDI: Z N C V
        `add, `addi: begin
                {psr_temp[`carry_flag], alu_result} = {1'b0, of_ex_operanda} + {1'b0, of_ex_operandb};
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
                psr_temp[`overflow_flag] = (of_ex_operanda[31] == of_ex_operandb[31]) & (alu_result[31] != of_ex_operanda[31]);
        end
        //SUB/SUBI/CMP: Z N C V, C = 1 means no borrow (a >= b unsigned). CMP has no write-back (reg_write = 0 in OF)
        `sub, `subi, `cmp: begin
                {psr_temp[`carry_flag], alu_result} = {1'b0, of_ex_operanda} + {1'b0, ~of_ex_operandb} + 33'd1;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
                psr_temp[`overflow_flag] = (of_ex_operanda[31] != of_ex_operandb[31]) & (alu_result[31] != of_ex_operanda[31]);
        end
        //MUL: Z N. Single cycle, low 32 bits of the product
        `mul: begin
                alu_result = of_ex_operanda * of_ex_operandb;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        //Logic ops: Z N
        `and_gate, `andi: begin
                alu_result = of_ex_operanda & of_ex_operandb;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        `or_gate, `ori: begin
                alu_result = of_ex_operanda | of_ex_operandb;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        `xor_gate, `xori: begin
                alu_result = of_ex_operanda ^ of_ex_operandb;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        `not_gate: begin
                alu_result = ~of_ex_operanda;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        //Shifts: Z N
        `shl: begin
                alu_result = of_ex_operanda << shift_amount;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        `shr: begin
                alu_result = of_ex_operanda >> shift_amount;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        `sar: begin
                alu_result = $signed(of_ex_operanda) >>> shift_amount;
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        //Rotates: Z N. Doubling the operand turns the rotate into a plain shift
        `rol: begin
                rotate_temp = {of_ex_operanda, of_ex_operanda} << shift_amount;
                alu_result = rotate_temp[63:32];
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        `ror: begin
                rotate_temp = {of_ex_operanda, of_ex_operanda} >> shift_amount;
                alu_result = rotate_temp[31:0];
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        //Compare-to-register ops: Z only (Z follows the 0/1 result, so Z = 1 when the compare is false)
        `eq: begin
                alu_result = {31'd0, (of_ex_operanda == of_ex_operandb)};
                psr_temp[`zero_flag] = (alu_result == 32'd0);
        end
        `slt: begin
                alu_result = {31'd0, ($signed(of_ex_operanda) < $signed(of_ex_operandb))};
                psr_temp[`zero_flag] = (alu_result == 32'd0);
        end
        `sltu: begin
                alu_result = {31'd0, (of_ex_operanda < of_ex_operandb)};
                psr_temp[`zero_flag] = (alu_result == 32'd0);
        end
        //Moves and immediates: no flags
        `mov: alu_result = of_ex_operanda;
        `load_imm: alu_result = of_ex_operandb;
        `lui: alu_result = {of_ex_operandb[11:0], 20'd0};   //Rd <- {IMM, 20'b0}
        //Load/store: the result is the address (MEM uses [13:0]); store data travels separately as of_ex_operandb. No flags
        `load, `load_ind, `store, `store_ind: alu_result = of_ex_operanda;
        //CALL: LR (R15) <- return address. No flags
        `call: alu_result = {20'd0, of_ex_pc} + 32'd1;
        //NOP, JMP, JMP_IF, BEQ/BNE/BLT/BGE/BLTU/BGEU, JMP_REG, RET, HALT: no result, no flags
        default: begin
                alu_result = 32'd0;
                psr_temp = ex_of_program_status_register;
        end
        endcase
end

always@(posedge clk_cpu or negedge rst) begin
        if(~rst) ex_of_program_status_register <= 4'd0;
        else if(~stall) ex_of_program_status_register <= psr_temp;
end
endmodule
