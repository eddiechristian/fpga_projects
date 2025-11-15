## This file is a constraints file for the Nexys Video board
## targeting the Artix-7 FPGA (XC7A200T-1SBG484C)
## Driving 2x LTP-3786E 14-segment displays (2 digits each = 4 digits total)

## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN R4   IOSTANDARD LVCMOS33 } [get_ports { CLK }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK }];

## Reset Button (BTNC - CPU_RESET)
set_property -dict { PACKAGE_PIN G4   IOSTANDARD LVCMOS15 } [get_ports { RST }];

## Switches
set_property -dict { PACKAGE_PIN E22  IOSTANDARD LVCMOS12 } [get_ports { SW[0] }];
set_property -dict { PACKAGE_PIN F21  IOSTANDARD LVCMOS12 } [get_ports { SW[1] }];
set_property -dict { PACKAGE_PIN G21  IOSTANDARD LVCMOS12 } [get_ports { SW[2] }];
set_property -dict { PACKAGE_PIN G22  IOSTANDARD LVCMOS12 } [get_ports { SW[3] }];
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS12 } [get_ports { SW[4] }];
set_property -dict { PACKAGE_PIN J16  IOSTANDARD LVCMOS12 } [get_ports { SW[5] }];
set_property -dict { PACKAGE_PIN K13  IOSTANDARD LVCMOS12 } [get_ports { SW[6] }];
set_property -dict { PACKAGE_PIN M17  IOSTANDARD LVCMOS12 } [get_ports { SW[7] }];

## Buttons
set_property -dict { PACKAGE_PIN B22  IOSTANDARD LVCMOS12 } [get_ports { BTN[0] }]; # BTNU
set_property -dict { PACKAGE_PIN D22  IOSTANDARD LVCMOS12 } [get_ports { BTN[1] }]; # BTNL
set_property -dict { PACKAGE_PIN C22  IOSTANDARD LVCMOS12 } [get_ports { BTN[2] }]; # BTND
set_property -dict { PACKAGE_PIN D14  IOSTANDARD LVCMOS12 } [get_ports { BTN[3] }]; # BTNR
set_property -dict { PACKAGE_PIN F15  IOSTANDARD LVCMOS12 } [get_ports { BTN[4] }]; # BTNC (not reset)

## LEDs
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS25 } [get_ports { LED[0] }];
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS25 } [get_ports { LED[1] }];
set_property -dict { PACKAGE_PIN T16  IOSTANDARD LVCMOS25 } [get_ports { LED[2] }];
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS25 } [get_ports { LED[3] }];
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS25 } [get_ports { LED[4] }];
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS25 } [get_ports { LED[5] }];
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS25 } [get_ports { LED[6] }];
set_property -dict { PACKAGE_PIN Y13  IOSTANDARD LVCMOS25 } [get_ports { LED[7] }];

##############################################################################
## PMOD JA - 14-segment signals (shared by both displays)
## Segments: a1, a2, b, c, d1, d2, e, f, g1, g2, h, i, j, k
## These 14 signals drive the segment patterns on both LTP-3786E displays
##############################################################################
set_property -dict { PACKAGE_PIN AB22 IOSTANDARD LVCMOS33 } [get_ports { SEG[0] }];  # JA1 - segment a1
set_property -dict { PACKAGE_PIN AB21 IOSTANDARD LVCMOS33 } [get_ports { SEG[1] }];  # JA2 - segment a2
set_property -dict { PACKAGE_PIN AB20 IOSTANDARD LVCMOS33 } [get_ports { SEG[2] }];  # JA3 - segment b
set_property -dict { PACKAGE_PIN AB18 IOSTANDARD LVCMOS33 } [get_ports { SEG[3] }];  # JA4 - segment c
set_property -dict { PACKAGE_PIN Y21  IOSTANDARD LVCMOS33 } [get_ports { SEG[4] }];  # JA7 - segment d1
set_property -dict { PACKAGE_PIN AA21 IOSTANDARD LVCMOS33 } [get_ports { SEG[5] }];  # JA8 - segment d2
set_property -dict { PACKAGE_PIN AA20 IOSTANDARD LVCMOS33 } [get_ports { SEG[6] }];  # JA9 - segment e
set_property -dict { PACKAGE_PIN AA18 IOSTANDARD LVCMOS33 } [get_ports { SEG[7] }];  # JA10 - segment f

##############################################################################
## PMOD JB - More 14-segment signals (shared by both displays)
##############################################################################
set_property -dict { PACKAGE_PIN V9   IOSTANDARD LVCMOS33 } [get_ports { SEG[8] }];  # JB1 - segment g1
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports { SEG[9] }];  # JB2 - segment g2
set_property -dict { PACKAGE_PIN V7   IOSTANDARD LVCMOS33 } [get_ports { SEG[10] }]; # JB3 - segment h
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports { SEG[11] }]; # JB4 - segment i
set_property -dict { PACKAGE_PIN W9   IOSTANDARD LVCMOS33 } [get_ports { SEG[12] }]; # JB7 - segment j
set_property -dict { PACKAGE_PIN Y9   IOSTANDARD LVCMOS33 } [get_ports { SEG[13] }]; # JB8 - segment k

##############################################################################
## PMOD JC - Digit select signals (OFFICIAL DIGILENT PINS)
##############################################################################
set_property -dict { PACKAGE_PIN Y6   IOSTANDARD LVCMOS33 } [get_ports { DIG[0] }]; # JC1 - Digit 0
set_property -dict { PACKAGE_PIN AA6  IOSTANDARD LVCMOS33 } [get_ports { DIG[1] }]; # JC2 - Digit 1
set_property -dict { PACKAGE_PIN AA8  IOSTANDARD LVCMOS33 } [get_ports { DIG[2] }]; # JC3 - Digit 2
set_property -dict { PACKAGE_PIN AB8  IOSTANDARD LVCMOS33 } [get_ports { DIG[3] }]; # JC4 - Digit 3

## Configuration options
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
