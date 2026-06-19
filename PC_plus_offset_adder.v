module branch_adder(
    input  [31:0] pc_out,
    input  [31:0] immediate_for_branch,
    output [31:0] adder_output
);

assign adder_output = pc_out + immediate_for_branch;

endmodule
