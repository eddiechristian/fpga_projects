# Vivado Project Creation Script
# This script creates the fourteen_seg_display project from source files

# Set project name and directory
set project_name "fourteen_seg_display"
set script_dir [file normalize [file dirname [info script]]]
set project_dir "$script_dir/build"

# Set the FPGA part number (Nexys Video board)
set part_number "xc7a200tsbg484-1"

# Create build directory if it doesn't exist
file mkdir $project_dir

# Create project in build directory
create_project $project_name $project_dir -part $part_number -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property default_lib xil_defaultlib [current_project]

# Add HDL source files
add_files -norecurse {
    src/hdl/top_module.vhd
    src/ascii_to_14seg.vhd
}

# Set top module
set_property top top_module [current_fileset]

# Add simulation files
#add_files -fileset sim_1 -norecurse {
#    src/sim/tb_segment_multiplexor.vhd
#}

# Set simulation top
#set_property top tb_segment_multiplexor [get_filesets sim_1]

# Add constraints
add_files -fileset constrs_1 -norecurse {
    src/constraints/nexys_video.xdc
}

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set synthesis and implementation strategies
set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

puts "Project created successfully!"
puts "Project location: $project_dir"
puts ""
puts "To build the project, run:"
puts "  launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts ""
puts "Or in GUI, open: $project_dir/$project_name.xpr"
