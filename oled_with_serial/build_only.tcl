# Vivado Build Script for OLED Demo
# This script builds the bitstream without programming
# Usage: vivado -mode batch -source build_only.tcl

set project_name "oled_with_serial"
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
puts ""

puts "========================================"
puts "Building Bitstream"
puts "========================================"

# First, run IP synthesis if not already done
puts "Checking IP synthesis status..."
set ip_runs [get_runs -filter {IS_SYNTHESIS && PARENT == {}}]
foreach run $ip_runs {
    if {[get_property PROGRESS $run] != "100%"} {
        puts "Synthesizing IP: $run"
        launch_runs $run -jobs 4
        wait_on_run $run
        if {[get_property PROGRESS $run] != "100%"} {
            puts "ERROR: IP synthesis failed for $run"
            exit 1
        }
    }
}
puts "IP synthesis complete!"
puts ""

# Run synthesis
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}
puts "Synthesis complete!"
puts ""

# Run implementation
puts "Running implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}
puts "Implementation complete!"
puts ""

# Get bitstream path
set bitstream_file "[get_property DIRECTORY [get_runs impl_1]]/top_module.bit"
puts "Bitstream generated: $bitstream_file"
puts ""

puts "========================================"
puts "Build Complete!"
puts "========================================"
puts "Bitstream: $bitstream_file"
puts "========================================"
