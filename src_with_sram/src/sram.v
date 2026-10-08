
/*********************************************************************
*  SAED_EDK90nm_SRAM : SRAM1RW512x32 Verilog description            *
*  ---------------------------------------------------------------   *
*  Filename      : SRAM1RW512x32.v                                  *
*  SRAM name     : SRAM1RW512x32                                    *
*  Word width    : 32    bits                                        *
*  Word number   : 512                                               *
*  Adress width  : 9     bits                                        *
**********************************************************************/



`define numAddr 9
`define numWords 512
`define wordLength 32


module SRAM1RW512x32 (A,CE,WEB,OEB,CSB,I,O);

input                           CE;
input                           WEB;
input                           OEB;
input                           CSB;

input   [`numAddr-1:0]          A;
input   [`wordLength-1:0]       I;
output  [`wordLength-1:0]       O;

/*reg   [`wordLength-1:0]       memory[`numWords-1:0];*/
/*reg   [`wordLength-1:0]       data_out;*/
wire    [`wordLength-1:0]       O;

wire                            RE;
wire                            WE;

SRAM1RW512x32_1bit sram_IO0 ( CE, WEB,  A, OEB, CSB, I[0], O[0]);
SRAM1RW512x32_1bit sram_IO1 ( CE, WEB,  A, OEB, CSB, I[1], O[1]);
SRAM1RW512x32_1bit sram_IO2 ( CE, WEB,  A, OEB, CSB, I[2], O[2]);
SRAM1RW512x32_1bit sram_IO3 ( CE, WEB,  A, OEB, CSB, I[3], O[3]);
SRAM1RW512x32_1bit sram_IO4 ( CE, WEB,  A, OEB, CSB, I[4], O[4]);
SRAM1RW512x32_1bit sram_IO5 ( CE, WEB,  A, OEB, CSB, I[5], O[5]);
SRAM1RW512x32_1bit sram_IO6 ( CE, WEB,  A, OEB, CSB, I[6], O[6]);
SRAM1RW512x32_1bit sram_IO7 ( CE, WEB,  A, OEB, CSB, I[7], O[7]);
SRAM1RW512x32_1bit sram_IO8 ( CE, WEB,  A, OEB, CSB, I[8], O[8]);
SRAM1RW512x32_1bit sram_IO9 ( CE, WEB,  A, OEB, CSB, I[9], O[9]);
SRAM1RW512x32_1bit sram_IO10 ( CE, WEB,  A, OEB, CSB, I[10], O[10]);
SRAM1RW512x32_1bit sram_IO11 ( CE, WEB,  A, OEB, CSB, I[11], O[11]);
SRAM1RW512x32_1bit sram_IO12 ( CE, WEB,  A, OEB, CSB, I[12], O[12]);
SRAM1RW512x32_1bit sram_IO13 ( CE, WEB,  A, OEB, CSB, I[13], O[13]);
SRAM1RW512x32_1bit sram_IO14 ( CE, WEB,  A, OEB, CSB, I[14], O[14]);
SRAM1RW512x32_1bit sram_IO15 ( CE, WEB,  A, OEB, CSB, I[15], O[15]);
SRAM1RW512x32_1bit sram_IO16 ( CE, WEB,  A, OEB, CSB, I[16], O[16]);
SRAM1RW512x32_1bit sram_IO17 ( CE, WEB,  A, OEB, CSB, I[17], O[17]);
SRAM1RW512x32_1bit sram_IO18 ( CE, WEB,  A, OEB, CSB, I[18], O[18]);
SRAM1RW512x32_1bit sram_IO19 ( CE, WEB,  A, OEB, CSB, I[19], O[19]);
SRAM1RW512x32_1bit sram_IO20 ( CE, WEB,  A, OEB, CSB, I[20], O[20]);
SRAM1RW512x32_1bit sram_IO21 ( CE, WEB,  A, OEB, CSB, I[21], O[21]);
SRAM1RW512x32_1bit sram_IO22 ( CE, WEB,  A, OEB, CSB, I[22], O[22]);
SRAM1RW512x32_1bit sram_IO23 ( CE, WEB,  A, OEB, CSB, I[23], O[23]);
SRAM1RW512x32_1bit sram_IO24 ( CE, WEB,  A, OEB, CSB, I[24], O[24]);
SRAM1RW512x32_1bit sram_IO25 ( CE, WEB,  A, OEB, CSB, I[25], O[25]);
SRAM1RW512x32_1bit sram_IO26 ( CE, WEB,  A, OEB, CSB, I[26], O[26]);
SRAM1RW512x32_1bit sram_IO27 ( CE, WEB,  A, OEB, CSB, I[27], O[27]);
SRAM1RW512x32_1bit sram_IO28 ( CE, WEB,  A, OEB, CSB, I[28], O[28]);
SRAM1RW512x32_1bit sram_IO29 ( CE, WEB,  A, OEB, CSB, I[29], O[29]);
SRAM1RW512x32_1bit sram_IO30 ( CE, WEB,  A, OEB, CSB, I[30], O[30]);
SRAM1RW512x32_1bit sram_IO31 ( CE, WEB,  A, OEB, CSB, I[31], O[31]);


endmodule


module SRAM1RW512x32_1bit (CE_i, WEB_i,  A_i, OEB_i, CSB_i, I_i, O_i);

input CSB_i;
input OEB_i;
input CE_i;
input WEB_i;

input   [`numAddr-1:0]  A_i;
input   [0:0] I_i;

