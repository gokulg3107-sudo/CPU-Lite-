///////////////////////////////////////////////////////////////////////////////
//Basic Single Port Memory
//Active High Enable, asynchronous active low reset
//Whenever enable is asserted, based on the controler signal read_writebar
//If read_write_bar = 0 -> write operation on the given address. Else read
//operation on the given address, output is fed to data_out.
//Built from 32 x SRAM1RW512x32 (512 words each = 16384 words)
///////////////////////////////////////////////////////////////////////////////

module data_memory(clk_mem, rst, enable, read_writebar, data_in, addr, data_out, valid);
input clk_mem, rst, enable, read_writebar;
input [31:0] data_in;
input [13:0] addr;
output [31:0] data_out;
output valid;
assign valid = 1'b1;

reg [31:0] chip_enable;
wire [31:0] dout0, dout1, dout2, dout3, dout4, dout5, dout6, dout7, dout8, dout9, dout10, dout11, dout12, dout13, dout14, dout15, dout16, dout17, dout18, dout19, dout20, dout21, dout22, dout23, dout24, dout25, dout26, dout27, dout28, dout29, dout30, dout31;

always@(*)begin
        chip_enable = 32'd0;
        if(enable) begin
                if(addr < 14'd512) chip_enable = 32'd1;
                else if(addr < 14'd1024) chip_enable = 32'd2;
                else if(addr < 14'd1536) chip_enable = 32'd4;
                else if(addr < 14'd2048) chip_enable = 32'd8;
                else if(addr < 14'd2560) chip_enable = 32'd16;
                else if(addr < 14'd3072) chip_enable = 32'd32;
                else if(addr < 14'd3584) chip_enable = 32'd64;
                else if(addr < 14'd4096) chip_enable = 32'd128;
                else if(addr < 14'd4608) chip_enable = 32'd256;
                else if(addr < 14'd5120) chip_enable = 32'd512;
                else if(addr < 14'd5632) chip_enable = 32'd1024;
                else if(addr < 14'd6144) chip_enable = 32'd2048;
                else if(addr < 14'd6656) chip_enable = 32'd4096;
                else if(addr < 14'd7168) chip_enable = 32'd8192;
                else if(addr < 14'd7680) chip_enable = 32'd16384;
                else if(addr < 14'd8192) chip_enable = 32'd32768;
                else if(addr < 14'd8704) chip_enable = 32'd65536;
                else if(addr < 14'd9216) chip_enable = 32'd131072;
                else if(addr < 14'd9728) chip_enable = 32'd262144;
                else if(addr < 14'd10240) chip_enable = 32'd524288;
                else if(addr < 14'd10752) chip_enable = 32'd1048576;
                else if(addr < 14'd11264) chip_enable = 32'd2097152;
                else if(addr < 14'd11776) chip_enable = 32'd4194304;
                else if(addr < 14'd12288) chip_enable = 32'd8388608;
                else if(addr < 14'd12800) chip_enable = 32'd16777216;
                else if(addr < 14'd13312) chip_enable = 32'd33554432;
                else if(addr < 14'd13824) chip_enable = 32'd67108864;
                else if(addr < 14'd14336) chip_enable = 32'd134217728;
                else if(addr < 14'd14848) chip_enable = 32'd268435456;
                else if(addr < 14'd15360) chip_enable = 32'd536870912;
                else if(addr < 14'd15872) chip_enable = 32'd1073741824;
                else chip_enable = 32'd2147483648;
        end
end

//SRAM output is registered inside the macro (valid one clock after the access),
//so the bank select for the output mux is registered the same way
reg [4:0] bank_sel_q;
always@(posedge clk_mem or negedge rst)begin
        if(~rst) bank_sel_q <= 5'd0;
        else if(enable) bank_sel_q <= addr[13:9];
end

//CE is the SRAM clock, CSB (active low) is the bank select

SRAM1RW512x32 sram0(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[0]), .I(data_in), .O(dout0));
SRAM1RW512x32 sram1(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[1]), .I(data_in), .O(dout1));
SRAM1RW512x32 sram2(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[2]), .I(data_in), .O(dout2));
SRAM1RW512x32 sram3(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[3]), .I(data_in), .O(dout3));
SRAM1RW512x32 sram4(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[4]), .I(data_in), .O(dout4));
SRAM1RW512x32 sram5(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[5]), .I(data_in), .O(dout5));
SRAM1RW512x32 sram6(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[6]), .I(data_in), .O(dout6));
SRAM1RW512x32 sram7(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[7]), .I(data_in), .O(dout7));
SRAM1RW512x32 sram8(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[8]), .I(data_in), .O(dout8));
SRAM1RW512x32 sram9(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[9]), .I(data_in), .O(dout9));
SRAM1RW512x32 sram10(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[10]), .I(data_in), .O(dout10));
SRAM1RW512x32 sram11(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[11]), .I(data_in), .O(dout11));
SRAM1RW512x32 sram12(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[12]), .I(data_in), .O(dout12));
SRAM1RW512x32 sram13(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[13]), .I(data_in), .O(dout13));
SRAM1RW512x32 sram14(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[14]), .I(data_in), .O(dout14));
SRAM1RW512x32 sram15(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[15]), .I(data_in), .O(dout15));
SRAM1RW512x32 sram16(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[16]), .I(data_in), .O(dout16));
SRAM1RW512x32 sram17(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[17]), .I(data_in), .O(dout17));
SRAM1RW512x32 sram18(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[18]), .I(data_in), .O(dout18));
SRAM1RW512x32 sram19(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[19]), .I(data_in), .O(dout19));
SRAM1RW512x32 sram20(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[20]), .I(data_in), .O(dout20));
SRAM1RW512x32 sram21(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[21]), .I(data_in), .O(dout21));
SRAM1RW512x32 sram22(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[22]), .I(data_in), .O(dout22));
SRAM1RW512x32 sram23(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[23]), .I(data_in), .O(dout23));
SRAM1RW512x32 sram24(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[24]), .I(data_in), .O(dout24));
SRAM1RW512x32 sram25(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[25]), .I(data_in), .O(dout25));
SRAM1RW512x32 sram26(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[26]), .I(data_in), .O(dout26));
SRAM1RW512x32 sram27(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[27]), .I(data_in), .O(dout27));
SRAM1RW512x32 sram28(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[28]), .I(data_in), .O(dout28));
SRAM1RW512x32 sram29(.A(addr[8:0]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[29]), .I(data_in), .O(dout29));
SRAM1RW512x32 sram30(.A(addr[13:5]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[30]), .I(data_in), .O(dout30));
SRAM1RW512x32 sram31(.A(addr[13:5]), .CE(clk_mem), .WEB(read_writebar), .OEB(1'b0), .CSB(~chip_enable[31]), .I(data_in), .O(dout31));

reg [31:0] data_out_mux;
always@(*)begin
        case(bank_sel_q)
        5'd0: data_out_mux = dout0;
        5'd1: data_out_mux = dout1;
        5'd2: data_out_mux = dout2;
        5'd3: data_out_mux = dout3;
        5'd4: data_out_mux = dout4;
        5'd5: data_out_mux = dout5;
        5'd6: data_out_mux = dout6;
        5'd7: data_out_mux = dout7;
        5'd8: data_out_mux = dout8;
        5'd9: data_out_mux = dout9;
        5'd10: data_out_mux = dout10;
        5'd11: data_out_mux = dout11;
        5'd12: data_out_mux = dout12;
        5'd13: data_out_mux = dout13;
        5'd14: data_out_mux = dout14;
        5'd15: data_out_mux = dout15;
        5'd16: data_out_mux = dout16;
        5'd17: data_out_mux = dout17;
        5'd18: data_out_mux = dout18;
        5'd19: data_out_mux = dout19;
        5'd20: data_out_mux = dout20;
        5'd21: data_out_mux = dout21;
        5'd22: data_out_mux = dout22;
        5'd23: data_out_mux = dout23;
        5'd24: data_out_mux = dout24;
        5'd25: data_out_mux = dout25;
        5'd26: data_out_mux = dout26;
        5'd27: data_out_mux = dout27;
        5'd28: data_out_mux = dout28;
        5'd29: data_out_mux = dout29;
        5'd30: data_out_mux = dout30;
        5'd31: data_out_mux = dout31;
        default: data_out_mux = 32'd0;
        endcase
end
assign data_out = data_out_mux;

endmodule
