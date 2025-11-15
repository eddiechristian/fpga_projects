# Vivado Project Creation Script for OLED Controller
# This script creates the complete project with all source files and IP cores
# Usage: vivado -mode batch -source create_project.tcl

# Set project name and directory
set project_name "nexys_oled_vhdl"
set script_dir [file normalize [file dirname [info script]]]
set project_dir "$script_dir/build"

# Set the FPGA part number (Nexys Video board)
set part_number "xc7a200tsbg484-1"

puts "========================================"
puts "Creating Nexys Video OLED VHDL Project"
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
    src/hdl/spi_ctrl.vhd
    src/hdl/delay_ms.vhd
    src/hdl/oled_ctrl.vhd
    src/hdl/uart_rx.vhd
    src/hdl/text_buffer.vhd
    src/hdl/oled_master.vhd
}

# Set top module
set_property top oled_master [current_fileset]

puts "VHDL sources added!"

#=============================================================================
# Add constraints
#=============================================================================
puts "Adding constraints..."

add_files -fileset constrs_1 -norecurse {
    src/constraints/nexys_video.xdc
}

puts "Constraints added!"

#=============================================================================
# Create Block RAM IP cores
#=============================================================================
puts "\nCreating Block RAM IP cores..."

# 1. Character Library ROM
puts "  Creating charLib..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
    -module_name charLib

set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Write_Width_A {8} \
    CONFIG.Write_Depth_A {1024} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File "$script_dir/src/data/characterLib.coe" \
    CONFIG.Fill_Remaining_Memory_Locations {false} \
    CONFIG.Port_A_Write_Rate {0} \
] [get_ips charLib]

# 2. Pixel Buffer RAM
puts "  Creating pixel_buffer..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
    -module_name pixel_buffer

set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Write_Width_A {8} \
    CONFIG.Write_Depth_A {512} \
    CONFIG.Operating_Mode_A {NO_CHANGE} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Write_Width_B {8} \
    CONFIG.Read_Width_B {8} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Fill_Remaining_Memory_Locations {true} \
    CONFIG.Remaining_Memory_Locations {0} \
    CONFIG.Port_B_Clock {100} \
    CONFIG.Port_B_Enable_Rate {100} \
] [get_ips pixel_buffer]

# 3. Initialization Sequence ROM
puts "  Creating init_sequence_rom..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 \
    -module_name init_sequence_rom

set_property -dict [list \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Write_Width_A {16} \
    CONFIG.Write_Depth_A {16} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File "$script_dir/src/data/init_sequence.coe" \
    CONFIG.Fill_Remaining_Memory_Locations {true} \
    CONFIG.Remaining_Memory_Locations {0} \
    CONFIG.Port_A_Write_Rate {0} \
] [get_ips init_sequence_rom]

puts "Block RAM IP cores created!"

#=============================================================================
# Generate IP outputs
#=============================================================================
puts "\nGenerating IP outputs..."

generate_target all [get_ips]

puts "IP outputs generated!"

#=============================================================================
# Create synthesis runs for IPs
#=============================================================================
puts "\nCreating IP synthesis runs..."

foreach ip [get_ips] {
    create_ip_run $ip
}

puts "IP runs created!"

#=============================================================================
# Update compile order
#=============================================================================
update_compile_order -fileset sources_1

#=============================================================================
# Project Summary
#=============================================================================
puts "\n========================================"
puts "Project Creation Complete!"
puts "========================================"
puts "Project: $project_name"
puts "Location: $project_dir"
puts "\nNext steps:"
puts "1. Synthesize IPs (optional, will run automatically):"
puts "   launch_runs -jobs 4 charLib_synth_1 pixel_buffer_synth_1 init_sequence_rom_synth_1"
puts "2. Build bitstream:"
puts "   launch_runs impl_1 -to_step write_bitstream -jobs 4"
puts "3. Or open in GUI:"
puts "   vivado $project_dir/$project_name.xpr"
puts "========================================"