output  [0:0] O_i;

reg     [0:0]O_i;
reg     [0:0]   memory[`numWords-1:0];
reg     [0:0]   data_out;


// Write Mode
and u1 (RE, ~CSB_i,  WEB_i);
and u2 (WE, ~CSB_i, ~WEB_i);


always @ (posedge CE_i)
        if (RE)
                data_out = memory[A_i];
always @ (posedge CE_i)
        if (WE)
                memory[A_i] = I_i;


always @ (data_out or OEB_i)
        if (!OEB_i)
                O_i = data_out;
        else
                O_i =  1'bz;


endmodule

/*********************************************************************
*  SAED_EDK90nm_SRAM : SRAM2RW32x32 Verilog description                 *
*  ---------------------------------------------------------------   *
*  Filename      : SRAM2RW32x32.v                                       *
*  SRAM name     : SRAM2RW32x32                                         *
*  Word width    : 32    bits                                        *
*  Word number   : 32                                                *
*  Adress width  : 5     bits                                        *
**********************************************************************/



`define numAddr 5
`define numWords 32
`define wordLength 32



module SRAM2RW32x32 (A1,A2,CE1,CE2,WEB1,WEB2,OEB1,OEB2,CSB1,CSB2,I1,I2,O1,O2);

input                           CE1;
input                           CE2;
input                           WEB1;
input                           WEB2;
input                           OEB1;
input                           OEB2;
input                           CSB1;
input                           CSB2;

input   [`numAddr-1:0]          A1;
input   [`numAddr-1:0]          A2;
input   [`wordLength-1:0]       I1;
input   [`wordLength-1:0]       I2;
output  [`wordLength-1:0]       O1;
output  [`wordLength-1:0]       O2;

/*reg   [`wordLength-1:0]       memory[`numWords-1:0];*/
/*reg   [`wordLength-1:0]       data_out1;*/
/*reg   [`wordLength-1:0]       data_out2;*/
wire    [`wordLength-1:0]       O1;
wire    [`wordLength-1:0]       O2;

wire                            RE1;
wire                            RE2;
wire                            WE1;
wire                            WE2;

SRAM2RW32x32_1bit sram_IO0 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[0], I2[0], O1[0], O2[0]);
SRAM2RW32x32_1bit sram_IO1 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[1], I2[1], O1[1], O2[1]);
SRAM2RW32x32_1bit sram_IO2 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[2], I2[2], O1[2], O2[2]);
SRAM2RW32x32_1bit sram_IO3 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[3], I2[3], O1[3], O2[3]);
SRAM2RW32x32_1bit sram_IO4 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[4], I2[4], O1[4], O2[4]);
SRAM2RW32x32_1bit sram_IO5 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[5], I2[5], O1[5], O2[5]);
SRAM2RW32x32_1bit sram_IO6 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[6], I2[6], O1[6], O2[6]);
SRAM2RW32x32_1bit sram_IO7 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[7], I2[7], O1[7], O2[7]);
SRAM2RW32x32_1bit sram_IO8 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[8], I2[8], O1[8], O2[8]);
SRAM2RW32x32_1bit sram_IO9 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[9], I2[9], O1[9], O2[9]);
SRAM2RW32x32_1bit sram_IO10 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[10], I2[10], O1[10], O2[10]);
SRAM2RW32x32_1bit sram_IO11 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[11], I2[11], O1[11], O2[11]);
SRAM2RW32x32_1bit sram_IO12 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[12], I2[12], O1[12], O2[12]);
SRAM2RW32x32_1bit sram_IO13 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[13], I2[13], O1[13], O2[13]);
SRAM2RW32x32_1bit sram_IO14 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[14], I2[14], O1[14], O2[14]);
SRAM2RW32x32_1bit sram_IO15 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[15], I2[15], O1[15], O2[15]);
SRAM2RW32x32_1bit sram_IO16 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[16], I2[16], O1[16], O2[16]);
SRAM2RW32x32_1bit sram_IO17 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[17], I2[17], O1[17], O2[17]);
SRAM2RW32x32_1bit sram_IO18 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[18], I2[18], O1[18], O2[18]);
SRAM2RW32x32_1bit sram_IO19 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[19], I2[19], O1[19], O2[19]);
SRAM2RW32x32_1bit sram_IO20 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[20], I2[20], O1[20], O2[20]);
SRAM2RW32x32_1bit sram_IO21 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[21], I2[21], O1[21], O2[21]);
SRAM2RW32x32_1bit sram_IO22 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[22], I2[22], O1[22], O2[22]);
SRAM2RW32x32_1bit sram_IO23 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[23], I2[23], O1[23], O2[23]);
SRAM2RW32x32_1bit sram_IO24 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[24], I2[24], O1[24], O2[24]);
SRAM2RW32x32_1bit sram_IO25 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[25], I2[25], O1[25], O2[25]);
SRAM2RW32x32_1bit sram_IO26 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[26], I2[26], O1[26], O2[26]);
SRAM2RW32x32_1bit sram_IO27 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[27], I2[27], O1[27], O2[27]);
SRAM2RW32x32_1bit sram_IO28 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[28], I2[28], O1[28], O2[28]);
SRAM2RW32x32_1bit sram_IO29 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[29], I2[29], O1[29], O2[29]);
SRAM2RW32x32_1bit sram_IO30 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[30], I2[30], O1[30], O2[30]);
SRAM2RW32x32_1bit sram_IO31 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[31], I2[31], O1[31], O2[31]);


