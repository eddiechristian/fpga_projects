# Post-synthesis simulation script
open_project ./build/trs_test.xpr

# Open synthesized design
open_run synth_1 -name synth_1

# Launch post-synthesis simulation in GUI
launch_simulation -mode post-synthesis -type timing

# Load waveform config if it exists
if {[file exists top_module_tb_post_synth.wcfg]} {
    open_wave_config top_module_tb_post_synth.wcfg
}

# Run simulation for 2000ns
run 2000ns
