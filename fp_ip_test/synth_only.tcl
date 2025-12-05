# Synthesis-only script - for post-synthesis simulation
# Does not run implementation or generate bitstream

set project_name "fp_ip_test"
set project_dir "./build"

puts "Running synthesis only..."

# Check if project exists
if {![file exists "$project_dir/$project_name.xpr"]} {
    puts "ERROR: Project doesn't exist. Run build.tcl first."
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

puts ""
puts "================================"
puts "Synthesis complete!"
puts "================================"
puts "You can now run post-synthesis simulation"
puts "  Flow → Run Simulation → Run Post-Synthesis Functional Simulation"
puts ""
