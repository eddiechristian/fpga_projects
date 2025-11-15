#!/usr/bin/tclsh

# Open hardware manager
open_hw_manager
connect_hw_server -allow_non_jtag

# Open target
open_hw_target

# Program device
set device [lindex [get_hw_devices] 0]
current_hw_device $device
refresh_hw_device $device
set_property PROGRAM.FILE {./build/vga_nexys_video.runs/impl_1/top_module.bit} $device
program_hw_devices $device

puts "FPGA programmed successfully!"

# Close hardware manager
close_hw_target
disconnect_hw_server
close_hw_manager
