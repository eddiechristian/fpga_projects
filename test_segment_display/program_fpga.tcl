# Program FPGA Script
# This script programs the Nexys Video board with the generated bitstream

set bitstream_file "build/test_segment_display.runs/impl_1/top_module.bit"

# Check if bitstream exists
if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream file not found: $bitstream_file"
    exit 1
}

puts "========================================="
puts "Programming Nexys Video FPGA"
puts "========================================="
puts "Bitstream: $bitstream_file"
puts ""

# Open hardware manager
open_hw_manager

# Connect to hardware server
puts "Connecting to hardware server..."
connect_hw_server -allow_non_jtag

# Open target
puts "Opening hardware target..."
open_hw_target

# Get the device
set device [lindex [get_hw_devices] 0]
puts "Found device: $device"

# Set programming file
current_hw_device $device
set_property PROGRAM.FILE $bitstream_file $device

# Program the device
puts ""
puts "Programming device..."
program_hw_devices $device

# Verify
puts ""
if {[get_property PROGRAM.DONE $device]} {
    puts "========================================="
    puts "SUCCESS: FPGA programmed successfully!"
    puts "========================================="
} else {
    puts "========================================="
    puts "ERROR: Programming failed!"
    puts "========================================="
    exit 1
}

# Close hardware manager
close_hw_target
disconnect_hw_server
close_hw_manager

puts ""
puts "The FPGA is now running your design."
puts "Use SW[7:0] switches to select ASCII characters."
puts "The character will display on the 14-segment display."
