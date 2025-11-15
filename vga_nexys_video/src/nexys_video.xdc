## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_100mhz }];

## Reset button (BTNC)
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS15 } [get_ports { reset }];

##############################################################################
## VGA via PMODs JA and JB only (4-bit per channel = 4096 colors)
## PMOD JA: Red (pins 1-4) + Green (pins 7-10)
## PMOD JB: Blue (pins 1-4) + HSYNC/VSYNC (pins 7-8)
##############################################################################

## VGA Red signals (4-bit) - PMOD JA pins 1-4 (top row)
set_property -dict { PACKAGE_PIN AB22  IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }];  # JA1
set_property -dict { PACKAGE_PIN AB21  IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }];  # JA2
set_property -dict { PACKAGE_PIN AB20  IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }];  # JA3
set_property -dict { PACKAGE_PIN AB18  IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }];  # JA4

## VGA Green signals (4-bit) - PMOD JA pins 7-10 (bottom row)
set_property -dict { PACKAGE_PIN Y21   IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }];  # JA7
set_property -dict { PACKAGE_PIN AA21  IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }];  # JA8
set_property -dict { PACKAGE_PIN AA20  IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }];  # JA9
set_property -dict { PACKAGE_PIN AA18  IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }];  # JA10

## VGA Blue signals (4-bit) - PMOD JB pins 1-4 (top row)
set_property -dict { PACKAGE_PIN V9    IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }];  # JB1
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }];  # JB2
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }];  # JB3
set_property -dict { PACKAGE_PIN W7    IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }];  # JB4

## VGA Sync signals - PMOD JB pins 7-8 (bottom row)
set_property -dict { PACKAGE_PIN W9    IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }]; # JB7
set_property -dict { PACKAGE_PIN Y9    IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }]; # JB8
