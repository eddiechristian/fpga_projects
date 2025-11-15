# Build and Program Script for Nexys Video OLED Controller
# This script builds the bitstream and programs the FPGA board
# Usage: vivado -mode tcl -source build_and_program.tcl

set project_name "nexys_oled_vhdl"
set script_dir [file normalize [file dirname [info script]]]
set project_dir "$script_dir/build"
set project_file "$project_dir/$project_name.xpr"

puts "========================================"
puts "Build and Program Script"
puts "========================================"
puts "Project: $project_name"
puts ""

# Check if project exists
if {![file exists $project_file]} {
    puts "ERROR: Project not found at $project_file"
    puts "Please run create_project.tcl first"
    exit 1
}

# Open project
puts "Opening project..."
open_project $project_file

#=============================================================================
# Build bitstream
#=============================================================================
puts "\n========================================"
puts "Building Bitstream"
puts "========================================"

# Reset and launch synthesis
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed"
    exit 1
}
puts "Synthesis complete!"

# Launch implementation and bitstream generation
puts "\nRunning implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed"
    exit 1
}
puts "Implementation complete!"

# Get bitstream location
set bitstream_file "[get_property DIRECTORY [get_runs impl_1]]/oled_master.bit"
puts "\nBitstream generated: $bitstream_file"

#=============================================================================
# Program FPGA
#=============================================================================
puts "\n========================================"
puts "Programming FPGA"
puts "========================================"

# Open hardware manager
open_hw_manager
puts "Connecting to hardware server..."
connect_hw_server

# Get available targets
set targets [get_hw_targets]
if {[llength $targets] == 0} {
    puts "ERROR: No hardware targets found"
    puts "Please check:"
    puts "  1. FPGA board is powered on"
    puts "  2. USB cable is connected"
    puts "  3. Board drivers are installed"
    close_hw_manager
    exit 1
}

puts "Available targets: $targets"

# Try each target until we find a device
set device_found 0
foreach target $targets {
    puts "Trying target: $target"
    if {[catch {open_hw_target $target} result]} {
        puts "  Could not open target: $result"
        continue
    }
    
    set devices [get_hw_devices]
    if {[llength $devices] > 0} {
        set device [lindex $devices 0]
        puts "  Found device: $device"
        set device_found 1
        break
    } else {
        puts "  No devices on this target"
        close_hw_target
    }
}

if {!$device_found} {
    puts "\nERROR: No FPGA device found on any target"
    puts "Please check board connections and power"
    close_hw_manager
    exit 1
}

# Program the device
puts "\nProgramming device $device..."
current_hw_device $device
set_property PROGRAM.FILE $bitstream_file $device
program_hw_devices $device
refresh_hw_device $device

puts "\n========================================"
puts "Programming Complete!"
puts "========================================"
puts "The FPGA has been programmed successfully"
puts "Bitstream: $bitstream_file"
puts "========================================"

close_hw_manager

# Exit Vivado
exit
