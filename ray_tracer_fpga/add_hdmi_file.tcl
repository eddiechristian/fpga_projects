#!/usr/bin/env vivado -mode batch -source

# Script to add rgb2tmds.vhd to the existing project

set project_name "ray_tracer_fpga"
set project_dir "./build"

# Open existing project
open_project $project_dir/${project_name}.xpr

# Add the new HDMI/TMDS encoder file
add_files -fileset sources_1 ./src/hdl/rgb2tmds.vhd

# Update compile order
update_compile_order -fileset sources_1

puts "Successfully added rgb2tmds.vhd to project"
close_project
