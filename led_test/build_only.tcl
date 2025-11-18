# Build Only Script for LED Test
# This script builds the bitstream without programming
# Usage: vivado -mode batch -source build_only.tcl

set project_name "led_test"
set script_dir [file normalize [file dirname [info script]]]
set project_dir "$script_dir/build"
set project_file "$project_dir/$project_name.xpr"

puts "========================================"
puts "Build Only Script"
puts "========================================"
puts "Project: $project_name"
puts ""

# Check if project exists
if {![file exists $project_file]} {
    puts "ERROR: Project not found at $project_file"
    puts "Please run create_project.tcl first"
    exit 1
}

# Open project
puts "Opening project..."
open_project $project_file

#=============================================================================
# Build bitstream
#=============================================================================
puts ""
puts "========================================"
puts "Building Bitstream"
puts "========================================"

# Reset and launch synthesis
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}
puts "Synthesis complete!"

# Launch implementation and bitstream generation
puts ""
puts "Running implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}
puts "Implementation complete!"

# Get bitstream location
set bitstream_file "[get_property DIRECTORY [get_runs impl_1]]/top_module.bit"
puts ""
puts "Bitstream generated: $bitstream_file"

puts ""
puts "========================================"
puts "Build Complete!"
puts "========================================"
puts "Bitstream: $bitstream_file"
puts "========================================"
