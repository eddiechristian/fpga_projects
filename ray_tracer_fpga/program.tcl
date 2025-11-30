#!/usr/bin/env vivado -mode batch -source

# Program Nexys Video FPGA with Ray Tracer bitstream

puts "Opening Hardware Manager..."
open_hw_manager

puts "Connecting to hardware server..."
connect_hw_server

puts "Opening hardware target..."
open_hw_target

puts "Programming FPGA device..."
set_property PROGRAM.FILE {build/ray_tracer_fpga.runs/impl_1/top_module.bit} [get_hw_devices xc7a200t_0]
current_hw_device [get_hw_devices xc7a200t_0]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7a200t_0] 0]
program_hw_devices [get_hw_devices xc7a200t_0]

puts "Programming complete!"
puts "The ray tracer should now be running on the FPGA."
puts "Check your VGA display for output."

close_hw_target
disconnect_hw_server
close_hw_manager
