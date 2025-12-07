open_project /home/eddie/fpga_projects/trs_test/build/trs_test_proj.xpr

# Launch post-synthesis functional simulation
launch_simulation -mode post-synthesis -type functional

# Run simulation for sufficient time
run 10 ms

# Close simulation
close_sim

# Close project
close_project
