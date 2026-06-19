module wb_rom(
    input         clk,
    input         reset,

    input  [31:0] adr_i,
    input  [31:0] dat_i,
    output [31:0] dat_o,
    input         we_i,
    input  [3:0]  sel_i,
    input         cyc_i,
    input         stb_i,
    output        ack_o
);

    reg [31:0] rom [0:255];
    reg [31:0] dat_o_reg;
    reg ack_reg;

    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 32'h00000013;   // NOP

        // Hardcoded FPGA test program:
        // CPU + Wishbone LED sequence test without branch/jump
        // x5 = 0x00002000
        // write 1, 2, 4, 8 to LED peripheral
        rom[0]  = 32'h000022b7;   // lui  x5, 0x2
        rom[1]  = 32'h00100313;   // addi x6, x0, 1
        rom[2]  = 32'h0062a023;   // sw   x6, 0(x5)
        rom[3]  = 32'h00200313;   // addi x6, x0, 2
        rom[4]  = 32'h0062a023;   // sw   x6, 0(x5)
        rom[5]  = 32'h00400313;   // addi x6, x0, 4
        rom[6]  = 32'h0062a023;   // sw   x6, 0(x5)
        rom[7]  = 32'h00800313;   // addi x6, x0, 8
        rom[8]  = 32'h0062a023;   // sw   x6, 0(x5)
        rom[9]  = 32'h00000013;   // nop
        rom[10] = 32'h00000013;   // nop
    end

    always @(posedge clk) begin
        if (reset) begin
            ack_reg   <= 1'b0;
            dat_o_reg <= 32'b0;
        end
        else begin
            ack_reg <= cyc_i & stb_i;

            if (cyc_i && stb_i) begin
                dat_o_reg <= rom[adr_i[9:2]];
            end
        end
    end

    assign dat_o = dat_o_reg;
    assign ack_o = ack_reg;

endmodule
