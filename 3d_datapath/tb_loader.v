`include "loader.v"   
`timescale 1ns/1ns

module tb_loader;

    localparam N = 15;
    localparam T = 2;
    localparam M = 4;
    localparam MAX_ITER = 100;

    reg clk, rst, start_master;

    wire done_master;
    wire [7:0] leds;

    loader #(.M(M), .T(T), .N(N)) DUT (
        .clk(clk),
        .rst(rst),
        .start_master(start_master),
        .leds(leds),
        .done_master(done_master)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start_master = 0;

        repeat (4) @(posedge clk);
        rst <= 0;
        repeat (2) @(posedge clk);

        start_master <= 1; @(posedge clk); start_master <= 0;

        wait (done_master);
        @(posedge clk);
        $display("done: done_master=%b", done_master);

        $finish;
    end

    initial begin
        #5_000_000;
        $display("TIMEOUT");
        $finish;
    end
endmodule