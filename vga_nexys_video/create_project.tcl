#!/usr/bin/tclsh

# Set project name and directory
set project_name "vga_nexys_video"
set project_dir "./build"
set src_dir "./src"

# Create project
create_project ${project_name} ${project_dir} -part xc7a200tsbg484-1 -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Add HDL source files
add_files -fileset sources_1 ${src_dir}/hdl/top_module.vhd
set_property top top_module [current_fileset]

# Add simulation files
add_files -fileset sim_1 ${src_dir}/sim/top_module_tb.vhd
set_property top top_module_tb [get_filesets sim_1]

# Add constraint file
add_files -fileset constrs_1 ${src_dir}/constraints/nexys_video.xdc

# Update compile order
update_compile_order -fileset sources_1

puts "Project created successfully!"
puts "To synthesize, implement and generate bitstream, run: vivado -mode batch -source build_and_program.tcl"
