
//////////////////////////////////////////////////////////////////////////////
//Async FIFO with SRAM storage (SAED32 SRAM2RW32x32, 16 words x 32 bits)
//Port 1 -> write side (wclk), Port 2 -> read side (rclk).
//The SRAM read is synchronous, so the read address is driven with the NEXT
//read pointer. After every rclk edge read_dataout = mem[b_rptr], which is the
//same behaviour as the old combinational register-array read.
//The macro is fixed at 32x32, so ADDR_WIDTH = 4 and DATA_WIDTH = 32.
//////////////////////////////////////////////////////////////////////////////
module async_fifo #(parameter ADDR_WIDTH = 5, parameter DATA_WIDTH = 32) (wclk, wen, wrst, write_datain, rclk, ren, rrst, read_dataout, empty, full);
input wclk, wen, wrst, rclk, ren, rrst;
output wire empty;
output wire full;
input  [DATA_WIDTH-1:0] write_datain;
output wire [DATA_WIDTH-1:0] read_dataout;
wire [ADDR_WIDTH:0] b_wptr, g_wptr, b_rptr, g_rptr;

write_pointer_handler #(.ADDR_WIDTH(ADDR_WIDTH)) w1(wclk, wen, wrst, g_wptr, b_wptr, g_rptr, full);
read_pointer_handler  #(.ADDR_WIDTH(ADDR_WIDTH)) w2(rclk, ren, rrst, g_rptr, b_rptr, g_wptr, empty);

//Read address = pointer value after this clock edge (next pointer)
wire [ADDR_WIDTH:0] b_rptr_next;
assign b_rptr_next = (ren & !empty) ? b_rptr + 1'b1 : b_rptr;

wire sram_wr_en;
assign sram_wr_en = wen & !full;

wire [DATA_WIDTH-1:0] sram_o1_unused;

SRAM2RW32x32 fifo_sram(
        //Port 1: write only
        .A1(b_wptr[ADDR_WIDTH-1:0]), .CE1(wclk), .WEB1(~sram_wr_en), .OEB1(1'b1), .CSB1(~sram_wr_en), .I1(write_datain), .O1(sram_o1_unused),
        //Port 2: read only, enabled every cycle
        .A2(b_rptr_next[ADDR_WIDTH-1:0]), .CE2(rclk), .WEB2(1'b1), .OEB2(1'b0), .CSB2(1'b0), .I2({DATA_WIDTH{1'b0}}), .O2(read_dataout)
);
endmodule


module read_pointer_handler #(parameter ADDR_WIDTH = 2) (rclk, ren, rrst, g_rptr, b_rptr, g_wptr, empty);
input rclk, ren, rrst;
input [ADDR_WIDTH:0] g_wptr;
output reg [ADDR_WIDTH:0] b_rptr, g_rptr;
output empty;
reg [ADDR_WIDTH:0] g_wptr_sync, sync1;

//Dual rank synchronizer
always@(posedge rclk or negedge rrst)begin
        if(!rrst) sync1 <= 0;
        else sync1 <= g_wptr;
end
always@(posedge rclk or negedge rrst)begin
        if(!rrst) g_wptr_sync <= 0;
        else g_wptr_sync <= sync1;
end

//Read pointer management
always@(posedge rclk or negedge rrst)begin
        if(~rrst) b_rptr <= 0;
        else if (ren & !empty) b_rptr <= b_rptr + 1;
end

wire [ADDR_WIDTH:0] g_rptr_temp;
//Conversion of binary to gray coded read pointer for domain crossing to write
//pointer handler
assign g_rptr_temp = b_rptr ^ (b_rptr >> 1);

//Latching gray coded read pointer for domain crossing because directly
//transmitting combo block output to different domain can cause glitch
always@(posedge rclk or negedge rrst)begin
        if(!rrst) g_rptr <= 0;
        else g_rptr <= g_rptr_temp;
end

reg [ADDR_WIDTH:0] b_wptr;
//Convert synchronized gray coded write pointer to binary coded.
integer i;
always@(*)begin
        b_wptr[ADDR_WIDTH] = g_wptr_sync[ADDR_WIDTH];
        for(i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                b_wptr[i] = b_wptr[i+1] ^ g_wptr_sync[i];
end

//Driving empty signal
assign empty = (b_wptr[ADDR_WIDTH] == b_rptr[ADDR_WIDTH]) & (b_wptr[ADDR_WIDTH-1:0] == b_rptr[ADDR_WIDTH-1:0]);
endmodule


module write_pointer_handler #(parameter ADDR_WIDTH = 2) (wclk, wen, wrst, g_wptr, b_wptr, g_rptr, full);
input wclk, wen, wrst;
input [ADDR_WIDTH:0] g_rptr;
output reg [ADDR_WIDTH:0] g_wptr, b_wptr;
reg [ADDR_WIDTH:0] sync1, g_rptr_sync;
output wire full;
reg [ADDR_WIDTH:0] b_rptr;

always@(posedge wclk or negedge wrst)begin
        if(!wrst) b_wptr <= 0;
        else if(wen & !full) b_wptr <= b_wptr + 1;
end

wire [ADDR_WIDTH:0] g_wptr_temp;
assign g_wptr_temp = b_wptr ^ (b_wptr >> 1);

always@(posedge wclk or negedge wrst)begin
        if(!wrst) g_wptr <= 0;
        else g_wptr <= g_wptr_temp;
end

//Dual rank synchronizer for gray coded read pointer from rclk domain
always@(posedge wclk or negedge wrst)begin
        if(!wrst) sync1 <= 0;
        else sync1 <= g_rptr;
end
always@(posedge wclk or negedge wrst)begin
        if(!wrst) g_rptr_sync <= 0;
        else g_rptr_sync <= sync1;
end

//Conversion of synchronized gray coded read pointer to binary coded
integer i;
always@(*)begin
        b_rptr[ADDR_WIDTH] = g_rptr_sync[ADDR_WIDTH];
        for(i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                b_rptr[i] = b_rptr[i+1] ^ g_rptr_sync[i];
end

assign full = (b_rptr[ADDR_WIDTH] != b_wptr[ADDR_WIDTH]) & (b_wptr[ADDR_WIDTH-1:0] == b_rptr[ADDR_WIDTH-1:0]);
endmodule

