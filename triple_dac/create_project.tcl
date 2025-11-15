# Vivado Project Creation Script for Triple DAC Controller
# Usage: vivado -mode batch -source create_project.tcl

# Set project name and directory
set project_name "triple_dac"
set script_dir [file normalize [file dirname [info script]]]
set project_dir "$script_dir/build"

# Set the FPGA part number (Nexys Video board)
set part_number "xc7a200tsbg484-1"

puts "========================================"
puts "Creating Triple DAC Project"
puts "========================================"
puts "Project: $project_name"
puts "Directory: $project_dir"
puts "Part: $part_number"
puts ""

# Create build directory if it doesn't exist
file mkdir $project_dir

# Create project
create_project $project_name $project_dir -part $part_number -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property default_lib xil_defaultlib [current_project]

#=============================================================================
# Add VHDL source files
#=============================================================================
puts "Adding VHDL source files..."

add_files -norecurse {
    src/hdl/i2c_master.vhd
    src/hdl/mcp4725_driver.vhd
    src/hdl/sine_generator.vhd
    src/hdl/top_module.vhd
}

# Set top module
set_property top top_module [current_fileset]

puts "VHDL sources added!"

#=============================================================================
# Add simulation files
#=============================================================================
puts "Adding simulation files..."

add_files -fileset sim_1 -norecurse {
    src/sim/mcp4725_driver_tb.vhd
}

set_property top mcp4725_driver_tb [get_filesets sim_1]

puts "Simulation files added!"

#=============================================================================
# Add constraints
#=============================================================================
puts "Adding constraints..."

add_files -fileset constrs_1 -norecurse {
    src/constraints/nexys_video.xdc
}

puts "Constraints added!"

#=============================================================================
# Update compile order
#=============================================================================
update_compile_order -fileset sources_1

#=============================================================================
# Project Summary
#=============================================================================
puts ""
puts "========================================"
puts "Project Creation Complete!"
puts "========================================"
puts "Project: $project_name"
puts "Location: $project_dir"
puts ""
puts "Next steps:"
puts "1. Build bitstream:"
puts "   vivado -mode tcl -source build_and_program.tcl"
puts "2. Or open in GUI:"
puts "   vivado $project_dir/$project_name.xpr"
puts "========================================"
