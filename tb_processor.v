`timescale 1ns/1ps

module testbench;

    reg clk;
    reg reset;
    wire [3:0] led;

    integer seen_1;
    integer seen_2;
    integer seen_4;
    integer seen_8;

    tope uut(
        .clk(clk),
        .reset(reset),
        .led(led)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    initial begin
        $dumpfile("wishbone_soc.vcd");
        $dumpvars(0, testbench);
    end

    always @(led) begin
        $display("TIME=%0t LED=%b HEX=0x%h", $time, led, led);

        if (led == 4'b0001)
            seen_1 = 1;

        if (led == 4'b0010)
            seen_2 = 1;

        if (led == 4'b0100)
            seen_4 = 1;

        if (led == 4'b1000)
            seen_8 = 1;
    end

    initial begin
        seen_1 = 0;
        seen_2 = 0;
        seen_4 = 0;
        seen_8 = 0;

        $display("=======================================");
        $display(" RISC-V Wishbone 4-LED Simulation Start");
        $display("=======================================");

        #2000000;

        $display("=======================================");
        $display(" Final LED = %b", led);
        $display(" Seen LED0 = %0d", seen_1);
        $display(" Seen LED1 = %0d", seen_2);
        $display(" Seen LED2 = %0d", seen_4);
        $display(" Seen LED3 = %0d", seen_8);
        $display("=======================================");

        if (seen_1 && seen_2 && seen_4 && seen_8)
            $display("[PASS] 4 LED running pattern detected through Wishbone");
        else
            $display("[FAIL] Complete 4 LED pattern not detected");

        $finish;
    end

endmodule