endmodule


module SRAM2RW32x32_1bit (CE1_i, CE2_i, WEB1_i, WEB2_i,  A1_i, A2_i, OEB1_i, OEB2_i, CSB1_i, CSB2_i, I1_i, I2_i, O1_i, O2_i);

input   CSB1_i, CSB2_i;
input   OEB1_i, OEB2_i;
input   CE1_i, CE2_i;
input   WEB1_i, WEB2_i;

input   [`numAddr-1:0]  A1_i, A2_i;
input   [0:0] I1_i, I2_i;

output  [0:0] O1_i, O2_i;

reg     [0:0] O1_i, O2_i;
reg     [0:0]   memory[`numWords-1:0];
reg     [0:0]   data_out1, data_out2;


and u1 (RE1, ~CSB1_i,  WEB1_i);
and u2 (WE1, ~CSB1_i, ~WEB1_i);
and u3 (RE2, ~CSB2_i,  WEB2_i);
and u4 (WE2, ~CSB2_i, ~WEB2_i);

//Primary ports

always @ (posedge CE1_i)
        if (RE1)
                data_out1 = memory[A1_i];
always @ (posedge CE1_i)
        if (WE1)
                memory[A1_i] = I1_i;


always @ (data_out1 or OEB1_i)
        if (!OEB1_i)
                O1_i = data_out1;
        else
                O1_i =  1'bz;

//Dual ports
always @ (posedge CE2_i)
        if (RE2)
                data_out2 = memory[A2_i];
always @ (posedge CE2_i)
        if (WE2)
                memory[A2_i] = I2_i;

always @ (data_out2 or OEB2_i)
        if (!OEB2_i)
                O2_i = data_out2;
        else
                O2_i = 1'bz;

