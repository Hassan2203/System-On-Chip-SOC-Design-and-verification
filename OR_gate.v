module OR_gate(jump,AND_gate_output,OR_gate_result);
	input jump, AND_gate_output;
	output OR_gate_result;
	assign OR_gate_result = jump | AND_gate_output;
endmodule

