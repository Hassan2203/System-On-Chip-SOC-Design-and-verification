module ALU_Control(
    input [6:0] funct7,
    input [2:0] funct3,
    input [1:0] ALUOp,
    output reg [3:0] ALU_Ctrl
);

always @(*) begin

    casez ({ALUOp, funct7, funct3})

        // LOAD / STORE / ADDI
        12'b00_???????_???: ALU_Ctrl = 4'b0000;

        // R-TYPE
      
        12'b10_0000000_000: ALU_Ctrl = 4'b0000; // ADD
        12'b10_0100000_000: ALU_Ctrl = 4'b0001; // SUB
        12'b10_0000000_100: ALU_Ctrl = 4'b0010; // XOR
        12'b10_0000000_110: ALU_Ctrl = 4'b0011; // OR
        12'b10_0000000_111: ALU_Ctrl = 4'b0100; // AND
        12'b10_0000000_001: ALU_Ctrl = 4'b0101; // SLL
        12'b10_0000000_101: ALU_Ctrl = 4'b0110; // SRL
        12'b10_0100000_101: ALU_Ctrl = 4'b0111; // SRA
        12'b10_0000000_010: ALU_Ctrl = 4'b1000; // SLT
        12'b10_0000000_011: ALU_Ctrl = 4'b1001; // SLTU

        // BRANCH
 
        12'b01_???????_000: ALU_Ctrl = 4'b1010; // BEQ
        12'b01_???????_001: ALU_Ctrl = 4'b1011; // BNE
        12'b01_???????_100: ALU_Ctrl = 4'b1100; // BLT
        12'b01_???????_101: ALU_Ctrl = 4'b1101; // BGE
        12'b01_???????_110: ALU_Ctrl = 4'b1110; // BLTU
        12'b01_???????_111: ALU_Ctrl = 4'b1111; // BGEU

	// I-Type Arithmetic

	12'b11_0000000_000: ALU_Ctrl = 4'b0000; // ADDI
	12'b11_0000000_111: ALU_Ctrl = 4'b0100; // ANDI
	12'b11_0000000_110: ALU_Ctrl = 4'b0011; // ORI
	12'b11_0000000_100: ALU_Ctrl = 4'b0010; // XORI
	12'b11_0000000_010: ALU_Ctrl = 4'b1000; // SLTI
	12'b11_0000000_011: ALU_Ctrl = 4'b1001; // SLTIU
	12'b11_0000000_001: ALU_Ctrl = 4'b0101; // SLLI
	12'b11_0000000_101: ALU_Ctrl = 4'b0110; // SRLI
	12'b11_0100000_101: ALU_Ctrl = 4'b0111; // SRAI
        default: ALU_Ctrl = 4'b0000;
    endcase
end
endmodule
