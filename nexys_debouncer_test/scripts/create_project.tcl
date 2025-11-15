####################################################################################
## TCL Script to Create Vivado Project for Nexys Video Debouncer Test
####################################################################################

# Set the project name and directory
set project_name "nexys_debouncer_test"
set project_dir "[file normalize [file dirname [info script]]/../vivado_project]"

# Set the FPGA part for Nexys Video
set part_name "xc7a200tsbg484-1"

# Create project
create_project $project_name $project_dir -part $part_name -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Add source files
add_files -norecurse [file normalize [file dirname [info script]]/../rtl/debounce_test_top.vhd]
add_files -norecurse [file normalize [file dirname [info script]]/../rtl/debouncer_instrumented.vhd]

puts "Added project source files"

# Add constraints file
add_files -fileset constrs_1 -norecurse [file normalize [file dirname [info script]]/../constraints/nexys_video.xdc]

# Set top module
set_property top debounce_test_top [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

puts "Project created successfully at: $project_dir"
puts ""
puts "To build the project, run:"
puts "  vivado -mode batch -source [file normalize [file dirname [info script]]/build_project.tcl]"
puts ""
puts "Or open the project in Vivado GUI:"
puts "  vivado $project_dir/$project_name.xpr"
