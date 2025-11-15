# Program FPGA Script
# This script programs an existing bitstream to the FPGA
# Usage: vivado -mode tcl -source program.tcl

set project_name "nexys_oled_vhdl"
set script_dir [file normalize [file dirname [info script]]]
set bitstream_file "$script_dir/build/$project_name.runs/impl_1/oled_master.bit"

puts "========================================"
puts "Program FPGA"
puts "========================================"

# Check if bitstream exists
if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream not found at $bitstream_file"
    puts "Please run build_and_program.tcl first to generate bitstream"
    exit 1
}

puts "Bitstream: $bitstream_file"
puts ""

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
puts "========================================"

close_hw_manager
