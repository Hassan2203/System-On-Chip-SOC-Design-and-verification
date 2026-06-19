module wb_ram(
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

    reg [31:0] ram [0:255];
    reg [31:0] dat_o_reg;
    reg ack_reg;

    wire [7:0] word_addr;
    assign word_addr = adr_i[9:2];

    always @(posedge clk) begin
        if (reset) begin
            ack_reg   <= 1'b0;
            dat_o_reg <= 32'b0;
        end
        else begin
            ack_reg <= cyc_i & stb_i;

            if (cyc_i && stb_i) begin
                dat_o_reg <= ram[word_addr];

                if (we_i) begin
                    if (sel_i[0])
                        ram[word_addr][7:0] <= dat_i[7:0];

                    if (sel_i[1])
                        ram[word_addr][15:8] <= dat_i[15:8];

                    if (sel_i[2])
                        ram[word_addr][23:16] <= dat_i[23:16];

                    if (sel_i[3])
                        ram[word_addr][31:24] <= dat_i[31:24];
                end
            end
        end
    end

    assign dat_o = dat_o_reg;
    assign ack_o = ack_reg;

endmodule
