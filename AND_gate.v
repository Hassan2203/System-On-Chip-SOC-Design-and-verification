module AND_gate(zero,branch,out);
	input zero,branch;
	output out;
	assign out = zero & branch;
endmodule
