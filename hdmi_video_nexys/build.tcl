# HDMI Video Output Build Script for Nexys Video
# Uses Vivado IP cores for video generation

# Create project
set project_name "hdmi_video_nexys"
set project_dir "./build"
set part_number "xc7a200tsbg484-1"

create_project $project_name $project_dir -part $part_number -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Create IP repository (for custom IPs if needed)
set_property ip_repo_paths {/home/eddie/vivado-library} [current_project]
update_ip_catalog

# Create block design for IP integration
create_bd_design "hdmi_video_bd"

# Create Clocking Wizard IP for pixel clock generation
# 1920x1080@60Hz requires 148.5 MHz pixel clock
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {148.500} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {742.500} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.RESET_PORT {resetn} \
] [get_bd_cells clk_wiz_0]

# Create Video Timing Controller
create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 v_tc_0
set_property -dict [list \
    CONFIG.VIDEO_MODE {1080p} \
    CONFIG.GEN_F0_VBLANK_HEND {1920} \
    CONFIG.GEN_F0_VBLANK_HSTART {1920} \
    CONFIG.GEN_F0_VFRAME_SIZE {1125} \
    CONFIG.GEN_F0_VSYNC_HEND {1920} \
    CONFIG.GEN_F0_VSYNC_HSTART {1920} \
    CONFIG.GEN_F0_VSYNC_VEND {1084} \
    CONFIG.GEN_F0_VSYNC_VSTART {1084} \
    CONFIG.GEN_F1_VBLANK_HEND {1920} \
    CONFIG.GEN_F1_VBLANK_HSTART {1920} \
    CONFIG.GEN_F1_VFRAME_SIZE {1125} \
    CONFIG.GEN_F1_VSYNC_HEND {1920} \
    CONFIG.GEN_F1_VSYNC_HSTART {1920} \
    CONFIG.GEN_F1_VSYNC_VEND {1084} \
    CONFIG.GEN_F1_VSYNC_VSTART {1084} \
    CONFIG.GEN_HACTIVE_SIZE {1920} \
    CONFIG.GEN_HFRAME_SIZE {2200} \
    CONFIG.GEN_HSYNC_END {2052} \
    CONFIG.GEN_HSYNC_START {2008} \
    CONFIG.GEN_VACTIVE_SIZE {1080} \
    CONFIG.enable_detection {false} \
    CONFIG.HAS_AXI4_LITE {false} \
] [get_bd_cells v_tc_0]

# Create AXI4-Stream to Video Out
create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_0
set_property -dict [list \
    CONFIG.C_HAS_ASYNC_CLK {0} \
    CONFIG.C_VTG_MASTER_SLAVE {1} \
] [get_bd_cells v_axi4s_vid_out_0]

# Create Video Test Pattern Generator (for testing)
create_bd_cell -type ip -vlnv xilinx.com:ip:v_tpg:8.2 v_tpg_0
set_property -dict [list \
    CONFIG.MAX_DATA_WIDTH {8} \
    CONFIG.SAMPLES_PER_CLOCK {1} \
] [get_bd_cells v_tpg_0]

# Create RGB to DVI/HDMI encoder
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0
set_property -dict [list \
    CONFIG.kGenerateSerialClk {false} \
    CONFIG.kClkPrimitive {MMCM} \
] [get_bd_cells rgb2dvi_0]

# Make external ports
create_bd_port -dir I -type clk -freq_hz 100000000 sys_clock
set_property CONFIG.FREQ_HZ 100000000 [get_bd_ports sys_clock]
create_bd_port -dir I -type rst sys_resetn
create_bd_port -dir O hdmi_tx_clk_p
create_bd_port -dir O hdmi_tx_clk_n
create_bd_port -dir O -from 2 -to 0 hdmi_tx_p
create_bd_port -dir O -from 2 -to 0 hdmi_tx_n

# Connect clocking
connect_bd_net [get_bd_ports sys_clock] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_ports sys_resetn] [get_bd_pins clk_wiz_0/resetn]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins v_tc_0/clk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins v_axi4s_vid_out_0/aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins v_tpg_0/ap_clk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins rgb2dvi_0/PixelClk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins rgb2dvi_0/SerialClk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins v_tc_0/clken]

# Connect reset
connect_bd_net [get_bd_ports sys_resetn] [get_bd_pins v_tc_0/resetn]
connect_bd_net [get_bd_ports sys_resetn] [get_bd_pins v_axi4s_vid_out_0/aresetn]
connect_bd_net [get_bd_ports sys_resetn] [get_bd_pins v_tpg_0/ap_rst_n]

# Connect video timing controller to AXI4-Stream to Video Out
connect_bd_intf_net [get_bd_intf_pins v_tc_0/vtiming_out] [get_bd_intf_pins v_axi4s_vid_out_0/vtiming_in]

# Connect test pattern generator to video out
connect_bd_intf_net [get_bd_intf_pins v_tpg_0/m_axis_video] [get_bd_intf_pins v_axi4s_vid_out_0/video_in]

# Connect video signals to RGB2DVI encoder
connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_active_video] [get_bd_pins rgb2dvi_0/vid_pVDE]
connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_hsync] [get_bd_pins rgb2dvi_0/vid_pHSync]
connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_vsync] [get_bd_pins rgb2dvi_0/vid_pVSync]
connect_bd_net [get_bd_pins v_axi4s_vid_out_0/vid_data] [get_bd_pins rgb2dvi_0/vid_pData]

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

# Add top module wrapper
add_files -fileset sources_1 ./src/hdl/top_module.vhd

# Add constraints
add_files -fileset constrs_1 ./src/constraints/nexys_video.xdc

# Set top module
set_property top top_module [current_fileset]

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
