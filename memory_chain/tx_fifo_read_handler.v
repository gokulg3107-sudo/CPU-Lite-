module tx_fifo_read_handler(clk_mem, rst, fifo_empty, fifo_read_data, mem_dataout, mem_valid, ren, mem_addr, mem_en, mem_rwbar, wen, mem_datain, rx_fifo_write_data, done);
input clk_mem, rst, fifo_empty, mem_valid;
input [31:0] fifo_read_data, mem_dataout;
output reg ren, mem_en, mem_rwbar, wen;
output reg [13:0] mem_addr;
output reg [31:0] mem_datain;
output [31:0] rx_fifo_write_data;
output done;
localparam [2:0] idle = 3'd0, read_control_signals = 3'd1, read_start_address = 3'd2, write_issue = 3'd3, write_wait = 3'd4, read_issue = 3'd5, read_wait = 3'd6, memory_access_done = 3'd7;
reg [2:0] current_state, next_state;

//Every word access to data_memory is split into two states. In *_issue the
//access (mem_en, address, data) is presented for one cycle. In *_wait the
//handler holds address/data steady and waits for mem_valid, which tells us the
//access is complete: for a read, mem_dataout is valid in that same cycle; for a
//write, the word is committed and the next word can be issued. The TX FIFO word
//is only popped (ren) once mem_valid is seen, so fifo_read_data stays stable
//for the whole access.
wire access_complete;
assign access_complete = (current_state == write_wait | current_state == read_wait) & mem_valid;

always@(posedge clk_mem or negedge rst) begin
        if(~rst) current_state <= idle;
        else current_state <= next_state;
end

reg [3:0] count_word;
always@(posedge clk_mem or negedge rst) begin
        if(~rst) count_word <= 4'd0;
        else if (access_complete) count_word <= count_word + 1'b1;
        else if (current_state != write_issue && current_state != write_wait && current_state != read_issue && current_state != read_wait) count_word <= 4'd0;
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
        else if (access_complete) addr_reg <= addr_reg + 1'b1;
end

always@(*) begin
        case(current_state)
        idle: next_state = fifo_empty ? idle : read_control_signals;
        read_control_signals: next_state = fifo_empty ? read_control_signals : read_start_address;
        read_start_address: next_state = fifo_empty ? read_start_address : (rw_bit ? read_issue : write_issue);
        write_issue: next_state = fifo_empty ? write_issue : write_wait;
        write_wait: next_state = mem_valid ? (count_word == 4'd15 ? memory_access_done : write_issue) : write_wait;
        read_issue: next_state = read_wait;
        read_wait: next_state = mem_valid ? (count_word == 4'd15 ? memory_access_done : read_issue) : read_wait;
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
        write_issue: begin
                mem_en = ~fifo_empty;
                ren = 1'b0;
                wen = 1'b0;
                mem_rwbar = 1'b0;
                mem_addr = addr_reg;
                mem_datain = fifo_read_data;
        end
        write_wait: begin
                mem_en = 1'b0;
                ren = mem_valid;
                wen = 1'b0;
                mem_rwbar = 1'b0;
                mem_addr = addr_reg;
                mem_datain = fifo_read_data;
        end
        read_issue: begin
                mem_en = 1'b1;
                ren = 1'b0;
                wen = 1'b0;
                mem_rwbar = 1'b1;
                mem_addr = addr_reg;
                mem_datain = 0;
        end
        read_wait: begin
                mem_en = 1'b0;
                ren = 1'b0;
                wen = mem_valid;
                mem_rwbar = 1'b1;
                mem_addr = addr_reg;
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
assign rx_fifo_write_data = mem_dataout;
assign done = current_state == memory_access_done;
endmodule
