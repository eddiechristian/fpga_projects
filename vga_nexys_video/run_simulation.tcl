#!/usr/bin/tclsh

# VGA Testbench Simulation Script
# This script runs the VGA testbench showing all signals including pixel clock

set project_name "vga_nexys_video"
set project_dir "./build"

# Open the project
open_project ${project_dir}/${project_name}.xpr

# Set simulation top
set_property top top_module_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

# Set simulation runtime
set_property -name {xsim.simulate.runtime} -value {25ms} -objects [get_filesets sim_1]

# Launch simulation
launch_simulation

# Remove all existing waves to prevent duplicates
remove_wave -of [get_wave_config] [get_waves -of [get_wave_config] *]

# Add all signals to waveform
add_wave {{/top_module_tb/clk_100mhz}}
add_wave {{/top_module_tb/reset}}
add_wave {{/top_module_tb/pixel_clk}}
add_wave {{/top_module_tb/vga_hsync}}
add_wave {{/top_module_tb/vga_vsync}}
add_wave {{/top_module_tb/vga_r}}
add_wave {{/top_module_tb/vga_g}}
add_wave {{/top_module_tb/vga_b}}
add_wave {{/top_module_tb/h_pos}}
add_wave {{/top_module_tb/v_pos}}
add_wave {{/top_module_tb/h_front_porch}}
add_wave {{/top_module_tb/h_sync_region}}
add_wave {{/top_module_tb/h_back_porch}}
add_wave {{/top_module_tb/v_front_porch}}
add_wave {{/top_module_tb/v_sync_region}}
add_wave {{/top_module_tb/v_back_porch}}
add_wave {{/top_module_tb/h_sync_count}}
add_wave {{/top_module_tb/v_sync_count}}
add_wave {{/top_module_tb/pixel_count}}

# Run simulation
run 25ms

puts "=========================================="
puts "Simulation Complete!"
puts "Check the waveform viewer for all VGA signals"
puts "Key signals monitored:"
puts "  - clk_100mhz (system clock)"
puts "  - pixel_clk (25 MHz pixel clock)"
puts "  - vga_hsync/vsync (sync signals)"
puts "  - vga_r/g/b (color outputs)"
puts "  - h_pos/v_pos (position counters)"
puts "  - h_front_porch, h_sync_region, h_back_porch"
puts "  - v_front_porch, v_sync_region, v_back_porch"
puts "  - sync counters and pixel count"
puts "=========================================="
