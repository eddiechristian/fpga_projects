# Quick synthesis test script - no simulation
# Opens existing project and runs synthesis only

set project_name "fp_ip_test"
set project_dir "./build"

# Open existing project
open_project $project_dir/$project_name.xpr

# Update compile order
update_compile_order -fileset sources_1

puts "Running synthesis..."

# Run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 1
wait_on_run synth_1

# Check synthesis status
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

if {$synth_status == "synth_design Complete!"} {
    puts "Synthesis completed successfully!"
    
    # Open synthesis run and generate reports
    open_run synth_1
    
    report_utilization -file $project_dir/synth_utilization.rpt
    report_timing_summary -max_paths 10 -file $project_dir/synth_timing.rpt
    
    puts "Reports generated:"
    puts "  Utilization: $project_dir/synth_utilization.rpt"
    puts "  Timing:      $project_dir/synth_timing.rpt"
} else {
    puts "ERROR: Synthesis failed!"
    exit 1
}

puts "Done!"
