## Nexys Video Ray Tracer Constraints

## Clock Signal (100 MHz)
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset Button (active low, CPU reset)
set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS15 } [get_ports { reset_n }];

## LEDs for debug
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS25 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS25 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS25 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS25 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS25 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS25 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS25 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN Y13   IOSTANDARD LVCMOS25 } [get_ports { led[7] }];

## HDMI TX Connector (Nexys Video HDMI Output)
## Using TMDS differential signaling for DVI/HDMI output

## HDMI TX Clock (differential pair)
set_property -dict { PACKAGE_PIN T1    IOSTANDARD TMDS_33 } [get_ports { hdmi_clk_p }];
set_property -dict { PACKAGE_PIN U1    IOSTANDARD TMDS_33 } [get_ports { hdmi_clk_n }];

## HDMI TX Data Channel 0 (Blue - differential pair)
set_property -dict { PACKAGE_PIN W1    IOSTANDARD TMDS_33 } [get_ports { hdmi_data_p[0] }];
set_property -dict { PACKAGE_PIN Y1    IOSTANDARD TMDS_33 } [get_ports { hdmi_data_n[0] }];

## HDMI TX Data Channel 1 (Green - differential pair)
set_property -dict { PACKAGE_PIN AA1   IOSTANDARD TMDS_33 } [get_ports { hdmi_data_p[1] }];
set_property -dict { PACKAGE_PIN AB1   IOSTANDARD TMDS_33 } [get_ports { hdmi_data_n[1] }];

## HDMI TX Data Channel 2 (Red - differential pair)
set_property -dict { PACKAGE_PIN AB5   IOSTANDARD TMDS_33 } [get_ports { hdmi_data_p[2] }];
set_property -dict { PACKAGE_PIN AB6   IOSTANDARD TMDS_33 } [get_ports { hdmi_data_n[2] }];

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Timing constraints for generated clocks (created by Clock Wizard IP)
## clk_out1 = 25.175 MHz pixel clock  
## clk_out2 = 50 MHz ray tracer clock

## False paths between clock domains
# Pixel clock and ray tracer clock are asynchronous
set_false_path -from [get_clocks clk_out1_clk_wiz_0] -to [get_clocks clk_out2_clk_wiz_0]
set_false_path -from [get_clocks clk_out2_clk_wiz_0] -to [get_clocks clk_out1_clk_wiz_0]
