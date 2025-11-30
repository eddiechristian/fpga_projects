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

set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[2] }]; #IO_L16N_T2_A27_15 Sch=fmc_la_n[02]
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[2] }]; #IO_L16P_T2_A28_15 Sch=fmc_la_p[02]
set_property -dict { PACKAGE_PIN N19   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[3] }]; #IO_L17N_T2_A25_15 Sch=fmc_la_n[03]
set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[3] }]; #IO_L17P_T2_A26_15 Sch=fmc_la_p[03]
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[4] }]; #IO_L18N_T2_A23_15 Sch=fmc_la_n[04]
set_property -dict { PACKAGE_PIN N20   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[4] }]; #IO_L18P_T2_A24_15 Sch=fmc_la_p[04]
set_property -dict { PACKAGE_PIN L21   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[5] }]; #IO_L10N_T1_AD11N_15 Sch=fmc_la_n[05]
set_property -dict { PACKAGE_PIN M21   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[5] }]; #IO_L10P_T1_AD11P_15 Sch=fmc_la_p[05]
set_property -dict { PACKAGE_PIN M22   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[6] }]; #IO_L15N_T2_DQS_ADV_B_15 Sch=fmc_la_n[06]
set_property -dict { PACKAGE_PIN N22   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[6] }]; #IO_L15P_T2_DQS_15 Sch=fmc_la_p[06]
set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[7] }]; #IO_L20N_T3_A19_15 Sch=fmc_la_n[07]
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[7] }]; #IO_L20P_T3_A20_15 Sch=fmc_la_p[07]
set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[8] }]; #IO_L24N_T3_RS0_15 Sch=fmc_la_n[08]
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[8] }]; #IO_L24P_T3_RS1_15 Sch=fmc_la_p[08]
set_property -dict { PACKAGE_PIN G20   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_n[9] }]; #IO_L8N_T1_AD10N_15 Sch=fmc_la_n[09]
set_property -dict { PACKAGE_PIN H20   IOSTANDARD LVCMOS12 } [get_ports { fmc_la_p[9] }]; #IO_L8P_T1_AD10P_15 Sch=fmc_la_p[09]


## Configuration options
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
