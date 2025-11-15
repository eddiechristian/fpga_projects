####################################################################################
## TCL Script to Build (Synthesize, Implement, Generate Bitstream)
####################################################################################

# Set the project name and directory
set project_name "nexys_debouncer_test"
set project_dir "[file normalize [file dirname [info script]]/../vivado_project]"

# Open the project
open_project "$project_dir/$project_name.xpr"

# Run synthesis
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "Synthesis complete."

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Run implementation
puts "Running implementation..."
reset_run impl_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1
puts "Implementation complete."

# Check implementation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# Generate bitstream
puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "Bitstream generation complete."

# Check bitstream generation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

# Report location of bitstream
set bitstream_file "$project_dir/$project_name.runs/impl_1/debounce_test_top.bit"
puts ""
puts "==================================================================="
puts "Build completed successfully!"
puts "Bitstream location: $bitstream_file"
puts ""
puts "To program the FPGA, use:"
puts "  Open Vivado Hardware Manager and program the device"
puts "  Or use: vivado -mode tcl -source program_device.tcl"
puts "==================================================================="

# Close project
close_project
