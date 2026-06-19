module pin_test(
    input clk,
    output [3:0] led
);

    reg [25:0] counter = 26'd0;

    always @(posedge clk) begin
        counter <= counter + 1'b1;
    end

    assign led[0] = counter[22];
    assign led[1] = counter[23];
    assign led[2] = counter[24];
    assign led[3] = counter[25];

endmodule
