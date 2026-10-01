`include "header_file.h"
module cpu_core(clk_cpu, rst, program_memory_data, program_memory_addr, cache_done, cache_start, cache_control, cache_addr, cache_data_bus, cache_data_in, halted);
input clk_cpu, rst, cache_done;
input [31:0] program_memory_data;
input [31:0] cache_data_in;          //load data coming back from the L1 cache (l1_cache data_out)
output [11:0] program_memory_addr;
output cache_start;
output [1:0] cache_control;          //`load_data / `store_data / `store_stack / `stack_retrieve
output [13:0] cache_addr;
output [31:0] cache_data_bus;        //store data going to the L1 cache (l1_cache cpu_data_in)
output reg halted;

//stall          : MEM busy (cache access) -> hold PC, IF/OF and OF/EX
//load_use_stall : OF must wait for load data -> hold PC and IF/OF, push a bubble into OF/EX
//flush          : redirect taken by the instruction in EX -> redirect PC, clear IF/OF and OF/EX
wire stall, flush, load_use_stall;

//Hazard unit
wire hazard_detected, forward_opa, forward_opb;
wire [31:0] hazard_forwarded_value_opa, hazard_forwarded_value_opb;

//RW stage (register file write port)
wire rw_wen;
wire [3:0] rw_waddr;
wire [31:0] rw_wdata;

//Hardware call stack engine (CALL pushes R0..R15 as one line, RET pops it).
//Declared here because the register file write port below uses them; logic is in the MEM section.
reg  [2:0]  stk_state, stk_next_state;
reg  [3:0]  stk_idx;
wire        stk_reg_wen, stk_sp_wen;
wire [31:0] stk_sp_val;

//PSR bit positions (spec 2.3): `zero_flag / `negative_flag / `carry_flag / `overflow_flag from header_file.h

reg [11:0] branch_target;
reg [11:0] pc;
reg [31:0] if_of_instruction;
reg [11:0] if_of_pc;

reg [7:0]  of_ex_opcode;
reg [31:0] of_ex_operanda, of_ex_operandb;
reg [11:0] of_ex_branch_target;   //registered - belongs to the instruction now in EX
reg [11:0] of_ex_pc;
reg [3:0]  of_ex_destination_register;   //registered - Rd of the instruction now in EX
reg        of_ex_reg_write;              //1 only if the instruction in EX writes a register

reg [3:0]  ex_of_program_status_register;   //PSR: [0]=Z [1]=N [2]=C [3]=V

reg [7:0]  ex_mem_opcode;
reg [31:0] ex_mem_result;          //ALU result, or the address for load/store
reg [31:0] ex_mem_store_data;
reg [3:0]  ex_mem_destination_register;
reg ex_mem_reg_write;

reg [31:0] mem_rw_result;
reg [3:0]  mem_rw_destination_register;
reg mem_rw_reg_write;

assign program_memory_addr = pc;

integer i;
reg [31:0] general_purpose_register[0:15];
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                for (i = 0; i < 16; i = i + 1) begin
			if(i == 14) general_purpose_register[i] <= 32'h3FFF;
			else general_purpose_register[i] <= 0;
		end
        end
        else begin
                if(rw_wen) general_purpose_register[rw_waddr] <= rw_wdata;
                //Stack engine ports. The RW stage only holds bubbles while a CALL/RET is
                //in MEM (mem_busy), so these never collide with rw_wen.
                if(stk_reg_wen) general_purpose_register[stk_idx] <= cache_data_in;   //RET restore
                if(stk_sp_wen)  general_purpose_register[14] <= stk_sp_val;           //CALL SP update
        end
end

//Register read with write-through: if RW is writing the register on this same
//edge, OF sees the new value instead of the stale one.
//One wire per distinct read address used below (replaces the former gpr_read function).
wire [3:0]  gpr_ra_addr, gpr_rb_addr, gpr_rd_addr;
assign gpr_ra_addr = if_of_instruction[`operand_a];
assign gpr_rb_addr = if_of_instruction[`operand_b];
assign gpr_rd_addr = if_of_instruction[`destination_register];

