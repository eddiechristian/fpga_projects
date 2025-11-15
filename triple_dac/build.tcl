#!/usr/bin/tclsh

# Build script for triple DAC controller project
# Target: Nexys Video (XC7A200T-1SBG484C)

set project_name "triple_dac_controller"
set top_module "triple_dac_top"
set part "xc7a200tsbg484-1"

# Get the directory where this script is located
set script_dir [file dirname [file normalize [info script]]]
set build_dir "${script_dir}/build"
set src_dir "${script_dir}/src"

# Create project
puts "Creating project: ${project_name}"
create_project ${project_name} ${build_dir}/${project_name} -part ${part} -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Add source files
puts "Adding source files..."
add_files -fileset sources_1 "${src_dir}/hdl/i2c_master.vhd"
add_files -fileset sources_1 "${src_dir}/hdl/mcp4725_driver.vhd"
add_files -fileset sources_1 "${src_dir}/hdl/sine_generator.vhd"
add_files -fileset sources_1 "${src_dir}/hdl/triple_dac_top.vhd"

# Add simulation files
puts "Adding simulation files..."
add_files -fileset sim_1 "${src_dir}/sim/mcp4725_driver_tb.vhd"
set_property top mcp4725_driver_tb [get_filesets sim_1]

# Add constraints file
puts "Adding constraints file..."
add_files -fileset constrs_1 "${src_dir}/constraints/nexys_video.xdc"

# Set top module
set_property top ${top_module} [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

# Run synthesis
puts "Running synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "Synthesis complete"

# Check synthesis results
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}

# Run implementation
puts "Running implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1
puts "Implementation complete"

# Check implementation results
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}

# Generate bitstream
puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "Bitstream generation complete"

# Report timing summary
open_run impl_1
report_timing_summary -file ${build_dir}/timing_summary.rpt
report_utilization -file ${build_dir}/utilization.rpt

puts ""
puts "============================================"
puts "Build complete!"
puts "Bitstream: ${build_dir}/${project_name}/${project_name}.runs/impl_1/${top_module}.bit"
puts "Timing report: ${build_dir}/timing_summary.rpt"
puts "Utilization report: ${build_dir}/utilization.rpt"
puts "============================================"
