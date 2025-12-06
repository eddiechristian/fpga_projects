# Synthesis-only build for low-memory systems
open_project ./build/trs_test.xpr

# Make sure any new HDL files are added
set hdl_files [glob -nocomplain ./src/hdl/*.vhd]
if {[llength $hdl_files] > 0} {
    add_files -fileset sources_1 $hdl_files
}
update_compile_order -fileset sources_1

puts "Running synthesis only (skipping implementation)..."

# Force reset and clean
catch {reset_run synth_1 -prev_step}
reset_run synth_1
launch_runs synth_1 -jobs 1
wait_on_run synth_1

puts "Synthesis complete - ready for post-synthesis simulation"
puts "Skipped implementation to save memory"

close_project
exit
