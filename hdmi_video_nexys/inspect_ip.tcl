# Inspect IP to see available pins
set project_name "temp_inspect"
set project_dir "./temp_build"
set part_number "xc7a200tsbg484-1"

create_project $project_name $project_dir -part $part_number -force
set_property ip_repo_paths {/home/eddie/vivado-library} [current_project]
update_ip_catalog

create_bd_design "test_bd"

# Create the IPs we need to inspect
create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_0
create_bd_cell -type ip -vlnv digilentinc.com:ip:rgb2dvi:1.4 rgb2dvi_0

# List all pins
puts "\n===== v_axi4s_vid_out_0 pins ====="
puts [get_bd_pins v_axi4s_vid_out_0/*]

puts "\n===== rgb2dvi_0 pins ====="
puts [get_bd_pins rgb2dvi_0/*]

close_project
