`define valid_bit 4'd15
`define dirty_bit 4'd14
`define tag_bits 13:9
`define offset_bits 3:0
`define load_data 2'b00
`define store_data 2'b01
`define store_stack 2'b10
`define stack_retrieve 2'b11
`define zero 2'b00
`define negative 2'b01
`define carry 2'b10
`define overflow 2'b11

//Opcodes - Core (mandatory)
`define nop 8'h00
`define load 8'h01
`define load_ind 8'h02
`define load_imm 8'h03
`define store 8'h04
`define store_ind 8'h05
`define add 8'h06
`define sub 8'h07
`define mul 8'h08
`define and_gate 8'h09
`define or_gate 8'h0A
`define not_gate 8'h0B
`define cmp 8'h0C
`define eq 8'h0D
`define jmp 8'h0E
`define jmp_if 8'h0F
`define shl 8'h11
`define shr 8'h12
`define sar 8'h13
`define addi 8'h16
`define subi 8'h17
`define beq 8'h20
`define bne 8'h21
`define blt 8'h22
`define bge 8'h23
`define halt 8'hFF

//Opcodes - Optional
`define xor_gate 8'h10
`define rol 8'h14
`define ror 8'h15
`define andi 8'h18
`define ori 8'h19
`define xori 8'h1A
`define mov 8'h1B
`define slt 8'h1C
`define sltu 8'h1D
`define lui 8'h1E
`define bltu 8'h24
`define bgeu 8'h25
`define jmp_reg 8'h26
`define call 8'h27
`define ret 8'h28

//Instruction Format
`define opcode 31:24
`define destination_register 23:20
`define operand_a 19:16
`define operand_b 15:12
`define immediate_address 11:0


//Program Status Register
`define zero_flag 2'b00
`define negative_flag 2'b01
`define carry_flag 2'b10
`define overflow_flag 2'b11
