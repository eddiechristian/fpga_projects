# TRS Test Project Build Script
set project_name "trs_test"
set project_dir "./build"
set part_name "xc7a200tsbg484-1"

# Create project
create_project $project_name $project_dir -part $part_name -force

# Set project properties
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# Add IP from fp_ip_test project (reuse existing generated FP/clk IPs)
set source_ip_dir "../fp_ip_test/build/ip"

puts "Adding FP/clk IP from fp_ip_test project..."

# Add only the FP/clk IPs; exclude cordic_sincos (we will create a local floating-point CORDIC)
foreach ip_name {clk_wiz_0 floating_point_add floating_point_mult floating_point_div} {
    set ip_xci "$source_ip_dir/${ip_name}_1/$ip_name.xci"
    if {[file exists $ip_xci]} {
        puts "Adding $ip_name..."
        add_files $ip_xci
    } else {
        puts "WARNING: $ip_xci not found"
    }
}

# Create local fixed-point CORDIC IP (Q1.31 sin/cos) and float-to-fixed converters
set ip_dir "$project_dir/$project_name.srcs/sources_1/ip"
file mkdir $ip_dir

# CORDIC in fixed-point mode (Q1.31)
create_ip -name cordic -vendor xilinx.com -library ip -version 6.0 -module_name cordic_sincos -dir $ip_dir
set_property -dict [list \
    CONFIG.Functional_Selection {Sin_and_Cos} \
    CONFIG.Architectural_Configuration {Word_Serial} \
    CONFIG.Pipelining_Mode {Optimal} \
    CONFIG.Data_Format {SignedFraction} \
    CONFIG.Phase_Format {Radians} \
    CONFIG.Input_Width {32} \
    CONFIG.Output_Width {32} \
    CONFIG.Round_Mode {Truncate} \
    CONFIG.Compensation_Scaling {Divide_by_K} \
] [get_ips cordic_sincos]

# Float-to-fixed converter (IEEE-754 single to Q1.31)
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name float_to_fixed -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Float_to_fixed} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.Result_Precision_Type {Custom} \
    CONFIG.C_Result_Exponent_Width {1} \
    CONFIG.C_Result_Fraction_Width {31} \
    CONFIG.C_Mult_Usage {No_Usage} \
] [get_ips float_to_fixed]

# Fixed-to-float converter (Q1.31 to IEEE-754 single)
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fixed_to_float -dir $ip_dir
set_property -dict [list \
    CONFIG.Operation_Type {Fixed_to_float} \
    CONFIG.A_Precision_Type {Custom} \
    CONFIG.C_A_Exponent_Width {1} \
    CONFIG.C_A_Fraction_Width {31} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Mult_Usage {No_Usage} \
] [get_ips fixed_to_float]

puts "IP added (FP/clk reused, local fixed-point CORDIC + converters created)."

# Add HDL source files
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
}

# Add simulation files
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
}

# Set top module
set_property top top_module [current_fileset]
set_property top top_module_tb [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Running synthesis..."

# Run synthesis
launch_runs synth_1 -jobs 1
wait_on_run synth_1

puts "Synthesis complete. Generating post-synthesis simulation files..."

# Set up post-synthesis simulation
set_property -name {xsim.simulate.runtime} -value {2000ns} -objects [get_filesets sim_1]

puts "Synthesis complete - skipping implementation to save memory"
puts "Project location: $project_dir/$project_name.xpr"
puts "Ready for post-synthesis simulation"
