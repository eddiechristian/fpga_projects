# Build script for existing Nexys Video FMC test project
# Opens existing project and runs synthesis/implementation

# Set the reference directory
set origin_dir [file dirname [info script]]

# Open the existing project
open_project ${origin_dir}/build/nexys_video_fmc_test.xpr

# Run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check for synthesis errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "ERROR: Synthesis failed"
}

puts "Synthesis completed successfully"

# Run implementation
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Check for implementation errors
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "ERROR: Implementation failed"
}

puts "Implementation completed successfully"

# Generate reports
open_run impl_1
report_utilization -file ${origin_dir}/build/utilization.rpt
report_timing_summary -file ${origin_dir}/build/timing_summary.rpt

puts "Build completed successfully!"
puts "Bitstream: ${origin_dir}/build/nexys_video_fmc_test.runs/impl_1/top_module.bit"
