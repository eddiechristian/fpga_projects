# Vivado build script for FP32 Multiply FIFO (Stage 1)
# This script creates the project from scratch, generates floating point multiplier IP,
# BRAM FIFOs, and runs synthesis/implementation to measure resource usage
# NOTE: This script runs in batch mode and does NOT start GUI

# Project settings
set project_name "resource_test"
set project_dir "./build"

# Change this to your target FPGA part
set part_number "xc7a200tsbg484-1"

# Clean build directory if it exists
if {[file exists $project_dir]} {
    puts "Removing existing build directory..."
    file delete -force $project_dir
}

# Create fresh project directory
file mkdir $project_dir

# Create project
create_project $project_name $project_dir -part $part_number -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property default_lib work [current_project]

# Create IP directory
set ip_dir "$project_dir/ip"
file mkdir $ip_dir
set_property ip_repo_paths $ip_dir [current_project]

puts "Creating Clocking Wizard IP..."

# Create Clocking Wizard for 200 MHz clock
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir $ip_dir
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
] [get_ips clk_wiz_0]

puts "Creating Floating Point Multiplier IP..."

# Create FP32 Multiplication IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_mult -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {8} \
    CONFIG.C_Mult_Usage {Full_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {false} \
] [get_ips floating_point_mult]


puts "Creating AXI4-Stream FIFO IPs..."

# Create Input FIFO with AXI4-Stream interface
# TDATA width = 64 bits (32-bit operand_a + 32-bit operand_b)
# TUSER width = 4 bits (for routing to 0-9 multipliers, using TDEST alternative)
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name axis_input_fifo -dir $ip_dir
set_property -dict [list \
    CONFIG.Fifo_Implementation {Common_Clock_Block_RAM} \
    CONFIG.Performance_Options {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width {32} \
    CONFIG.Input_Depth {1024} \
    CONFIG.Output_Data_Width {32} \
    CONFIG.Output_Depth {1024} \
    CONFIG.Reset_Type {Asynchronous_Reset} \
    CONFIG.Full_Flags_Reset_Value {1} \
    CONFIG.Use_Extra_Logic {true} \
    CONFIG.Data_Count {true} \
    CONFIG.Data_Count_Width {10} \
    CONFIG.Write_Data_Count_Width {10} \
    CONFIG.Read_Data_Count_Width {10} \
    CONFIG.INTERFACE_TYPE {AXI_STREAM} \
    CONFIG.TDATA_NUM_BYTES {8} \
    CONFIG.TUSER_WIDTH {4} \
    CONFIG.Enable_TLAST {false} \
    CONFIG.HAS_TKEEP {false} \
    CONFIG.HAS_TSTRB {false} \
] [get_ips axis_input_fifo]

# Create Output FIFO with AXI4-Stream interface
# TDATA width = 32 bits (FP32 result)
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name axis_output_fifo -dir $ip_dir
set_property -dict [list \
    CONFIG.Fifo_Implementation {Common_Clock_Block_RAM} \
    CONFIG.Performance_Options {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width {32} \
    CONFIG.Input_Depth {1024} \
    CONFIG.Output_Data_Width {32} \
    CONFIG.Output_Depth {1024} \
    CONFIG.Reset_Type {Asynchronous_Reset} \
    CONFIG.Full_Flags_Reset_Value {1} \
    CONFIG.Use_Extra_Logic {true} \
    CONFIG.Data_Count {true} \
    CONFIG.Data_Count_Width {10} \
    CONFIG.Write_Data_Count_Width {10} \
    CONFIG.Read_Data_Count_Width {10} \
    CONFIG.INTERFACE_TYPE {AXI_STREAM} \
    CONFIG.TDATA_NUM_BYTES {4} \
    CONFIG.TUSER_WIDTH {0} \
    CONFIG.Enable_TLAST {false} \
    CONFIG.HAS_TKEEP {false} \
    CONFIG.HAS_TSTRB {false} \
] [get_ips axis_output_fifo]

puts "Creating AXI4-Stream Interconnect (1-to-10 routing)..."

# Create AXI4-Stream Interconnect for routing to 10 multipliers
create_ip -name axis_interconnect -vendor xilinx.com -library ip -version 1.1 -module_name axis_interconnect_0 -dir $ip_dir
set_property -dict [list \
    CONFIG.C_NUM_SI_SLOTS {1} \
    CONFIG.C_NUM_MI_SLOTS {10} \
    CONFIG.SWITCH_TDATA_NUM_BYTES {8} \
    CONFIG.C_SWITCH_TDEST_WIDTH {4} \
    CONFIG.HAS_TSTRB {false} \
    CONFIG.HAS_TKEEP {false} \
    CONFIG.HAS_TLAST {false} \
    CONFIG.HAS_TID {false} \
    CONFIG.C_M00_AXIS_BASETDEST {0x00000000} \
    CONFIG.C_M00_AXIS_HIGHTDEST {0x00000000} \
    CONFIG.C_M01_AXIS_BASETDEST {0x00000001} \
    CONFIG.C_M01_AXIS_HIGHTDEST {0x00000001} \
    CONFIG.C_M02_AXIS_BASETDEST {0x00000002} \
    CONFIG.C_M02_AXIS_HIGHTDEST {0x00000002} \
    CONFIG.C_M03_AXIS_BASETDEST {0x00000003} \
    CONFIG.C_M03_AXIS_HIGHTDEST {0x00000003} \
    CONFIG.C_M04_AXIS_BASETDEST {0x00000004} \
    CONFIG.C_M04_AXIS_HIGHTDEST {0x00000004} \
    CONFIG.C_M05_AXIS_BASETDEST {0x00000005} \
    CONFIG.C_M05_AXIS_HIGHTDEST {0x00000005} \
    CONFIG.C_M06_AXIS_BASETDEST {0x00000006} \
    CONFIG.C_M06_AXIS_HIGHTDEST {0x00000006} \
    CONFIG.C_M07_AXIS_BASETDEST {0x00000007} \
    CONFIG.C_M07_AXIS_HIGHTDEST {0x00000007} \
    CONFIG.C_M08_AXIS_BASETDEST {0x00000008} \
    CONFIG.C_M08_AXIS_HIGHTDEST {0x00000008} \
    CONFIG.C_M09_AXIS_BASETDEST {0x00000009} \
    CONFIG.C_M09_AXIS_HIGHTDEST {0x00000009} \
] [get_ips axis_interconnect_0]

puts "Creating AXI4-Stream Combiner (10-to-1 results collection)..."

# Create AXI4-Stream Combiner to collect results from 10 multipliers
create_ip -name axis_combiner -vendor xilinx.com -library ip -version 1.1 -module_name axis_combiner_0 -dir $ip_dir
set_property -dict [list \
    CONFIG.NUM_SI {10} \
    CONFIG.TDATA_NUM_BYTES {4} \
    CONFIG.HAS_TKEEP {0} \
    CONFIG.HAS_TLAST {0} \
    CONFIG.HAS_TSTRB {0} \
    CONFIG.TDEST_WIDTH {0} \
    CONFIG.TID_WIDTH {0} \
] [get_ips axis_combiner_0]

# Generate all IP outputs and synthesis products
puts "Generating IP cores..."
generate_target all [get_ips]

# Create synthesis checkpoints for all IPs
puts "Creating synthesis runs for all IPs..."
set_property generate_synth_checkpoint true [get_files *.xci]
foreach ip [get_ips] {
    set ip_name [get_property NAME $ip]
    puts "Creating IP run for: $ip_name"
    create_ip_run $ip
}

# Launch all IP synthesis runs in parallel
puts "Synthesizing all IP cores in parallel..."
set ip_runs [get_runs *_synth_1]
launch_runs $ip_runs -jobs 8
foreach ip_run $ip_runs {
    wait_on_run $ip_run
    set run_status [get_property STATUS $ip_run]
    puts "Completed IP run: $ip_run - Status: $run_status"
}

puts "IP generation complete."

# Add HDL source files
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
}

# Add simulation files
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
}

