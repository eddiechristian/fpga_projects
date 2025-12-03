# Build script for HDMI test pattern
set project_name "hdmi_test_pattern"
set part "xc7a200tsbg484-1"

# Create project
create_project $project_name ./build/$project_name -part $part -force

# Add source files
add_files -fileset sources_1 {
    ./src/hdl/top_module.vhd
    ./src/hdl/rgb2tmds.vhd
}

# Add constraints
add_files -fileset constrs_1 ./src/constraints/constraints.xdc

# Set top module
set_property top top_module [current_fileset]

# Create clock wizard IP for simple test (25 MHz pixel clock, 125 MHz TMDS clock)
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125.000} \
    CONFIG.USE_RESET {false} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.RESET_PORT {reset} \
] [get_ips clk_wiz_0]

# Generate IP
generate_target all [get_ips]
create_ip_run [get_ips]
launch_runs -jobs 4 [get_runs clk_wiz_0_synth_1]
wait_on_runs [get_runs clk_wiz_0_synth_1]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_runs synth_1

# Run implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_runs impl_1

# Generate reports
open_run impl_1
report_timing_summary -file ./build/timing_summary.rpt
report_utilization -file ./build/utilization.rpt
report_power -file ./build/power.rpt

puts "Build complete! Bitstream: ./build/$project_name.runs/impl_1/top_module.bit"
