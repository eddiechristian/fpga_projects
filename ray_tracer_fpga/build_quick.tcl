#!/usr/bin/env vivado -mode batch -source

# Quick Build Script - Skips IP generation, just runs synthesis/implementation
# Use this after IPs have been generated once with build.tcl

set project_name "ray_tracer_fpga"
set project_dir "./build"

# Open existing project
open_project $project_dir/${project_name}.xpr

# Update compile order in case files changed
update_compile_order -fileset sources_1

# Run synthesis
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1

# Check for synthesis errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis complete."

# Run implementation
puts "Running implementation..."
reset_run impl_1
launch_runs impl_1 -jobs 2
wait_on_run impl_1

# Check for implementation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

puts "Implementation complete."

# Generate bitstream
puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

# Check for bitstream generation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

puts "Bitstream generation complete."

# Generate timing and utilization reports
puts "Generating reports..."
open_run impl_1
report_timing_summary -file $project_dir/timing_summary.rpt
report_utilization -file $project_dir/utilization.rpt
report_power -file $project_dir/power.rpt

puts "Build complete! Bitstream location: $project_dir/${project_name}.runs/impl_1/top_module.bit"

close_project
