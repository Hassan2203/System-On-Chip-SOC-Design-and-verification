module mux(
    input  [31:0] pc_out,
    input  [31:0] adder_output,
    input         sel,
    output [31:0] mux_output
);

assign mux_output = sel ? adder_output : pc_out;

endmodule
