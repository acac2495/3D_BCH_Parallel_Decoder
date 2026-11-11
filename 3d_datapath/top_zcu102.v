module top_zcu102(CLK_125_P, CLK_125_N, CPU_RST, GPIO_SW_N, GPIO_LED, done_master);

    input CLK_125_P, CLK_125_N;
    input CPU_RST, GPIO_SW_N;

    output [7:0] GPIO_LED;
    output done_master;

    wire clk_125_ibuf;
    wire clk_fb, clk_80_raw, clk_80;
    wire mmcm_locked;

    IBUFDS IBUFDS_CLK_125 (
        .I(CLK_125_P),
        .IB(CLK_125_N),
        .O(clk_125_ibuf)
    );

    MMCME4_BASE #(
        .CLKIN1_PERIOD    (8.000),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (8.000),
        .CLKOUT0_DIVIDE_F (12.500)
    ) u_mmcm (
        .CLKIN1(clk_125_ibuf), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_80_raw), .LOCKED(mmcm_locked), .PWRDWN(1'b0), .RST(1'b0)
    );

    BUFG u_bufg_clk_80 (
        .I(clk_80_raw), 
        .O(clk_80)
    );

    wire rst_int = CPU_RESET | ~mmcm_locked;

    top_interface u_top (
        .clk(clk_80), .rst(rst_int),
        .start_master(GPIO_SW_N),
        .done_master(done_master),
        .leds(GPIO_LED)
    );
endmodule