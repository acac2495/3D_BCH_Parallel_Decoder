## ZCU102 constraints for top_zcu102 -> top_interface
## LED / button / reset pins from UG1182 Table 3-33.

## ---------------- Clock: CLK_125 (UG1182 Table 3-13) ----------------
set_property PACKAGE_PIN G21  [get_ports CLK_125_P]
set_property PACKAGE_PIN F21  [get_ports CLK_125_N]
set_property IOSTANDARD LVDS_25 [get_ports {CLK_125_P CLK_125_N}]
create_clock -name sys_clk_125 -period 8.000 [get_ports CLK_125_P]
## The 80 MHz MMCM output is derived automatically.

## ---------------- Reset ----------------
set_property PACKAGE_PIN AM13    [get_ports CPU_RESET]
set_property IOSTANDARD LVCMOS33 [get_ports CPU_RESET]

## ---------------- Start button (north) ----------------
set_property PACKAGE_PIN AG15    [get_ports GPIO_SW_N]
set_property IOSTANDARD LVCMOS33 [get_ports GPIO_SW_N]

## ---------------- LEDs ----------------
set_property PACKAGE_PIN AG14 [get_ports {GPIO_LED[0]}]
set_property PACKAGE_PIN AF13 [get_ports {GPIO_LED[1]}]
set_property PACKAGE_PIN AE13 [get_ports {GPIO_LED[2]}]
set_property PACKAGE_PIN AJ14 [get_ports {GPIO_LED[3]}]
set_property PACKAGE_PIN AJ15 [get_ports {GPIO_LED[4]}]
set_property PACKAGE_PIN AH13 [get_ports {GPIO_LED[5]}]
set_property PACKAGE_PIN AH14 [get_ports {GPIO_LED[6]}]
set_property PACKAGE_PIN AL12 [get_ports {GPIO_LED[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {GPIO_LED[*]}]

## ---------------- done_master -> PMOD0 pin 0 ----------------
## A20 = PMOD0_0 / J55.1 (UG1182 Table 3-31)
set_property PACKAGE_PIN A20     [get_ports done_master]
set_property IOSTANDARD LVCMOS33 [get_ports done_master]

## ---------------- Timing exceptions (async board I/O) ----------------
set_false_path -from [get_ports {CPU_RESET GPIO_SW_N}]
set_false_path -to   [get_ports {GPIO_LED[*] done_master}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
