# Open the project
open_project build/bram_fifo.xpr

# Launch simulation
launch_simulation

# Run simulation for specified time
run 100 us

# Report any assertion failures
puts "\n========================================="
puts "Simulation completed"
puts "=========================================\n"

# Close simulation
close_sim -force

# Exit
exit

