module Reg_File(
    input clk,
    input reset,
    input Regwrite,
    input [4:0] Rs1,
    input [4:0] Rs2,
    input [4:0] Rd,
    input [31:0] Write_data,
    output [31:0] read_data1,
    output [31:0] read_data2
);

    reg [31:0] Registers [0:31];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                Registers[i] <= 32'b0;
        end
        else if (Regwrite && (Rd != 5'b00000)) begin
            Registers[Rd] <= Write_data;
        end
    end

    assign read_data1 = (Rs1 == 5'b00000) ? 32'b0 : Registers[Rs1];
    assign read_data2 = (Rs2 == 5'b00000) ? 32'b0 : Registers[Rs2];

endmodule
