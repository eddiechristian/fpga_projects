# Vivado build script for crossbar FP resource sharing system
# NOTE: This script runs in batch mode and does NOT start GUI

# Project settings
set project_name "crossbar"
set project_dir "./build"
set log_dir "./logs"

# Create logs directory if it doesn't exist
file mkdir $log_dir

# Change this to your target FPGA part
set part_number "xc7a200tsbg484-1"

# Configuration (matches crossbar_pkg.vhd constants)
set NUM_MULT_UNITS 10
set NUM_FMA_UNITS 5
set NUM_ADD_UNITS 3
set NUM_PRODUCERS 10

puts "Configuration:"
puts "  Multiplier units: $NUM_MULT_UNITS"
puts "  FMA units: $NUM_FMA_UNITS"
puts "  AddSub units: $NUM_ADD_UNITS"
puts "  Producers: $NUM_PRODUCERS"
puts ""

# Quick VHDL syntax check before spending time on IP generation
puts "========================================"
puts "Checking VHDL syntax..."
puts "========================================"
set syntax_ok 1

# Check HDL source files
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] == 0} {
    puts "WARNING: No VHDL files found in ./src/hdl/"
} else {
    foreach vhdl_file $hdl_files {
        puts "Checking: $vhdl_file"
        if {[catch {read_vhdl -vhdl2008 $vhdl_file} err]} {
            puts "ERROR in $vhdl_file:"
            puts $err
            set syntax_ok 0
        }
    }
}

# Check simulation testbench files
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    foreach sim_file $sim_files {
        puts "Checking: $sim_file"
        if {[catch {read_vhdl -vhdl2008 $sim_file} err]} {
            puts "ERROR in $sim_file:"
            puts $err
            set syntax_ok 0
        }
    }
}

if {!$syntax_ok} {
    puts ""
    puts "========================================"
    puts "VHDL syntax errors detected!"
    puts "Fix syntax errors before running build."
    puts "========================================"
    exit 1
}

puts "All VHDL files passed syntax check."
puts "========================================"
puts ""

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
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
] [get_ips clk_wiz_0]

puts "Creating Floating Point Multiplier IP..."

# Create FP32 Multiplication IP with 2-cycle latency, NonBlocking mode
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_mult -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {2} \
    CONFIG.C_Mult_Usage {Full_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
] [get_ips floating_point_mult]

puts "Creating Floating Point FMA (Fused Multiply-Add) IP..."

# Create FP32 FMA IP - 2 cycle latency, NonBlocking mode
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_fma -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {FMA} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {2} \
    CONFIG.C_Mult_Usage {Full_Usage} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
] [get_ips floating_point_fma]

puts "Creating Floating Point Add/Subtract IP..."

# Create FP32 Add/Subtract IP - 2 cycle latency, NonBlocking mode
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_addsub -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Add_Subtract} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Latency {2} \
    CONFIG.C_Rate {1} \
    CONFIG.Flow_Control {NonBlocking} \
    CONFIG.Maximum_Latency {false} \
    CONFIG.Add_Sub_Value {Both} \
] [get_ips floating_point_addsub]

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
    # Enable VHDL-2008 for all VHDL files
    set_property file_type {VHDL 2008} [get_files *.vhd]
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
set_property top top_module_tb [get_filesets sim_1]

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
set_property -name {xsim.simulate.runtime} -value {200us} -objects [get_filesets sim_1]

exit 1
