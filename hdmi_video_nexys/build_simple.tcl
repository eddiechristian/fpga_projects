# HDMI Video Output Build Script for Nexys Video - Simplified
# Direct video generation without TPG

# Create project
set project_name "hdmi_video_nexys"
set project_dir "./build"
set part_number "xc7a200tsbg484-1"

create_project $project_name $project_dir -part $part_number -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Create IP repository (for Digilent rgb2dvi)
set_property ip_repo_paths {/home/eddie/vivado-library} [current_project]
update_ip_catalog

# Create block design for IP integration
create_bd_design "hdmi_video_bd"

# Create Clocking Wizard IP for pixel clock generation
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {148.500} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {742.500} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.RESET_PORT {resetn} \
] [get_bd_cells clk_wiz_0]

# Create RGB to DVI/HDMI encoder
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0
set_property -dict [list \
    CONFIG.kGenerateSerialClk {false} \
] [get_bd_cells rgb2dvi_0]

# Make external ports
create_bd_port -dir I -type clk -freq_hz 100000000 sys_clock
set_property CONFIG.FREQ_HZ 100000000 [get_bd_ports sys_clock]
create_bd_port -dir I -type rst sys_resetn
create_bd_port -dir O hdmi_tx_clk_p
create_bd_port -dir O hdmi_tx_clk_n
create_bd_port -dir O -from 2 -to 0 hdmi_tx_p
create_bd_port -dir O -from 2 -to 0 hdmi_tx_n

# Make video signal ports (to be driven by VHDL)
create_bd_port -dir I -from 23 -to 0 vid_data
create_bd_port -dir I vid_hsync
create_bd_port -dir I vid_vsync
create_bd_port -dir I vid_active
create_bd_port -dir O -type clk pixel_clk
create_bd_port -dir O locked

# Connect clocking
connect_bd_net [get_bd_ports sys_clock] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_ports sys_resetn] [get_bd_pins clk_wiz_0/resetn]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins rgb2dvi_0/PixelClk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins rgb2dvi_0/SerialClk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_ports pixel_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_ports locked]

# Connect video signals
connect_bd_net [get_bd_ports vid_data] [get_bd_pins rgb2dvi_0/vid_pData]
connect_bd_net [get_bd_ports vid_hsync] [get_bd_pins rgb2dvi_0/vid_pHSync]
connect_bd_net [get_bd_ports vid_vsync] [get_bd_pins rgb2dvi_0/vid_pVSync]
connect_bd_net [get_bd_ports vid_active] [get_bd_pins rgb2dvi_0/vid_pVDE]

# Connect reset - use aRst (active high)
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 inverter_0
set_property -dict [list \
    CONFIG.C_SIZE {1} \
    CONFIG.C_OPERATION {not} \
] [get_bd_cells inverter_0]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins inverter_0/Op1]
connect_bd_net [get_bd_pins inverter_0/Res] [get_bd_pins rgb2dvi_0/aRst]

# Connect HDMI output
connect_bd_net [get_bd_ports hdmi_tx_clk_p] [get_bd_pins rgb2dvi_0/TMDS_Clk_p]
connect_bd_net [get_bd_ports hdmi_tx_clk_n] [get_bd_pins rgb2dvi_0/TMDS_Clk_n]
connect_bd_net [get_bd_ports hdmi_tx_p] [get_bd_pins rgb2dvi_0/TMDS_Data_p]
connect_bd_net [get_bd_ports hdmi_tx_n] [get_bd_pins rgb2dvi_0/TMDS_Data_n]

# Validate and save block design
validate_bd_design
save_bd_design

# Generate block design
generate_target all [get_files $project_dir/$project_name.srcs/sources_1/bd/hdmi_video_bd/hdmi_video_bd.bd]

# Create HDL wrapper
make_wrapper -files [get_files $project_dir/$project_name.srcs/sources_1/bd/hdmi_video_bd/hdmi_video_bd.bd] -top
add_files -norecurse $project_dir/$project_name.gen/sources_1/bd/hdmi_video_bd/hdl/hdmi_video_bd_wrapper.vhd

# Add top module wrapper with pattern generator
add_files -fileset sources_1 ./src/hdl/top_module_simple.vhd

# Add constraints
add_files -fileset constrs_1 ./src/constraints/nexys_video.xdc

# Set top module
set_property top top_module_simple [current_fileset]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Run implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Generate reports
open_run impl_1
report_utilization -file $project_dir/utilization.rpt
report_timing_summary -file $project_dir/timing.rpt

puts "Build complete!"
