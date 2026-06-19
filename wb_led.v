module wb_led(
    input         clk,
    input         reset,

    input  [31:0] adr_i,
    input  [31:0] dat_i,
    output [31:0] dat_o,
    input         we_i,
    input  [3:0]  sel_i,
    input         cyc_i,
    input         stb_i,
    output        ack_o,

    output [3:0]  led
);

    reg [3:0] led_reg;

    assign led = led_reg;

    assign dat_o = {28'b0, led_reg};

    assign ack_o = cyc_i & stb_i;

    always @(posedge clk) begin
        if (reset) begin
            led_reg <= 4'b0000;
        end
        else begin
            if (cyc_i && stb_i && we_i) begin
                led_reg <= dat_i[3:0];
            end
        end
    end

endmodule
