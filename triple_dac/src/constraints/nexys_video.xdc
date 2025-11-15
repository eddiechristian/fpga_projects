## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Reset button (CPU_RESET - active low)
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS15 } [get_ports { rst_n }];

## DAC value inputs - Using switches SW0-SW11 for DAC1
## Note: Nexys Video has 8 switches, so you'll need to modify this based on your input method
## These are example mappings - adjust according to your design needs
# set_property -dict { PACKAGE_PIN E22   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[0] }];
# set_property -dict { PACKAGE_PIN F21   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[1] }];
# set_property -dict { PACKAGE_PIN G21   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[2] }];
# set_property -dict { PACKAGE_PIN G22   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[3] }];
# set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[4] }];
# set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[5] }];
# set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[6] }];
# set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS12 } [get_ports { dac1_value[7] }];

## Update buttons - Using BTNU, BTND, BTNL (or map to FPGA logic)
# set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS12 } [get_ports { update1 }];
# set_property -dict { PACKAGE_PIN C22   IOSTANDARD LVCMOS12 } [get_ports { update2 }];
# set_property -dict { PACKAGE_PIN D22   IOSTANDARD LVCMOS12 } [get_ports { update3 }];

## Status LEDs - Using LED0, LED1, LED2
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS25 } [get_ports { led_busy1 }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS25 } [get_ports { led_busy2 }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS25 } [get_ports { led_busy3 }];

## I2C Bus 1 - Using Pmod JA pins (top row)
## JA1 = SCL1, JA2 = SDA1
set_property -dict { PACKAGE_PIN AB22  IOSTANDARD LVCMOS33 } [get_ports { scl1 }];
set_property -dict { PACKAGE_PIN AB21  IOSTANDARD LVCMOS33 } [get_ports { sda1 }];

## I2C Bus 2 - Using Pmod JA pins (bottom row)
## JA7 = SCL2, JA8 = SDA2
set_property -dict { PACKAGE_PIN AB20  IOSTANDARD LVCMOS33 } [get_ports { scl2 }];
set_property -dict { PACKAGE_PIN AB18  IOSTANDARD LVCMOS33 } [get_ports { sda2 }];

## I2C Bus 3 - Using Pmod JB pins (top row)
## JB1 = SCL3, JB2 = SDA3
set_property -dict { PACKAGE_PIN V9    IOSTANDARD LVCMOS33 } [get_ports { scl3 }];
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { sda3 }];

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
