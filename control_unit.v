module control_unit(instruction,Branch,MemRead,MemtoReg,AluOp,MemWrite,ALUSrc,RegWrite,Jump);
        input [6:0] instruction;
        output reg Jump,Branch,MemRead,MemtoReg,MemWrite,ALUSrc,RegWrite;
        output reg [1:0] AluOp;

always@(*)
begin
        case(instruction)
                7'b0110011 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b0010000_10;    // R-type
                7'b0010011 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b1010000_11;     // I-ALU
                7'b0000011 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b1111000_00;     // I-Load
                7'b0100011 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b1000100_00;     // S-type
                7'b1100011 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b0000010_01;     // B-type
                7'b1101111 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b0010001_00;     // JAL
                7'b1100111 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b1010001_00;     // JALR
                7'b0110111 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b1010000_00;     // LUI
                7'b0010111 : {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b1010000_00;     // AUIPC
		default	:    {ALUSrc,MemtoReg,RegWrite,MemRead,MemWrite,Branch,Jump,AluOp} = 9'b0000000_00;
        endcase
end
endmodule

