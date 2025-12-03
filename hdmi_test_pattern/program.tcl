open_hw_manager
connect_hw_server
open_hw_target
set_property PROGRAM.FILE {build/hdmi_test_pattern.runs/impl_1/top_module.bit} [get_hw_devices xc7a200t_0]
program_hw_devices [get_hw_devices xc7a200t_0]
close_hw_target
disconnect_hw_server
close_hw_manager