endmodule
/*********************************************************************
*  SAED_EDK90nm_SRAM : SRAM2RW32x8 Verilog description                  *
*  ---------------------------------------------------------------   *
*  Filename      : SRAM2RW32x8.v                                        *
*  SRAM name     : SRAM2RW32x8                                          *
*  Word width    : 8     bits                                        *
*  Word number   : 32                                                *
*  Adress width  : 5     bits                                        *
**********************************************************************/



`define numAddr 5
`define numWords 32
`define wordLength 8



module SRAM2RW32x8 (A1,A2,CE1,CE2,WEB1,WEB2,OEB1,OEB2,CSB1,CSB2,I1,I2,O1,O2);

input                           CE1;
input                           CE2;
input                           WEB1;
input                           WEB2;
input                           OEB1;
input                           OEB2;
input                           CSB1;
input                           CSB2;

input   [`numAddr-1:0]          A1;
input   [`numAddr-1:0]          A2;
input   [`wordLength-1:0]       I1;
input   [`wordLength-1:0]       I2;
output  [`wordLength-1:0]       O1;
output  [`wordLength-1:0]       O2;

/*reg   [`wordLength-1:0]       memory[`numWords-1:0];*/
/*reg   [`wordLength-1:0]       data_out1;*/
/*reg   [`wordLength-1:0]       data_out2;*/
wire    [`wordLength-1:0]       O1;
wire    [`wordLength-1:0]       O2;

wire                            RE1;
wire                            RE2;
wire                            WE1;
wire                            WE2;

SRAM2RW32x8_1bit sram_IO0 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[0], I2[0], O1[0], O2[0]);
SRAM2RW32x8_1bit sram_IO1 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[1], I2[1], O1[1], O2[1]);
SRAM2RW32x8_1bit sram_IO2 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[2], I2[2], O1[2], O2[2]);
SRAM2RW32x8_1bit sram_IO3 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[3], I2[3], O1[3], O2[3]);
SRAM2RW32x8_1bit sram_IO4 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[4], I2[4], O1[4], O2[4]);
SRAM2RW32x8_1bit sram_IO5 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[5], I2[5], O1[5], O2[5]);
SRAM2RW32x8_1bit sram_IO6 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[6], I2[6], O1[6], O2[6]);
SRAM2RW32x8_1bit sram_IO7 ( CE1, CE2, WEB1, WEB2,  A1, A2, OEB1, OEB2, CSB1, CSB2, I1[7], I2[7], O1[7], O2[7]);


endmodule


module SRAM2RW32x8_1bit (CE1_i, CE2_i, WEB1_i, WEB2_i,  A1_i, A2_i, OEB1_i, OEB2_i, CSB1_i, CSB2_i, I1_i, I2_i, O1_i, O2_i);

input   CSB1_i, CSB2_i;
input   OEB1_i, OEB2_i;
input   CE1_i, CE2_i;
input   WEB1_i, WEB2_i;

input   [`numAddr-1:0]  A1_i, A2_i;
input   [0:0] I1_i, I2_i;

output  [0:0] O1_i, O2_i;

reg     [0:0] O1_i, O2_i;
reg     [0:0]   memory[`numWords-1:0];
reg     [0:0]   data_out1, data_out2;


and u1 (RE1, ~CSB1_i,  WEB1_i);
and u2 (WE1, ~CSB1_i, ~WEB1_i);
and u3 (RE2, ~CSB2_i,  WEB2_i);
and u4 (WE2, ~CSB2_i, ~WEB2_i);

//Primary ports

always @ (posedge CE1_i)
        if (RE1)
                data_out1 = memory[A1_i];
always @ (posedge CE1_i)
        if (WE1)
                memory[A1_i] = I1_i;


always @ (data_out1 or OEB1_i)
        if (!OEB1_i)
                O1_i = data_out1;
        else
                O1_i =  1'bz;

//Dual ports
always @ (posedge CE2_i)
        if (RE2)
                data_out2 = memory[A2_i];
always @ (posedge CE2_i)
        if (WE2)
                memory[A2_i] = I2_i;

always @ (data_out2 or OEB2_i)
        if (!OEB2_i)
                O2_i = data_out2;
        else
                O2_i = 1'bz;

endmodule

