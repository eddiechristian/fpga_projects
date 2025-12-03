# Quick rebuild script - reuses existing project and IP cores
# Much faster for iterative HDL changes

set project_name "hdmi_video_nexys"
set project_dir "./build"

# Open existing project
open_project $project_dir/$project_name.xpr

# Update HDL source files (in case they changed)
update_compile_order -fileset sources_1

# Run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Run implementation
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Quick build complete!"
