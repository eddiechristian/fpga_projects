# Refresh script to update files in existing Vivado project
# Usage: vivado -mode batch -source refresh_files.tcl

set proj_name "crossbar"
set proj_dir "./build"
set log_dir "./logs"

# Create logs directory if it doesn't exist
file mkdir $log_dir

# Quick VHDL syntax check before opening project
puts "========================================"
puts "Checking VHDL syntax..."
puts "========================================"
set syntax_ok 1

# Check HDL source files
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] == 0} {
    puts "WARNING: No VHDL files found in ./src/hdl/"
} else {
    foreach vhdl_file $hdl_files {
        puts "Checking: $vhdl_file"
        if {[catch {read_vhdl -vhdl2008 $vhdl_file} err]} {
            puts "ERROR in $vhdl_file:"
            puts $err
            set syntax_ok 0
        }
    }
}

# Check simulation testbench files
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    foreach sim_file $sim_files {
        puts "Checking: $sim_file"
        if {[catch {read_vhdl -vhdl2008 $sim_file} err]} {
            puts "ERROR in $sim_file:"
            puts $err
            set syntax_ok 0
        }
    }
}

if {!$syntax_ok} {
    puts ""
    puts "========================================"
    puts "VHDL syntax errors detected!"
    puts "Fix syntax errors before refreshing."
    puts "========================================"
    exit 1
}

puts "All VHDL files passed syntax check."
puts "========================================"
puts ""

# Open existing project
puts "Opening project: $proj_name"
open_project $proj_dir/$proj_name.xpr

# Remove old wcfg files from sim_1
puts "Removing old waveform config files..."
set old_wcfg [get_files -of_objects [get_filesets sim_1] *.wcfg]
if {[llength $old_wcfg] > 0} {
    remove_files -fileset sim_1 $old_wcfg
}

# Remove old testbench files
puts "Removing old testbench files..."
set old_tb [get_files -of_objects [get_filesets sim_1] *_tb.vhd]
if {[llength $old_tb] > 0} {
    remove_files -fileset sim_1 $old_tb
}

# Remove old HDL files
puts "Removing old HDL source files..."
set old_hdl [get_files -of_objects [get_filesets sources_1] *.vhd]
if {[llength $old_hdl] > 0} {
    remove_files -fileset sources_1 $old_hdl
}

# Add HDL source files
puts "Adding HDL source files..."
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
    # Enable VHDL-2008 for all VHDL files
    set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets sources_1] *.vhd]
}

# Add simulation files
puts "Adding simulation testbench files..."
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 $sim_files
    set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets sim_1] *_tb.vhd]
}

# Add waveform configuration files
puts "Adding waveform configuration files..."
set wcfg_files [glob -nocomplain ./src/sim/*.wcfg]
if {[llength $wcfg_files] > 0} {
    add_files -fileset sim_1 $wcfg_files
}

# Update compile order
puts "Updating compile order..."
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "File refresh complete!"
puts "Files in simulation fileset:"
foreach file [get_files -of_objects [get_filesets sim_1]] {
    puts "  $file"
}

close_project
