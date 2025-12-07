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

# Add the FP/clk IPs
foreach ip_name {clk_wiz_0 floating_point_add floating_point_mult floating_point_div} {
    set ip_xci "$source_ip_dir/${ip_name}_1/$ip_name.xci"
    if {[file exists $ip_xci]} {
        puts "Adding $ip_name..."
        add_files $ip_xci
    } else {
        puts "WARNING: $ip_xci not found"
    }
}

puts "IP added (FP/clk reused from fp_ip_test)."

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
