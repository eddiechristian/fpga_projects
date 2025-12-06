# Wrapper script to create the CORDIC test Vivado project
# Preferred entrypoint; delegates to build.tcl which sets up IP and sources

# Allow running from repo root or inside cordic_test directory
set here [file normalize [file dirname [info script]]]
if {[file tail $here] ne "cordic_test"} {
    puts "Please run from the cordic_test directory."
}

# Source main build script
source [file join $here "build.tcl"]
