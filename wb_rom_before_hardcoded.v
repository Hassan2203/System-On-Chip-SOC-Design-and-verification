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

        $readmemh("program.hex", rom);
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
