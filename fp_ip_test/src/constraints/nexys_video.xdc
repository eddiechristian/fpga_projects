## Constraints file for Floating Point IP Test
## Nexys Video Board - Artix-7 XC7A200T-1SBG484C
## Simple top module with only clock and reset

## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN R4   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Reset Button (BTNC - CPU_RESET)
set_property -dict { PACKAGE_PIN G4   IOSTANDARD LVCMOS15 } [get_ports { reset }];

## Heartbeat output - LED0
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS25 } [get_ports { heartbeat }];

## Configuration options
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
