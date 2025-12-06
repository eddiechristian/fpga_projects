# Timing Constraints for fp_ip_test
# ==================================

# Input clock constraint (100 MHz from board)
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

# Input delay constraint for reset (relative to input clock)
set_input_delay -clock [get_clocks sys_clk_pin] -min 0.000 [get_ports reset]
set_input_delay -clock [get_clocks sys_clk_pin] -max 2.000 [get_ports reset]

# Output delay constraint for LED (relative to output clock)
# LED is driven by internal 150 MHz clock
set_output_delay -clock [get_clocks clk_out1_clk_wiz_0] -min -1.000 [get_ports led]
set_output_delay -clock [get_clocks clk_out1_clk_wiz_0] -max 2.000 [get_ports led]

# Mark reset as asynchronous (false path) if it's truly async
set_false_path -from [get_ports reset]
