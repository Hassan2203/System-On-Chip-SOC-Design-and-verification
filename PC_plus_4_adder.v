module pc_adder(adder_in, adder_out);
        input [31:0] adder_in;
        output [31:0] adder_out;
        assign adder_out = adder_in + 4 ;
endmodule

