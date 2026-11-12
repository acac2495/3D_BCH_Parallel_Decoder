// Board wrapper for ZCU102: differential 300 MHz USER_SI570 clock (HP bank 64) -> MMCM -> 80 MHz -> top_interface
`timescale 1ns/1ps
module top_zcu102 (
    input        USER_SI570_P,
    input        USER_SI570_N,
    input        CPU_RESET,      // active-high pushbutton
    input        GPIO_SW_N,      // start_master
    output       done_master,
    output [7:0] GPIO_LED
);
    wire clk_300_ibuf, clk_fb, clk_80_raw, clk_80, mmcm_locked;

    // 1) differential -> single-ended clock
    IBUFDS u_ibufds (.I(USER_SI570_P), .IB(USER_SI570_N), .O(clk_300_ibuf));

    // 2) 300 MHz -> 80 MHz  (VCO = 300 x 4 / 1 = 1200 MHz; 1200 / 15 = 80 MHz)
    MMCME4_BASE #(
        .CLKIN1_PERIOD    (3.333),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (4.000),
        .CLKOUT0_DIVIDE_F (15.000)
    ) u_mmcm (
        .CLKIN1(clk_300_ibuf), .CLKFBIN(clk_fb), .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_80_raw), .LOCKED(mmcm_locked), .PWRDWN(1'b0), .RST(1'b0)
    );

    // 3) put the MMCM output on a global clock buffer
    BUFG u_bufg (.I(clk_80_raw), .O(clk_80));

    // 4) hold design in reset until the MMCM is locked
    wire rst_int = CPU_RESET | ~mmcm_locked;

    top_interface u_top (
        .clk(clk_80), .rst(rst_int),
        .start_master(GPIO_SW_N),
        .done_master(done_master),
        .leds(GPIO_LED)
    );
endmodule