# Add waveform configuration files
set wcfg_files [glob -nocomplain ./src/sim/*.wcfg]
if {[llength $wcfg_files] > 0} {
    add_files -fileset sim_1 $wcfg_files
}

# Add constraints (if any exist)
set xdc_files [glob -nocomplain ./src/constraints/*.xdc]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
}

# Set top module
set_property top top_module [current_fileset]
set_property top multiply_fifo_tb [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Running synthesis..."

# Run synthesis with parallel jobs
launch_runs synth_1 -jobs 8
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis complete - Status: $synth_status"

# Set up post-synthesis simulation
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]

puts "Running implementation..."

# Run implementation with parallel jobs
launch_runs impl_1 -jobs 8
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation complete - Status: $impl_status"

# Generate reports (skip bitstream for resource test)
puts "Generating resource utilization reports..."
open_run impl_1
report_utilization -file $project_dir/utilization.rpt
report_timing_summary -file $project_dir/timing.rpt
report_power -file $project_dir/power.rpt

puts "\n========================================"
puts "Resource test complete!"
puts "========================================"
puts "Project location: $project_dir/$project_name.xpr"
puts "Reports generated:"
puts "  Utilization: $project_dir/utilization.rpt"
puts "  Timing:      $project_dir/timing.rpt"
puts "  Power:       $project_dir/power.rpt"
puts "========================================"
puts "Note: Bitstream generation skipped (no I/O constraints)"
