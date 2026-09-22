module tx_fifo_read_handler(clk_mem, rst, fifo_empty, fifo_read_data, mem_dataout, ren, mem_addr, mem_en, mem_rwbar, wen, mem_datain, rx_fifo_write_data, done);
input clk_mem, rst, fifo_empty;
input [31:0] fifo_read_data, mem_dataout;
output reg ren, mem_en, mem_rwbar, wen;
output reg [13:0] mem_addr;
output reg [31:0] mem_datain;
output [31:0] rx_fifo_write_data;
output done;
localparam [2:0] idle = 3'd0, read_control_signals = 3'd1, read_start_address = 3'd2, write_to_memory = 3'd3, read_from_memory= 3'd4, memory_access_done = 3'd5, read_drain = 3'd6;
reg [2:0] current_state, next_state;

//data_memory registers its output (data_out <= memory[addr]), so the word for
//an address issued in read_from_memory only becomes valid on mem_dataout one
//cycle later. mem_read_active_d marks that "one cycle later" cycle so we push
//the correctly-aligned word into the RX FIFO instead of the stale/early one.
reg mem_read_active_d;
always@(posedge clk_mem or negedge rst) begin
        if(~rst) mem_read_active_d <= 1'b0;
        else mem_read_active_d <= (current_state == read_from_memory);
end
always@(posedge clk_mem or negedge rst) begin
        if(~rst) current_state <= idle;
        else current_state <= next_state;
end

reg [3:0] count_word;
always@(posedge clk_mem or negedge rst) begin
        if(~rst) count_word <= 4'd0;
        else if ((current_state == write_to_memory && ~fifo_empty) | current_state == read_from_memory) count_word <= count_word + 1'b1;
        else if (current_state != write_to_memory && current_state != read_from_memory) count_word <= 4'd0;
end
//The first word pushed into the TX FIFO from the clk_cpu domain is control
//signal, the LSB of the first word indicates whether the L1 cache wants to
//read/write from the data_memory
reg rw_bit;
always@(posedge clk_mem or negedge rst) begin
        if(~rst) rw_bit <= 1'b0;
        else if (current_state == read_control_signals & ~fifo_empty) rw_bit <= fifo_read_data[0];
end

reg [13:0] addr_reg;
always@(posedge clk_mem or negedge rst) begin
        if(~rst) addr_reg <= 14'd0;
        else if (current_state == read_start_address & ~fifo_empty) addr_reg <= fifo_read_data[13:0];
        else if ((current_state == write_to_memory && ~fifo_empty) | current_state == read_from_memory) addr_reg <= addr_reg + 1'b1;
end

always@(*) begin
        case(current_state)
        idle: next_state = fifo_empty ? idle : read_control_signals;
        read_control_signals: next_state = fifo_empty ? read_control_signals : read_start_address;
        read_start_address: next_state = fifo_empty ? read_start_address : (rw_bit ? read_from_memory : write_to_memory);
        write_to_memory: next_state = fifo_empty ? write_to_memory : (count_word == 4'd15 ? memory_access_done : write_to_memory);
        read_from_memory: next_state = (count_word == 4'd15) ? read_drain : read_from_memory;
        read_drain: next_state = memory_access_done;
        memory_access_done: next_state = idle;
        default: next_state = idle;
        endcase
end

always@(*) begin
        case(current_state)
        idle: begin
                mem_en = 1'b0;
                ren = 1'b0;
                wen = 1'b0;
                mem_rwbar = 1'b1; //By Default read_writebar is kept as 1'b1 because worst case scenario, reading data from data_memory has negligible consequences compared to writing into data_memory
                mem_addr = 14'd0;
                mem_datain = 0;
        end
        read_control_signals: begin
                mem_en = 1'b0;
                ren = ~fifo_empty;
                wen = 1'b0;
                mem_rwbar = 1'b1;
                mem_addr = 14'd0;
                mem_datain = 0;
        end
        read_start_address: begin
                mem_en = 1'b0;
                ren = ~fifo_empty;
                wen = 1'b0;
                mem_rwbar = 1'b1;
                mem_addr = 14'd0;
                mem_datain = 0;
        end
        write_to_memory: begin
                mem_en = ~fifo_empty;
                ren = ~fifo_empty;
                wen = 1'b0;
                mem_rwbar = 1'b0;
                mem_addr = addr_reg;
                mem_datain = fifo_read_data;
        end
        read_from_memory: begin
                mem_en = 1'b1;
                ren = 1'b0;
                wen = mem_read_active_d;
                mem_rwbar = 1'b1;
                mem_addr = addr_reg;
                mem_datain = 0;
        end
        read_drain: begin
                mem_en = 1'b0;
                ren = 1'b0;
                wen = mem_read_active_d;
                mem_rwbar = 1'b1;
                mem_addr = 14'd0;
                mem_datain = 0;
        end
        memory_access_done: begin
                mem_en = 1'b0;
                ren = 1'b0;
                wen = 1'b0;
                mem_rwbar = 1'b1;
                mem_addr = 14'd0;
                mem_datain = 0;
        end
        default: begin
                mem_en = 1'b0;
                ren = 1'b0;
                wen = 1'b0;
                mem_rwbar = 1'b1;
                mem_addr = 14'd0;
                mem_datain = 0;
        end
        endcase
end
assign rx_fifo_write_data = mem_read_active_d ? mem_dataout : 32'd0;
assign done = current_state == memory_access_done;
endmodule
