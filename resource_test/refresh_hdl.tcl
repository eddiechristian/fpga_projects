# Refresh HDL and simulation files
# Run this in Vivado TCL console after modifying HDL files

puts "Refreshing HDL and simulation files..."

# Remove old HDL files
set hdl_files [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == VHDL}]
if {[llength $hdl_files] > 0} {
    puts "Removing old HDL files..."
    remove_files -fileset sources_1 $hdl_files
}

# Remove old simulation files
set sim_files [get_files -of_objects [get_filesets sim_1] -filter {FILE_TYPE == VHDL}]
if {[llength $sim_files] > 0} {
    puts "Removing old simulation files..."
    remove_files -fileset sim_1 $sim_files
}

# Add HDL source files
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    puts "Adding HDL files:"
    foreach file $hdl_files {
        puts "  $file"
    }
    add_files -fileset sources_1 $hdl_files
}

# Add simulation files
set sim_files [glob -nocomplain ./src/sim/*_tb.vhd]
if {[llength $sim_files] > 0} {
    puts "Adding simulation files:"
    foreach file $sim_files {
        puts "  $file"
    }
    add_files -fileset sim_1 $sim_files
}

# Add waveform configuration files
set wcfg_files [glob -nocomplain ./src/sim/*.wcfg]
if {[llength $wcfg_files] > 0} {
    puts "Adding waveform configs:"
    foreach file $wcfg_files {
        puts "  $file"
    }
    add_files -fileset sim_1 $wcfg_files
}

# Update compile order
puts "Updating compile order..."
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "HDL files refreshed successfully!"
puts "Note: You may need to relaunch simulation for changes to take effect."
