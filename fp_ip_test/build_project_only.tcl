# Vivado build script - Project setup only (no synthesis)
# Creates project, generates IP cores, and adds source files

set project_name "fp_ip_test"
set project_dir "./build"
set part_number "xc7a200tsbg484-1"

# Clean build directory if it exists
if {[file exists $project_dir]} {
    puts "Removing existing build directory..."
    file delete -force $project_dir
}

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

puts "Creating Floating Point IP cores..."

# 1. Square Root IP
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

# 2. Multiplication IP
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

# 3. Addition IP
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

# 4. Compare IP
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

# 5. Divide IP
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

# Generate all IP
puts "Generating IP cores..."
generate_target all [get_ips]

puts "Creating synthesis runs for IPs..."
set_property generate_synth_checkpoint true [get_files *.xci]
foreach ip [get_ips] {
    create_ip_run $ip
}

# Launch IP synthesis sequentially
puts "Synthesizing IP cores..."
foreach ip_run [get_runs *_synth_1] {
    puts "Launching: $ip_run"
    launch_runs $ip_run -jobs 4
    wait_on_run $ip_run
}

puts "IP generation complete."

# Add HDL source files
puts "Adding HDL source files..."
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
}

# Add simulation files
puts "Adding simulation files..."
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
}

# Add waveform configs
set wcfg_files [glob -nocomplain ./src/sim/*.wcfg]
if {[llength $wcfg_files] > 0} {
    add_files -fileset sim_1 $wcfg_files
}

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "\n========================================"
puts "Project setup complete!"
puts "========================================"
puts "Project: $project_dir/$project_name.xpr"
puts ""
puts "To run Stage 1 simulation:"
puts "1. Open project in Vivado GUI"
puts "2. Set sphere_intersection_stage1_tb as top"
puts "3. Run Behavioral Simulation"
puts "========================================"
