# Create project
create_project hdmi_bare ./project -part xc7a200tsbg484-1 -force

# Add Digilent IP repository
set_property ip_repo_paths "/tmp/vivado-library" [current_project]
update_ip_catalog

# Add source files
add_files vga_timing.vhd

# Create block design
create_bd_design "design_1"

# Add RGB to DVI IP
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0
set_property -dict [list CONFIG.kGenerateSerialClk {true} CONFIG.kClkPrimitive {MMCM}] [get_bd_cells rgb2dvi_0]

# Add clock wizard
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} \
    CONFIG.USE_RESET {false} \
] [get_bd_cells clk_wiz_0]

# Add VGA timing module as RTL
create_bd_cell -type module -reference vga_timing vga_timing_0

# Create ports
create_bd_port -dir I -type clk sys_clk
set_property CONFIG.FREQ_HZ 100000000 [get_bd_ports sys_clk]
create_bd_port -dir O -from 2 -to 0 TMDS_DATA_P
create_bd_port -dir O -from 2 -to 0 TMDS_DATA_N
create_bd_port -dir O TMDS_CLK_P
create_bd_port -dir O TMDS_CLK_N
create_bd_port -dir O led_out

# Connect clocks
connect_bd_net [get_bd_ports sys_clk] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins vga_timing_0/clk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins rgb2dvi_0/PixelClk]

# Connect video signals
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {3}] [get_bd_cells xlconcat_0]

connect_bd_net [get_bd_pins vga_timing_0/blue] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins vga_timing_0/green] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins vga_timing_0/red] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins rgb2dvi_0/vid_pData]

connect_bd_net [get_bd_pins vga_timing_0/hsync] [get_bd_pins rgb2dvi_0/vid_pHSync]
connect_bd_net [get_bd_pins vga_timing_0/vsync] [get_bd_pins rgb2dvi_0/vid_pVSync]
connect_bd_net [get_bd_pins vga_timing_0/video_active] [get_bd_pins rgb2dvi_0/vid_pVDE]

# Connect TMDS outputs
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_DATA_P] [get_bd_ports TMDS_DATA_P]
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_DATA_N] [get_bd_ports TMDS_DATA_N]
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_CLK_P] [get_bd_ports TMDS_CLK_P]
connect_bd_net [get_bd_pins rgb2dvi_0/TMDS_CLK_N] [get_bd_ports TMDS_CLK_N]

# Connect LED
connect_bd_net [get_bd_pins vga_timing_0/led] [get_bd_ports led_out]

# Create reset for RGB2DVI
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins rgb2dvi_0/aRst]

# Validate
regenerate_bd_layout
validate_bd_design
save_bd_design

# Create wrapper
make_wrapper -files [get_files ./project/hdmi_bare.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./project/hdmi_bare.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v

# Add constraints
set constraints_file [open "./constraints.xdc" w]
puts $constraints_file "set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} \[get_ports sys_clk\]"
puts $constraints_file "create_clock -period 10.000 \[get_ports sys_clk\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN T1 IOSTANDARD TMDS_33} \[get_ports TMDS_CLK_P\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN U1 IOSTANDARD TMDS_33} \[get_ports TMDS_CLK_N\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN W1 IOSTANDARD TMDS_33} \[get_ports {TMDS_DATA_P\[0\]}\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN Y1 IOSTANDARD TMDS_33} \[get_ports {TMDS_DATA_N\[0\]}\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN AA1 IOSTANDARD TMDS_33} \[get_ports {TMDS_DATA_P\[1\]}\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN AB1 IOSTANDARD TMDS_33} \[get_ports {TMDS_DATA_N\[1\]}\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN AB3 IOSTANDARD TMDS_33} \[get_ports {TMDS_DATA_P\[2\]}\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN AB2 IOSTANDARD TMDS_33} \[get_ports {TMDS_DATA_N\[2\]}\]"
puts $constraints_file "set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS25} \[get_ports led_out\]"
close $constraints_file

add_files -fileset constrs_1 ./constraints.xdc
set_property top design_1_wrapper [current_fileset]

# Build
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Bitstream: ./project/hdmi_bare.runs/impl_1/design_1_wrapper.bit"
