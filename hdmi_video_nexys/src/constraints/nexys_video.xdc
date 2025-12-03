# Clock signal (100 MHz)
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports CLK100MHZ]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports CLK100MHZ]

# Reset button (active low)
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS15} [get_ports CPU_RESETN]

# HDMI TX signals
set_property -dict {PACKAGE_PIN T1 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_p]
set_property -dict {PACKAGE_PIN U1 IOSTANDARD TMDS_33} [get_ports hdmi_tx_clk_n]

set_property -dict {PACKAGE_PIN W1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[0]}]
set_property -dict {PACKAGE_PIN Y1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[0]}]

set_property -dict {PACKAGE_PIN AA1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[1]}]
set_property -dict {PACKAGE_PIN AB1 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[1]}]

set_property -dict {PACKAGE_PIN AB3 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[2]}]
set_property -dict {PACKAGE_PIN AB2 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[2]}]

# Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Bitstream configuration
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
