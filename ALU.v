module ALU(in1,in2,alu_result,alu_op,zero);

input [31:0] in1, in2;
input [3:0] alu_op;

output reg [31:0] alu_result;
output reg zero;

always @(*) begin

    case(alu_op)

        // ADD
        4'b0000 : begin
            alu_result = in1 + in2;
            zero = (alu_result == 32'd0);
        end

	// SUB
        
        4'b0001 : begin
            alu_result = in1 - in2;
            zero = (alu_result == 32'd0);
        end

        
        // XOR
        4'b0010 : begin
            alu_result = in1 ^ in2;
            zero = (alu_result == 32'd0);
        end

        
        // OR
        
        4'b0011 : begin
            alu_result = in1 | in2;
            zero = (alu_result == 32'd0);
        end

        
        // AND
        
        4'b0100 : begin
            alu_result = in1 & in2;
            zero = (alu_result == 32'd0);
        end

        
        // SLL
        
        4'b0101 : begin
            alu_result = in1 << in2[4:0];
            zero = (alu_result == 32'd0);
        end

        // SRL
        
        4'b0110 : begin
            alu_result = in1 >> in2[4:0];
            zero = (alu_result == 32'd0);
        end

        
        // SRA
        
        4'b0111 : begin
            alu_result = $signed(in1) >>> in2[4:0];
            zero = (alu_result == 32'd0);
        end

        // SLT
        
        4'b1000 : begin
            alu_result =
            ($signed(in1) < $signed(in2)) ? 32'd1 : 32'd0;

            zero = (alu_result == 32'd0);
        end

        
        // SLTU
            4'b1001 : begin
            alu_result =(in1 < in2) ? 32'd1 : 32'd0;

            zero = (alu_result == 32'd0);
        end

        
        // BEQ
        
        4'b1010 : begin
            alu_result = (in1==in2);

            if(in1 == in2)
                zero = 1'b1;
            else
                zero = 1'b0;
        end

        
        // BNE
        
        4'b1011 : begin
            alu_result = (in1 != in2);

            if(in1 != in2)
                zero = 1'b1;
            else
                zero = 1'b0;
        end

        // BLT
        
        4'b1100 : begin
            alu_result =
            ($signed(in1) < $signed(in2)) ? 32'd1 : 32'd0;

            zero = (alu_result == 32'd1);
        end

        // BGE
        4'b1101 : begin
            alu_result =
            ($signed(in1) >= $signed(in2)) ? 32'd1 : 32'd0;

            zero = (alu_result == 32'd1);
        end

        // BLTU
        4'b1110 : begin
            alu_result =
            (in1 < in2) ? 32'd1 : 32'd0;

            zero = (alu_result == 32'd1);
        end

        
        // BGEU
        
        4'b1111 : begin
            alu_result =
            (in1 >= in2) ? 32'd1 : 32'd0;

            zero = (alu_result == 32'd1);
        end

        
        // DEFAULT
        
        default : begin
            alu_result = 32'd0;
            zero = 1'b0;
        end

    endcase

end

endmodule
