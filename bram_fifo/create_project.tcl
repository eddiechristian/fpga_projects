# Vivado Project Creation Script
# This script creates a custom FIFO using Block RAM IP

# Set project name and directory
set project_name "bram_fifo"
set script_dir [file normalize [file dirname [info script]]]
set project_dir "$script_dir/build"

# Set the FPGA part number (Nexys Video board - adjust if needed)
set part_number "xc7a200tsbg484-1"

# Create build directory if it doesn't exist
file mkdir $project_dir

# Create project in build directory
create_project $project_name $project_dir -part $part_number -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

# Create Block Memory Generator IP (True Dual Port RAM)
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name bram_tdp

# Configure the BRAM IP as True Dual Port RAM
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {512} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Write_Width_B {32} \
    CONFIG.Read_Width_B {32} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Byte_Size {9} \
    CONFIG.Algorithm {Minimum_Area} \
] [get_ips bram_tdp]

# Generate the BRAM IP
generate_target {instantiation_template} [get_ips bram_tdp]
generate_target all [get_ips bram_tdp]
catch {config_ip_cache -export [get_ips bram_tdp]}
export_ip_user_files -of_objects [get_ips bram_tdp] -no_script -sync -force -quiet
create_ip_run [get_ips bram_tdp]
launch_runs bram_tdp_synth_1 -jobs 4
wait_on_run bram_tdp_synth_1

# Add HDL source files
add_files -norecurse {
    src/hdl/fifo_controller.vhd
    src/hdl/bram_fifo.vhd
}

# Set top module
set_property top bram_fifo [current_fileset]

# Add simulation files
add_files -fileset sim_1 -norecurse {
    src/sim/tb_bram_fifo.vhd
}

# Set simulation top
set_property top tb_bram_fifo [get_filesets sim_1]

# Set simulation runtime
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created successfully!"
puts "Project location: $project_dir"
puts ""
puts "Custom FIFO Configuration:"
puts "  - Implementation: True Dual Port BRAM"
puts "  - Data Width: 32 bits"
puts "  - Depth: 512 entries"
puts "  - Custom controller with read/write pointers"
puts ""
puts "To open the project in GUI, run:"
puts "  vivado $project_dir/$project_name.xpr"

