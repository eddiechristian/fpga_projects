# Vivado build script for Floating Point IP test project
# This script creates the project from scratch, generates floating point IP cores,
# runs synthesis, implementation, and generates bitstream
# NOTE: This script runs in batch mode and does NOT start GUI

# Project settings
set project_name "fp_ip_test"
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

# Create Clocking Wizard for 150 MHz clock (reduced from 200 for timing)
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir $ip_dir
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {150.000} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
] [get_ips clk_wiz_0]

puts "Creating Floating Point IP cores..."

# 1. Create Square Root IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_sqrt -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Square_root} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {28} \
    CONFIG.C_Mult_Usage {No_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {false} \
] [get_ips floating_point_sqrt]

# 2. Create Multiplication IP
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

# 3. Create Addition IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_add -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Add_Subtract} \
    CONFIG.Add_Sub_Value {Add} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {11} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {false} \
] [get_ips floating_point_add]

# 4. Create Compare IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_compare -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_Latency {2} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {false} \
] [get_ips floating_point_compare]

# 5. Create Divide IP
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_div -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Divide} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {28} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Has_RESULT_TREADY {false} \
] [get_ips floating_point_div]

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

# Launch and wait for IP synthesis runs - SEQUENTIALLY to avoid memory issues
puts "Synthesizing all IP cores sequentially..."
foreach ip_run [get_runs *_synth_1] {
    puts "Launching IP run: $ip_run"
    launch_runs $ip_run -jobs 1
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

# Add constraints (if any exist)
set xdc_files [glob -nocomplain ./src/constraints/*.xdc]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
}

# Set top module
set_property top top_module [current_fileset]
set_property top top_module_tb [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Running synthesis..."

# Run synthesis
launch_runs synth_1 -jobs 1
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis complete - Status: $synth_status"

# Set up post-synthesis simulation
set_property -name {xsim.simulate.runtime} -value {2000ns} -objects [get_filesets sim_1]

puts "Running implementation..."

# Run implementation
launch_runs impl_1 -jobs 1
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation complete - Status: $impl_status"

puts "Generating bitstream..."

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1

set bitstream_status [get_property STATUS [get_runs impl_1]]
puts "Bitstream generation complete - Status: $bitstream_status"

# Generate reports
open_run impl_1
report_utilization -file $project_dir/utilization.rpt
report_timing_summary -file $project_dir/timing.rpt
report_power -file $project_dir/power.rpt

puts "\n========================================"
puts "Build complete!"
puts "========================================"
puts "Project location: $project_dir/$project_name.xpr"
puts "Bitstream:        $project_dir/$project_name.runs/impl_1/top_module.bit"
puts "Reports generated:"
puts "  Utilization: $project_dir/utilization.rpt"
puts "  Timing:      $project_dir/timing.rpt"
puts "  Power:       $project_dir/power.rpt"
puts "========================================"
