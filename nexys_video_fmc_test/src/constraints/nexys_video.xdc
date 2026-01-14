## Nexys Video FMC Loopback Test Constraints
## Digilent Nexys Video Board

## Switches
set_property -dict { PACKAGE_PIN E22  IOSTANDARD LVCMOS12 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN F21  IOSTANDARD LVCMOS12 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN G21  IOSTANDARD LVCMOS12 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN G22  IOSTANDARD LVCMOS12 } [get_ports { sw[3] }]
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS12 } [get_ports { sw[4] }]
set_property -dict { PACKAGE_PIN J16  IOSTANDARD LVCMOS12 } [get_ports { sw[5] }]
set_property -dict { PACKAGE_PIN K13  IOSTANDARD LVCMOS12 } [get_ports { sw[6] }]
set_property -dict { PACKAGE_PIN M17  IOSTANDARD LVCMOS12 } [get_ports { sw[7] }]

## LEDs
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS25 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS25 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T16  IOSTANDARD LVCMOS25 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS25 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS25 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS25 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS25 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN Y13  IOSTANDARD LVCMOS25 } [get_ports { led[7] }]

## FMC HPC Connector - LA Pins (Bidirectional)
## Using LA02-LA09 as inout ports (Bank 15, LVCMOS12)
## Switch drives pin when high, LED reads pin state

set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS12 } [get_ports { red_in[0] }]; # 11_p
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS12 } [get_ports { red_in[1] }]; # 15_p
set_property -dict { PACKAGE_PIN H20   IOSTANDARD LVCMOS12 } [get_ports { red_in[2] }]; # 09_p
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS12 } [get_ports { red_in[3] }]; # 13_p
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS12 } [get_ports { red_in[4] }]; # 19_p
set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS12 } [get_ports { red_in[5] }]; # 21_p
set_property -dict { PACKAGE_PIN B21   IOSTANDARD LVCMOS12 } [get_ports { red_in[6] }]; # 23_p
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS12 } [get_ports { red_in[7] }]; # 07_p



set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS12 } [get_ports { green_in[0] }]; # 11_n
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS12 } [get_ports { green_in[1] }]; # 15_n
set_property -dict { PACKAGE_PIN G20   IOSTANDARD LVCMOS12 } [get_ports { green_in[2] }]; # 09_n
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS12 } [get_ports { green_in[3] }]; # 13_n
set_property -dict { PACKAGE_PIN A19   IOSTANDARD LVCMOS12 } [get_ports { green_in[4] }]; # 19_n
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS12 } [get_ports { green_in[5] }]; # 21_n
set_property -dict { PACKAGE_PIN A21   IOSTANDARD LVCMOS12 } [get_ports { green_in[6] }]; # 23_n
set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS12 } [get_ports { green_in[7] }]; # 07_n


set_property -dict { PACKAGE_PIN M21   IOSTANDARD LVCMOS12 } [get_ports { blue_in[0] }]; # 05_p
set_property -dict { PACKAGE_PIN L21   IOSTANDARD LVCMOS12 } [get_ports { blue_in[1] }]; # 05_n
set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS12 } [get_ports { blue_in[2] }]; # 24_p
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS12 } [get_ports { blue_in[3] }]; # 24_n
set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS12 } [get_ports { blue_in[4] }]; # 26_p
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS12 } [get_ports { blue_in[5] }]; # 26_n
set_property -dict { PACKAGE_PIN C13   IOSTANDARD LVCMOS12 } [get_ports { blue_in[6] }]; # 28_p
set_property -dict { PACKAGE_PIN B13   IOSTANDARD LVCMOS12 } [get_ports { blue_in[7] }]; # 28_n


set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS12 } [get_ports { hsync }]; # 30_p
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS12 } [get_ports { vsync }]; # 30_n

## Configuration options
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
