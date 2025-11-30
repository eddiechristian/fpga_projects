# Nexys Video FMC Loopback Test Build Script
# Digilent Nexys Video (xc7a200tsbg484-1)

# Set the reference directory for source file relative paths
set origin_dir [file dirname [info script]]

# Create project
create_project nexys_video_fmc_test ${origin_dir}/build -part xc7a200tsbg484-1 -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]

# Add HDL source files
add_files -fileset sources_1 ${origin_dir}/src/hdl/top_module.vhd

# Add constraints
add_files -fileset constrs_1 ${origin_dir}/src/constraints/nexys_video.xdc

# Set top module
set_property top top_module [current_fileset]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1

# Check for synthesis errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "ERROR: Synthesis failed"
}

puts "Synthesis completed successfully"

# Run implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check for implementation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "ERROR: Implementation failed"
}

puts "Implementation completed successfully"

# Generate reports
open_run impl_1
report_utilization -file ${origin_dir}/build/utilization.rpt
report_timing_summary -file ${origin_dir}/build/timing_summary.rpt

puts "Build completed successfully!"
puts "Bitstream: ${origin_dir}/build/nexys_video_fmc_test.runs/impl_1/top_module.bit"
