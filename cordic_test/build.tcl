# CORDIC Test Project Build Script
set project_name "cordic_test"
set project_dir "./build"
set part_name "xc7a200tsbg484-1"

# Create project
create_project $project_name $project_dir -part $part_name -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Create IP directory
set ip_dir "$project_dir/$project_name.srcs/sources_1/ip"
file mkdir $ip_dir

puts "Creating CORDIC IP for sin/cos computation..."

# Create CORDIC IP - Using floating-point format
# Input: angle in radians (IEEE-754 single precision)
# Output: sin and cos (IEEE-754 single precision) with automatic compensation
create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name cordic_sincos -dir $ip_dir
set_property CONFIG.Functional_Selection {Sin_and_Cos} [get_ips cordic_sincos]
set_property CONFIG.Architectural_Configuration {Parallel} [get_ips cordic_sincos]
set_property CONFIG.Pipelining_Mode {Maximum} [get_ips cordic_sincos]
set_property CONFIG.Data_Format {FloatingPoint} [get_ips cordic_sincos]
set_property CONFIG.Phase_Format {Radians} [get_ips cordic_sincos]
set_property CONFIG.Flow_Control {NonBlocking} [get_ips cordic_sincos]
set_property CONFIG.ARESETN {false} [get_ips cordic_sincos]

puts "CORDIC IP created with Q1.31 format"
puts "  - Input: angle/π in Q1.31 signed fraction"
puts "  - Output: sin and cos in Q1.31 signed fraction (-1.0 to +1.0)"
puts ""

# Check if we can reuse clock wizard from another project
set source_clk_ip "../fp_ip_test/build/ip/clk_wiz_0_1/clk_wiz_0.xci"
if {[file exists $source_clk_ip]} {
    puts "Reusing clock wizard IP from fp_ip_test..."
    add_files $source_clk_ip
} else {
    puts "Creating new clock wizard IP..."
    create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir $ip_dir
    set_property -dict [list \
        CONFIG.PRIM_IN_FREQ {100.000} \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
        CONFIG.USE_RESET {true} \
        CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    ] [get_ips clk_wiz_0]
}

puts "IP configuration complete"

# Add HDL source files
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
    puts "Added [llength $hdl_files] HDL source files"
}

# Add simulation files
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
    puts "Added [llength $sim_files] simulation files"
}

# Set top module
set_property top top_module [current_fileset]
set_property top top_module_tb [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "Running synthesis..."
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Synthesis complete!"
puts "Project location: $project_dir/$project_name.xpr"
puts ""
puts "To run simulation:"
puts "  1. Open project in Vivado GUI"
puts "  2. Run behavioral simulation"
puts "  3. Check waveform for sin_out and cos_out signals"
puts "  4. Compare against expected values in testbench"
puts ""
puts "Key signals to observe:"
puts "  - angle_index: which test angle (0-6)"
puts "  - cordic_phase: input angle in Q1.31 format"
puts "  - sin_out: sine result in Q1.31 format"
puts "  - cos_out: cosine result in Q1.31 format"
puts ""
puts "Q1.31 Format Notes:"
puts "  - Values range from -1.0 (0x80000000) to +1.0 (0x7FFFFFFF)"
puts "  - 0.5 = 0x40000000"
puts "  - 0.707 ≈ 0x5A827999"
puts "  - 0.866 ≈ 0x6ED9EBA1"
