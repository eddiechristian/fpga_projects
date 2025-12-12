# HDL Syntax Checker
# Checks syntax by reading Vivado compile logs

puts "========================================="
puts "HDL Syntax Checker"
puts "========================================="

# Reset filesets first
reset_run synth_1

puts "Analyzing HDL files...\n"

# Try to compile sources
if {[catch {update_compile_order -fileset sources_1} result]} {
    puts "ERROR: Failed to update compile order"
    puts "$result"
    exit 1
}

if {[catch {update_compile_order -fileset sim_1} result]} {
    puts "ERROR: Failed to update simulation compile order" 
    puts "$result"
    exit 1
}

puts "\nCompiling sources..."
if {[catch {launch_runs synth_1 -jobs 1} result]} {
    puts "ERROR: Synthesis launch failed"
    puts "$result"
    exit 1
}

wait_on_run synth_1

set status [get_property STATUS [get_runs synth_1]]
set progress [get_property PROGRESS [get_runs synth_1]]

puts "\n========================================="
puts "Syntax Check Result"
puts "========================================="
puts "Status:   $status"
puts "Progress: $progress"
puts "========================================="

if {[string match "*Error*" $status] || [string match "*Failed*" $status]} {
    puts "\nERROR: Syntax errors detected!"
    puts "Check the Messages tab in Vivado GUI for details."
    exit 1
} else {
    puts "\nSUCCESS: All files compiled successfully!"
    exit 0
}
