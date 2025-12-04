# Quick build script for Floating Point IP test project
# This script reuses existing IP cores and only rebuilds HDL sources
# Much faster than full build.tcl when IP cores haven't changed

# Project settings
set project_name "fp_ip_test"
set project_dir "./build"

# Change this to your target FPGA part
set part_number "xc7a200tsbg484-1"

puts "Quick build - reusing existing IP cores"

# Check if project exists
if {![file exists "$project_dir/$project_name.xpr"]} {
    puts "ERROR: Project doesn't exist. Run build.tcl first to generate IP cores."
    exit 1
}

# Open existing project
open_project "$project_dir/$project_name.xpr"

# Update HDL source files
puts "Updating HDL source files..."
remove_files [get_files -of_objects [get_filesets sources_1] *.vhd]
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
}

# Update simulation files
puts "Updating simulation files..."
remove_files [get_files -of_objects [get_filesets sim_1] *.vhd]
set sim_files [glob -nocomplain ./src/sim/*.vhd]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
}

# Update constraints (if any exist)
set xdc_files [glob -nocomplain ./src/constraints/*.xdc]
if {[llength $xdc_files] > 0} {
    remove_files [get_files -of_objects [get_filesets constrs_1] *.xdc]
    add_files -fileset constrs_1 $xdc_files
}

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Running synthesis..."

# Reset and run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Running implementation..."

# Reset and run implementation
reset_run impl_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# Generate bitstream
puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

# Generate reports
puts "Generating reports..."
open_run impl_1
report_utilization -file $project_dir/utilization.rpt
report_timing_summary -file $project_dir/timing.rpt
report_power -file $project_dir/power.rpt

puts ""
puts "================================"
puts "Quick build complete!"
puts "================================"
puts "Project location: $project_dir/$project_name.xpr"
puts "Bitstream: $project_dir/$project_name.runs/impl_1/top_module.bit"
puts "Reports generated:"
puts "  Utilization: $project_dir/utilization.rpt"
puts "  Timing:      $project_dir/timing.rpt"
puts "  Power:       $project_dir/power.rpt"
puts ""