wire [31:0] gpr_ra, gpr_rb, gpr_rd, gpr_r15;
assign gpr_ra  = (rw_wen && (rw_waddr == gpr_ra_addr)) ? rw_wdata : general_purpose_register[gpr_ra_addr];
assign gpr_rb  = (rw_wen && (rw_waddr == gpr_rb_addr)) ? rw_wdata : general_purpose_register[gpr_rb_addr];
assign gpr_rd  = (rw_wen && (rw_waddr == gpr_rd_addr)) ? rw_wdata : general_purpose_register[gpr_rd_addr];
assign gpr_r15 = (rw_wen && (rw_waddr == 4'd15)) ? rw_wdata : general_purpose_register[15];

//PC: flush redirects (flush has priority over stall). RET/JMP_REG take the
//target from EX operand A (already forwarded), HALT parks on its own PC,
//everything else uses the registered branch target. Otherwise fetch the next
//sequential instruction unless the front end is being held.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) pc <= 12'd0;
        else begin
                if(flush) begin
                        if(of_ex_opcode == `ret || of_ex_opcode == `jmp_reg) pc <= of_ex_operanda[11:0];
                        else if(of_ex_opcode == `halt) pc <= of_ex_pc;
                        else pc <= of_ex_branch_target;
                end
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
                operand_a = gpr_ra;
                operand_b = gpr_rb;
        end
        //Single register source: NOT, MOV, LOAD_IND (address), JMP_IF (condition), JMP_REG (target)
        `not_gate, `mov, `load_ind, `jmp_if, `jmp_reg: operand_a = gpr_ra;
        //ADDI/SUBI sign-extend the immediate
        `addi, `subi: begin
                operand_a = gpr_ra;
                operand_b = {{20{immediate_addr[11]}}, immediate_addr};
        end
        //ANDI/ORI/XORI zero-extend the immediate
        `andi, `ori, `xori: begin
                operand_a = gpr_ra;
                operand_b = {20'd0, immediate_addr};
        end
        //LUI/LOAD_IMM: immediate goes on operand B, zero-extended
        `lui, `load_imm: operand_b = {20'd0, immediate_addr};
        //Direct LOAD: address on operand A
        `load: operand_a = {20'd0, immediate_addr};
        //Direct STORE: address on operand A, data (Rd) on operand B
        `store: begin
                operand_a = {20'd0, immediate_addr};
                operand_b = gpr_rd;
        end
        //STORE_IND: address is Rs2, data is Rd
        `store_ind: begin
                operand_a = gpr_rb;
                operand_b = gpr_rd;
        end
        //RET: target comes from LR (R15)
        `ret: operand_a = gpr_r15;
        //NOP, HALT, JMP, BEQ/BNE/BLT/BGE/BLTU/BGEU, CALL: no register operands
        default: begin operand_a = 0; operand_b = 0; end
        endcase
end

//Which register (if any) each operand slot actually reads. The hazard unit
//compares these against EX/MEM destinations, so an immediate in the operand
//field (ADDI etc.) is never mistaken for a register source.
reg [3:0] src_a_reg, src_b_reg;
reg src_a_used, src_b_used;
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


//Execute Stage

//Every EX operation, MUL included, takes one cycle. The only source of stall is MEM.
wire mem_busy;
assign stall = mem_busy;

reg [31:0] alu_result;
reg        alu_c, alu_v;
reg [1:0]  flag_class;
localparam [1:0] FL_NONE = 2'd0, FL_ZN = 2'd1, FL_Z = 2'd2, FL_ZNCV = 2'd3;
reg [3:0]  psr_temp;
reg [63:0] rot_tmp;
wire [4:0] shift_amount;
assign shift_amount = of_ex_operandb[4:0];

always@(*) begin
        alu_result = 32'd0;
        alu_c = 1'b0;
        alu_v = 1'b0;
        flag_class = FL_NONE;
        rot_tmp = 64'd0;
        case(of_ex_opcode)
        `add, `addi: begin
                {alu_c, alu_result} = {1'b0, of_ex_operanda} + {1'b0, of_ex_operandb};
                alu_v = (of_ex_operanda[31] == of_ex_operandb[31]) & (alu_result[31] != of_ex_operanda[31]);
                flag_class = FL_ZNCV;
        end
        //C = 1 means no borrow (a >= b unsigned). CMP is a SUB with no write-back.
        `sub, `subi, `cmp: begin
                {alu_c, alu_result} = {1'b0, of_ex_operanda} + {1'b0, ~of_ex_operandb} + 33'd1;
                alu_v = (of_ex_operanda[31] != of_ex_operandb[31]) & (alu_result[31] != of_ex_operanda[31]);
                flag_class = FL_ZNCV;
        end
        `mul: begin alu_result = of_ex_operanda * of_ex_operandb; flag_class = FL_ZN; end
        `and_gate, `andi: begin alu_result = of_ex_operanda & of_ex_operandb; flag_class = FL_ZN; end
        `or_gate, `ori: begin alu_result = of_ex_operanda | of_ex_operandb; flag_class = FL_ZN; end
        `xor_gate, `xori: begin alu_result = of_ex_operanda ^ of_ex_operandb; flag_class = FL_ZN; end
        `not_gate: begin alu_result = ~of_ex_operanda; flag_class = FL_ZN; end
        `shl: begin alu_result = of_ex_operanda << shift_amount; flag_class = FL_ZN; end
        `shr: begin alu_result = of_ex_operanda >> shift_amount; flag_class = FL_ZN; end
        `sar: begin alu_result = $signed(of_ex_operanda) >>> shift_amount; flag_class = FL_ZN; end
        `rol: begin
                rot_tmp = {of_ex_operanda, of_ex_operanda} << shift_amount;
                alu_result = rot_tmp[63:32];
                flag_class = FL_ZN;
        end
        `ror: begin
                rot_tmp = {of_ex_operanda, of_ex_operanda} >> shift_amount;
                alu_result = rot_tmp[31:0];
                flag_class = FL_ZN;
        end
        `eq: begin alu_result = {31'd0, (of_ex_operanda == of_ex_operandb)}; flag_class = FL_Z; end
        `slt: begin alu_result = {31'd0, ($signed(of_ex_operanda) < $signed(of_ex_operandb))}; flag_class = FL_Z; end
        `sltu: begin alu_result = {31'd0, (of_ex_operanda < of_ex_operandb)}; flag_class = FL_Z; end
        `mov: alu_result = of_ex_operanda;
        `load_imm: alu_result = of_ex_operandb;
        `lui: alu_result = {of_ex_operandb[11:0], 20'd0};
        //Load/store: the result carries the address (14-bit for indirect, 12-bit for direct)
        `load, `load_ind, `store, `store_ind: alu_result = of_ex_operanda;
        //CALL: link register gets the return address
        `call: alu_result = {20'd0, of_ex_pc} + 32'd1;
        default: alu_result = 32'd0;
        endcase
end

//Flag update (Z N C V): only the flags listed in the spec for each instruction change
always@(*) begin
        psr_temp = ex_of_program_status_register;
        case(flag_class)
        FL_ZNCV: begin
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
                psr_temp[`carry_flag] = alu_c;
                psr_temp[`overflow_flag] = alu_v;
        end
        FL_ZN: begin
                psr_temp[`zero_flag] = (alu_result == 32'd0);
                psr_temp[`negative_flag] = alu_result[31];
        end
        FL_Z: psr_temp[`zero_flag] = (alu_result == 32'd0);
        default: psr_temp = ex_of_program_status_register;
        endcase
end

//The PSR only commits when the instruction in EX actually advances
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) ex_of_program_status_register <= 4'd0;
        else if(~stall) ex_of_program_status_register <= psr_temp;
end

//Redirect decision. Conditional branches read the registered PSR, which already
//holds the flags of the instruction directly ahead of the branch.
reg ex_redirect;
always@(*) begin
        case(of_ex_opcode)
        `jmp, `call, `ret, `jmp_reg, `halt: ex_redirect = 1'b1;
        `jmp_if: ex_redirect = (of_ex_operanda != 32'd0);
        `beq: ex_redirect =  ex_of_program_status_register[`zero_flag];
        `bne: ex_redirect = ~ex_of_program_status_register[`zero_flag];
        `blt: ex_redirect =  (ex_of_program_status_register[`negative_flag] ^ ex_of_program_status_register[`overflow_flag]);
        `bge: ex_redirect = ~(ex_of_program_status_register[`negative_flag] ^ ex_of_program_status_register[`overflow_flag]);
        `bltu: ex_redirect = ~ex_of_program_status_register[`carry_flag];
        `bgeu: ex_redirect =  ex_of_program_status_register[`carry_flag];
        default: ex_redirect = 1'b0;
        endcase
end
//An instruction in EX only takes effect when it advances
assign flush = ex_redirect & ~stall;

//HALT: stop execution. The flush keeps the instructions behind it from running.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) halted <= 1'b0;
        else if(of_ex_opcode == `halt & ~stall) halted <= 1'b1;
end

//EX/MEM pipeline register
//mem_busy: MEM has not finished, hold.
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                ex_mem_opcode <= 8'd0;
                ex_mem_result <= 32'd0;
                ex_mem_store_data <= 32'd0;
                ex_mem_destination_register <= 4'd0;
                ex_mem_reg_write <= 1'b0;
        end
        else if(~mem_busy) begin
                ex_mem_opcode <= of_ex_opcode;
                ex_mem_result <= alu_result;
                ex_mem_store_data <= of_ex_operandb;
                ex_mem_destination_register <= of_ex_destination_register;
                ex_mem_reg_write <= of_ex_reg_write;
        end
end


//Memory Stage (L1 cache access)

wire mem_is_load, mem_is_store, mem_op;
assign mem_is_load  = (ex_mem_opcode == `load) | (ex_mem_opcode == `load_ind);
assign mem_is_store = (ex_mem_opcode == `store) | (ex_mem_opcode == `store_ind);
assign mem_op = mem_is_load | mem_is_store;

//One start pulse per access, then wait for cache_done. Address, control and
//store data stay stable because EX/MEM holds while mem_busy.
reg mem_state;
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) mem_state <= 1'b0;
        else begin
                if(~mem_state) mem_state <= mem_op;
                else if(cache_done) mem_state <= 1'b0;
        end
end

//Hardware call stack (option 1).
//CALL: push R0..R15 (word k = Rk) as one 512-bit line with store_stack, then
//      SP <- base of the line below SP's line, i.e. {SP[13:4]-1, 4'b0}. That is
//      SP-16 rounded down to a line boundary, so the whole frame sits ABOVE the new SP
//      and a software pre-decrement push ([--SP]) can never land inside it.
//RET : stack_retrieve the line at SP and restore the registers in RESTORE_MASK.
//      Word 14 is the pre-CALL SP, so SP comes back exactly. R13 (return value) and
//      R15 (LR, managed by software) are not restored.
localparam [2:0]  STK_IDLE = 3'd0, STK_START = 3'd1, STK_FEED = 3'd2, STK_WAIT = 3'd3;
localparam [15:0] RESTORE_MASK = 16'h5FFF;   //R0-R12 and R14

wire mem_is_call, mem_is_ret, stk_op, stk_finish;
assign mem_is_call = (ex_mem_opcode == `call);
assign mem_is_ret  = (ex_mem_opcode == `ret);
assign stk_op      = mem_is_call | mem_is_ret;

wire [13:0] sp_now, frame_base;
assign sp_now     = general_purpose_register[14][13:0];
assign frame_base = {sp_now[13:4] - 10'd1, 4'b0000};

//IDLE : first cycle in MEM, lets the instruction ahead finish its register write
//START: one cache_start pulse (address/control latched by the interface)
//FEED : CALL only, R0..R15 on the data bus, one per cycle
//WAIT : CALL waits for cache_done; RET receives 16 words while cache_done is high

//Stack FSM - state register
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) stk_state <= STK_IDLE;
        else stk_state <= stk_next_state;
end

//Stack FSM - next state logic
always@(*) begin
        case(stk_state)
        STK_IDLE: stk_next_state = stk_op ? STK_START : STK_IDLE;
        STK_START: stk_next_state = mem_is_call ? STK_FEED : STK_WAIT;
        STK_FEED: stk_next_state = (stk_idx == 4'd15) ? STK_WAIT : STK_FEED;
        STK_WAIT: stk_next_state = stk_finish ? STK_IDLE : STK_WAIT;
        default: stk_next_state = STK_IDLE;
        endcase
end

//Stack word index counter
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) stk_idx <= 4'd0;
        else begin
                case(stk_state)
                STK_IDLE: stk_idx <= 4'd0;
                STK_FEED: stk_idx <= stk_idx + 1'b1;
                STK_WAIT: if(cache_done) stk_idx <= stk_idx + 1'b1;
                default: stk_idx <= stk_idx;
                endcase
        end
end
assign stk_finish  = (stk_state == STK_WAIT) & cache_done & (mem_is_call | (stk_idx == 4'd15));
assign stk_reg_wen = (stk_state == STK_WAIT) & mem_is_ret & cache_done & RESTORE_MASK[stk_idx];
assign stk_sp_wen  = stk_finish & mem_is_call;
assign stk_sp_val  = {18'd0, frame_base};

assign cache_start = (mem_op & ~mem_state) | (stk_state == STK_START);
assign cache_control = mem_is_call ? `store_stack : mem_is_ret ? `stack_retrieve : mem_is_load ? `load_data : `store_data;
assign cache_addr = mem_is_call ? frame_base : mem_is_ret ? sp_now : ex_mem_result[13:0];
assign cache_data_bus = (stk_state == STK_FEED) ? general_purpose_register[stk_idx] : ex_mem_store_data;
assign mem_busy = (mem_op & ~cache_done) | (stk_op & ~stk_finish);

//Value this instruction produces at the end of MEM (valid when ~mem_busy)
wire [31:0] mem_result;
assign mem_result = mem_is_load ? cache_data_in : ex_mem_result;

//MEM/RW pipeline register: bubble while the access is still in flight
always@(posedge clk_cpu or negedge rst) begin
        if(~rst) begin
                mem_rw_result <= 32'd0;
                mem_rw_destination_register <= 4'd0;
                mem_rw_reg_write <= 1'b0;
        end
        else if(mem_busy) begin
                mem_rw_result <= 32'd0;
                mem_rw_destination_register <= 4'd0;
                mem_rw_reg_write <= 1'b0;
        end
        else begin
                mem_rw_result <= mem_result;
                mem_rw_destination_register <= ex_mem_destination_register;
                mem_rw_reg_write <= ex_mem_reg_write;
        end
end


//Register Write stage

assign rw_wen = mem_rw_reg_write;
assign rw_waddr = mem_rw_destination_register;
assign rw_wdata = mem_rw_result;


//Hazard unit (consumer in OF, producers in EX and MEM; RW is covered by the
//register file write-through). EX is the youngest producer so it wins.

wire ex_is_load;
assign ex_is_load = (of_ex_opcode == `load) | (of_ex_opcode == `load_ind);

wire ex_match_a, ex_match_b, mem_match_a, mem_match_b;
assign ex_match_a  = of_ex_reg_write   & src_a_used & (of_ex_destination_register   == src_a_reg);
assign ex_match_b  = of_ex_reg_write   & src_b_used & (of_ex_destination_register   == src_b_reg);
assign mem_match_a = ex_mem_reg_write  & src_a_used & (ex_mem_destination_register  == src_a_reg);
assign mem_match_b = ex_mem_reg_write  & src_b_used & (ex_mem_destination_register  == src_b_reg);

//A load in EX has no data yet: hold OF (bubble into EX) until it reaches MEM and completes
assign load_use_stall = ex_is_load & (ex_match_a | ex_match_b);

assign forward_opa = ex_match_a | mem_match_a;
assign forward_opb = ex_match_b | mem_match_b;
assign hazard_detected = forward_opa | forward_opb;
assign hazard_forwarded_value_opa = ex_match_a ? alu_result : mem_result;
assign hazard_forwarded_value_opb = ex_match_b ? alu_result : mem_result;
endmodule
