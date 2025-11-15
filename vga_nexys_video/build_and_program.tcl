#!/usr/bin/tclsh

# Open the project
open_project ./build/vga_nexys_video.xpr

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "Synthesis completed"

# Run implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "Implementation completed"

# Check for errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed!"
}

puts "Bitstream generated successfully!"
puts "Bitstream location: ./build/vga_nexys_video.runs/impl_1/top_module.bit"
