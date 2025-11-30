#!/usr/bin/env vivado -mode batch -source

# Ray Tracer FPGA Build Script
# Targets Nexys Video Board (Artix-7 XC7A200T)

set project_name "ray_tracer_fpga"
set project_dir "./build"
set src_dir "./src"

# Create project
create_project $project_name $project_dir -part xc7a200tsbg484-1 -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]

# Add HDL source files
add_files -fileset sources_1 [glob $src_dir/hdl/*.vhd]

# Add constraints
add_files -fileset constrs_1 $src_dir/constraints/constraints.xdc

# Set top module
set_property top top_module [current_fileset]

# Create IP directory
file mkdir $project_dir/ip

# Create Clock Wizard IP for generating VGA pixel clock (25.175 MHz) and ray tracer clock (50 MHz)
puts "Creating Clock Wizard IP..."
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir $project_dir/ip

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.175} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50.000} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.CLKIN1_JITTER_PS {100.0} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT2_DRIVES {BUFG} \
    CONFIG.CLKOUT1_REQUESTED_PHASE {0.000} \
    CONFIG.CLKOUT2_REQUESTED_PHASE {0.000} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]

# Create Floating Point IP cores for ray-sphere intersection math
# These will be used for advanced mathematical operations

# Floating Point Multipliers (4 instances for parallel operations)
puts "Creating Floating Point Multiplier IP cores..."

# Multiplier 0
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_mult -dir $project_dir/ip
set_property -dict [list \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.C_Mult_Usage {Max_Usage} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.C_Latency {8} \
    CONFIG.C_Rate {1} \
] [get_ips fp_mult]
generate_target all [get_ips fp_mult]

# Floating Point Adder (32-bit single precision)
puts "Creating Floating Point Adder IP..."
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_add -dir $project_dir/ip
set_property -dict [list \
    CONFIG.Operation_Type {Add_Subtract} \
    CONFIG.Add_Sub_Value {Both} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.C_Latency {11} \
    CONFIG.C_Rate {1} \
] [get_ips fp_add]
generate_target all [get_ips fp_add]

# Floating Point Square Root (for vector normalization)
puts "Creating Floating Point Square Root IP..."
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_sqrt -dir $project_dir/ip

set_property -dict [list \
    CONFIG.Operation_Type {Square_root} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.C_Latency {28} \
    CONFIG.C_Rate {1} \
] [get_ips fp_sqrt]
generate_target all [get_ips fp_sqrt]

# Floating Point Divider (for normalization and intersection)
puts "Creating Floating Point Divider IP..."
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_div -dir $project_dir/ip

set_property -dict [list \
    CONFIG.Operation_Type {Divide} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.C_Latency {28} \
    CONFIG.C_Rate {1} \
] [get_ips fp_div]
generate_target all [get_ips fp_div]

# Floating Point Compare (for discriminant test)
puts "Creating Floating Point Compare IP..."
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_compare -dir $project_dir/ip
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.Has_RESULT_TREADY {false} \
    CONFIG.C_Latency {2} \
    CONFIG.C_Rate {1} \
] [get_ips fp_compare]
generate_target all [get_ips fp_compare]

# Block RAM for framebuffer (if needed beyond inferred RAM)
# 640x480x12 bits = 307,200 pixels = 3,686,400 bits
puts "Creating Block Memory Generator IP..."
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name framebuffer_ram -dir $project_dir/ip

set_property -dict [list \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Write_Width_A {12} \
    CONFIG.Write_Depth_A {307200} \
    CONFIG.Read_Width_A {12} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Write_Width_B {12} \
    CONFIG.Read_Width_B {12} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
    CONFIG.Use_Byte_Write_Enable {false} \
    CONFIG.Byte_Size {9} \
    CONFIG.Assume_Synchronous_Clk {false} \
] [get_ips framebuffer_ram]

generate_target all [get_ips framebuffer_ram]

# Create and launch IP synthesis runs
puts "Creating IP synthesis runs..."
create_ip_run [get_ips clk_wiz_0]
create_ip_run [get_ips fp_mult]
create_ip_run [get_ips fp_add]
create_ip_run [get_ips fp_sqrt]
create_ip_run [get_ips fp_div]
create_ip_run [get_ips fp_compare]
create_ip_run [get_ips framebuffer_ram]

puts "Launching IP synthesis sequentially to avoid overwhelming system..."
puts "  Synthesizing clk_wiz_0..."
launch_runs clk_wiz_0_synth_1 -jobs 1
wait_on_run clk_wiz_0_synth_1

puts "  Synthesizing fp_mult..."
launch_runs fp_mult_synth_1 -jobs 1
wait_on_run fp_mult_synth_1

puts "  Synthesizing fp_add..."
launch_runs fp_add_synth_1 -jobs 1
wait_on_run fp_add_synth_1

puts "  Synthesizing fp_sqrt..."
launch_runs fp_sqrt_synth_1 -jobs 1
wait_on_run fp_sqrt_synth_1

puts "  Synthesizing fp_div..."
launch_runs fp_div_synth_1 -jobs 1
wait_on_run fp_div_synth_1

puts "  Synthesizing fp_compare..."
launch_runs fp_compare_synth_1 -jobs 1
wait_on_run fp_compare_synth_1

puts "  Synthesizing framebuffer_ram..."
launch_runs framebuffer_ram_synth_1 -jobs 1
wait_on_run framebuffer_ram_synth_1

puts "IP generation complete."

# Update compile order
update_compile_order -fileset sources_1

# Run synthesis
puts "Running synthesis..."
launch_runs synth_1 -jobs 2
wait_on_run synth_1

# Check for synthesis errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis complete."

# Run implementation
puts "Running implementation..."
launch_runs impl_1 -jobs 2
wait_on_run impl_1

# Check for implementation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

puts "Implementation complete."

# Generate bitstream
puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1

# Check for bitstream generation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Bitstream generation failed!"
    exit 1
}

puts "Bitstream generation complete."

# Generate timing and utilization reports
puts "Generating reports..."
open_run impl_1
report_timing_summary -file $project_dir/timing_summary.rpt
report_utilization -file $project_dir/utilization.rpt
report_power -file $project_dir/power.rpt

puts "Build complete! Bitstream location: $project_dir/${project_name}.runs/impl_1/top_module.bit"
puts "To program the FPGA, use:"
puts "  vivado -mode batch -source program.tcl"
puts "Or use Vivado Hardware Manager GUI."

close_project
