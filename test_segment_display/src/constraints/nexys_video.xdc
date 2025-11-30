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


## Configuration options
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]





set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS12 } [get_ports { SEG[0] }]; #IO_L16P_T2_A28_15 Sch=fmc_la_p[02]          
set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS12 } [get_ports { SEG[1] }]; #IO_L17P_T2_A26_15 Sch=fmc_la_p[03]         
set_property -dict { PACKAGE_PIN N20   IOSTANDARD LVCMOS12 } [get_ports { SEG[2] }]; #IO_L18P_T2_A24_15 Sch=fmc_la_p[04]        
set_property -dict { PACKAGE_PIN M21   IOSTANDARD LVCMOS12 } [get_ports { SEG[3] }]; #IO_L10P_T1_AD11P_15 Sch=fmc_la_p[05]
set_property -dict { PACKAGE_PIN N22   IOSTANDARD LVCMOS12 } [get_ports { SEG[4] }]; #IO_L15P_T2_DQS_15 Sch=fmc_la_p[06]
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS12 } [get_ports { SEG[5] }]; #IO_L20P_T3_A20_15 Sch=fmc_la_p[07]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS12 } [get_ports { SEG[6] }]; #IO_L24P_T3_RS1_15 Sch=fmc_la_p[08]
set_property -dict { PACKAGE_PIN H20   IOSTANDARD LVCMOS12 } [get_ports { SEG[7] }]; #IO_L8P_T1_AD10P_15 Sch=fmc_la_p[09]
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS12 } [get_ports { SEG[8] }]; #IO_L22P_T3_A17_15 Sch=fmc_la_p[11]
set_property -dict { PACKAGE_PIN L19   IOSTANDARD LVCMOS12 } [get_ports { SEG[9] }]; #IO_L14P_T2_SRCC_15 Sch=fmc_la_p[12]
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS12 } [get_ports {  SEG[10] }]; #IO_L21P_T3_DQS_15 Sch=fmc_la_p[13]
set_property -dict { PACKAGE_PIN J22   IOSTANDARD LVCMOS12 } [get_ports {  SEG[11] }]; #IO_L7P_T1_AD2P_15 Sch=fmc_la_p[14]
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS12 } [get_ports {  SEG[12] }]; #IO_L23P_T3_FOE_B_15 Sch=fmc_la_p[15]
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS12 } [get_ports {  SEG[13] }]; #IO_L4P_T0_15 Sch=fmc_la_p[16]
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS12 } [get_ports { DIG[0] }]; #IO_L17P_T2_16 Sch=fmc_la_p[19]
set_property -dict { PACKAGE_PIN F19   IOSTANDARD LVCMOS12 } [get_ports { DIG[1] }]; #IO_L18P_T2_16 Sch=fmc_la_p[20]
set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS12 } [get_ports { DIG[2] }]; #IO_L14P_T2_SRCC_16 Sch=fmc_la_p[21]
set_property -dict { PACKAGE_PIN E21   IOSTANDARD LVCMOS12 } [get_ports { DIG[3] }]; #IO_L23P_T3_16 Sch=fmc_la_p[22]
set_property -dict { PACKAGE_PIN B21   IOSTANDARD LVCMOS12 } [get_ports { DIG[4] }]; #IO_L21P_T3_DQS_16 Sch=fmc_la_p[23]
set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS12 } [get_ports { DIG[5] }]; #IO_L7P_T1_16 Sch=fmc_la_p[24]
