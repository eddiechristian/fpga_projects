# Create Clocking Wizard IP to generate 200 MHz from 100 MHz input
# This provides 2x speedup for all floating-point operations

puts "Creating Clocking Wizard IP..."

# Create IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0

# Configure the Clocking Wizard
set_property -dict [list \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.RESET_PORT {reset} \
    CONFIG.USE_LOCKED_SIGNAL {true} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT2_DRIVES {BUFG} \
    CONFIG.CLKOUT3_DRIVES {BUFG} \
    CONFIG.CLKOUT4_DRIVES {BUFG} \
    CONFIG.CLKOUT5_DRIVES {BUFG} \
    CONFIG.CLKOUT6_DRIVES {BUFG} \
    CONFIG.CLKOUT7_DRIVES {BUFG} \
    CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {10.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {10.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {5.000} \
    CONFIG.CLKOUT1_JITTER {114.829} \
    CONFIG.CLKOUT1_PHASE_ERROR {98.575} \
] [get_ips clk_wiz_0]

# Generate the IP
generate_target {instantiation_template} [get_files clk_wiz_0.xci]
generate_target all [get_files clk_wiz_0.xci]
catch { config_ip_cache -export [get_ips -all clk_wiz_0] }
export_ip_user_files -of_objects [get_files clk_wiz_0.xci] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] clk_wiz_0.xci]

puts "Clocking Wizard IP created successfully!"
puts "Input clock: 100 MHz"
puts "Output clock: 200 MHz (2x speedup)"
puts ""
puts "Ports:"
puts "  clk_in1  - 100 MHz input clock"
puts "  clk_out1 - 200 MHz output clock"
puts "  reset    - Active high reset"
puts "  locked   - Output indicating PLL is locked"
