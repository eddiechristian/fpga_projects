## Nexys Video Constraints File for LED Test

## System Clock (100 MHz)
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];


## Reset Button (BTNC - CPU_RESET)
set_property -dict { PACKAGE_PIN G4   IOSTANDARD LVCMOS15 } [get_ports { RST }];

## Buttons
set_property -dict { PACKAGE_PIN B22  IOSTANDARD LVCMOS12 } [get_ports { BTNC }]; # BTNU
set_property -dict { PACKAGE_PIN D22  IOSTANDARD LVCMOS12 } [get_ports { BTND }]; # BTNL
set_property -dict { PACKAGE_PIN C22  IOSTANDARD LVCMOS12 } [get_ports { BTNL }]; # BTND
set_property -dict { PACKAGE_PIN D14  IOSTANDARD LVCMOS12 } [get_ports { BTNR }]; # BTNR
set_property -dict { PACKAGE_PIN F15  IOSTANDARD LVCMOS12 } [get_ports { BTNU }]; # BTNC (not reset)

## LEDs
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS25 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS25 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS25 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS25 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS25 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS25 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS25 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN Y13   IOSTANDARD LVCMOS25 } [get_ports { led[7] }];

## Configuration options
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
