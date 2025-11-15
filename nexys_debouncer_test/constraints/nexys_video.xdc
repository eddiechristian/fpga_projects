####################################################################################
## Nexys Video Constraints for Debouncer Test
## 
## This design is SAFE for use with Analog Discovery 2:
## - All Pmod pins use LVCMOS33 (3.3V) standard
## - Analog Discovery 2 supports 3.3V logic levels
## - Current limiting is built into FPGA outputs
####################################################################################

## Clock Signal - 100MHz
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}];

## Center Button (BTNC)
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS15 } [get_ports { btnc }];

####################################################################################
## Pmod Header JA
## SAFE: LVCMOS33 = 3.3V compatible with Analog Discovery 2
####################################################################################
set_property -dict { PACKAGE_PIN AB22  IOSTANDARD LVCMOS33 } [get_ports { ja[0] }];  # JA1 - Raw button
set_property -dict { PACKAGE_PIN AB21  IOSTANDARD LVCMOS33 } [get_ports { ja[1] }];  # JA2 - Debounced output
set_property -dict { PACKAGE_PIN AB20  IOSTANDARD LVCMOS33 } [get_ports { ja[2] }];  # JA3 - sig_out_reg
set_property -dict { PACKAGE_PIN AB18  IOSTANDARD LVCMOS33 } [get_ports { ja[3] }];  # JA4 - Counter active
set_property -dict { PACKAGE_PIN Y21   IOSTANDARD LVCMOS33 } [get_ports { ja[4] }];  # JA7 - Counter[23]
set_property -dict { PACKAGE_PIN AA21  IOSTANDARD LVCMOS33 } [get_ports { ja[5] }];  # JA8 - Counter[22]
set_property -dict { PACKAGE_PIN AA20  IOSTANDARD LVCMOS33 } [get_ports { ja[6] }];  # JA9 - Counter[21]
set_property -dict { PACKAGE_PIN AA18  IOSTANDARD LVCMOS33 } [get_ports { ja[7] }];  # JA10 - Counter[20]

####################################################################################
## Pmod Header JB
## SAFE: LVCMOS33 = 3.3V compatible with Analog Discovery 2
####################################################################################
set_property -dict { PACKAGE_PIN V9    IOSTANDARD LVCMOS33 } [get_ports { jb[0] }];  # JB1 - Counter[19]
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { jb[1] }];  # JB2 - Counter[18]
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { jb[2] }];  # JB3 - Counter[17]
set_property -dict { PACKAGE_PIN W7    IOSTANDARD LVCMOS33 } [get_ports { jb[3] }];  # JB4 - Counter[16]
set_property -dict { PACKAGE_PIN W9    IOSTANDARD LVCMOS33 } [get_ports { jb[4] }];  # JB7 - Counter[15]
set_property -dict { PACKAGE_PIN Y9    IOSTANDARD LVCMOS33 } [get_ports { jb[5] }];  # JB8 - Counter[14]
set_property -dict { PACKAGE_PIN Y8    IOSTANDARD LVCMOS33 } [get_ports { jb[6] }];  # JB9 - Counter[13]
set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { jb[7] }];  # JB10 - Counter[12]

####################################################################################
## Pmod Header JC
## SAFE: LVCMOS33 = 3.3V compatible with Analog Discovery 2
####################################################################################
set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { jc[0] }];  # JC1 - Counter[11]
set_property -dict { PACKAGE_PIN AA6   IOSTANDARD LVCMOS33 } [get_ports { jc[1] }];  # JC2 - Counter[10]
set_property -dict { PACKAGE_PIN AA8   IOSTANDARD LVCMOS33 } [get_ports { jc[2] }];  # JC3 - Counter[9]
set_property -dict { PACKAGE_PIN AB8   IOSTANDARD LVCMOS33 } [get_ports { jc[3] }];  # JC4 - Counter[8]
set_property -dict { PACKAGE_PIN R6    IOSTANDARD LVCMOS33 } [get_ports { jc[4] }];  # JC7 - Counter[7]
set_property -dict { PACKAGE_PIN T6    IOSTANDARD LVCMOS33 } [get_ports { jc[5] }];  # JC8 - Counter[6]
set_property -dict { PACKAGE_PIN AB7   IOSTANDARD LVCMOS33 } [get_ports { jc[6] }];  # JC9 - Counter[5]
set_property -dict { PACKAGE_PIN AB6   IOSTANDARD LVCMOS33 } [get_ports { jc[7] }];  # JC10 - Counter[4]

####################################################################################
## Pmod Header JD
## SAFE: LVCMOS33 = 3.3V compatible with Analog Discovery 2
####################################################################################
set_property -dict { PACKAGE_PIN W4    IOSTANDARD LVCMOS33 } [get_ports { jd[0] }];  # JD1 - Counter[3]
set_property -dict { PACKAGE_PIN V4    IOSTANDARD LVCMOS33 } [get_ports { jd[1] }];  # JD2 - Counter[2]
set_property -dict { PACKAGE_PIN U4    IOSTANDARD LVCMOS33 } [get_ports { jd[2] }];  # JD3 - Counter[1]
set_property -dict { PACKAGE_PIN U3    IOSTANDARD LVCMOS33 } [get_ports { jd[3] }];  # JD4 - Counter[0]
set_property -dict { PACKAGE_PIN V5    IOSTANDARD LVCMOS33 } [get_ports { jd[4] }];  # JD7 - Clock divided
set_property -dict { PACKAGE_PIN W5    IOSTANDARD LVCMOS33 } [get_ports { jd[5] }];  # JD8 - Unused
set_property -dict { PACKAGE_PIN U5    IOSTANDARD LVCMOS33 } [get_ports { jd[6] }];  # JD9 - Unused
set_property -dict { PACKAGE_PIN U2    IOSTANDARD LVCMOS33 } [get_ports { jd[7] }];  # JD10 - Unused

## Note: Pins 5 and 11 on each Pmod are GND
##       Pins 6 and 12 on each Pmod are VCC (3.3V)
##       Use GND pins as ground reference for Analog Discovery 2

####################################################################################
## Configuration
####################################################################################
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
