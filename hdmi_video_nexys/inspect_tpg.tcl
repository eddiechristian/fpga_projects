# Inspect v_tpg IP pins
set project_name "temp_inspect_tpg"
set project_dir "./temp_build_tpg"
set part_number "xc7a200tsbg484-1"

create_project $project_name $project_dir -part $part_number -force
create_bd_design "test_bd_tpg"
create_bd_cell -type ip -vlnv xilinx.com:ip:v_tpg:8.2 v_tpg_0
puts "\n===== v_tpg_0 pins ====="
puts [get_bd_pins v_tpg_0/*]
close_project
