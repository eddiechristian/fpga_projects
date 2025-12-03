# Create Floating Point IP Cores for Ray Tracer
# Run this once to generate the IP cores

set project_name "hdmi_video_nexys"
set project_dir "./build"

# Open existing project
open_project $project_dir/$project_name.xpr

# Create FP Multiplier
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_mult
set_property -dict [list \
    CONFIG.Operation_Type {Multiply} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.C_Mult_Usage {Max_Usage} \
    CONFIG.C_Latency {8} \
    CONFIG.C_Rate {1} \
    CONFIG.Has_ARESETn {false} \
] [get_ips fp_mult]

# Create FP Adder/Subtractor
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_add
set_property -dict [list \
    CONFIG.Operation_Type {Add_Subtract} \
    CONFIG.Add_Sub_Value {Both} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.C_Latency {11} \
    CONFIG.C_Rate {1} \
    CONFIG.Has_ARESETn {false} \
] [get_ips fp_add]

# Create FP Square Root  
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_sqrt
set_property -dict [list \
    CONFIG.Operation_Type {Square_root} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.C_Latency {28} \
    CONFIG.C_Rate {1} \
    CONFIG.Has_ARESETn {false} \
] [get_ips fp_sqrt]

# Create FP Divider
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_div
set_property -dict [list \
    CONFIG.Operation_Type {Divide} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.Result_Precision_Type {Single} \
    CONFIG.C_Result_Exponent_Width {8} \
    CONFIG.C_Result_Fraction_Width {24} \
    CONFIG.C_Latency {28} \
    CONFIG.C_Rate {1} \
    CONFIG.Has_ARESETn {false} \
] [get_ips fp_div]

# Create FP Compare
create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name fp_compare
set_property -dict [list \
    CONFIG.Operation_Type {Compare} \
    CONFIG.A_Precision_Type {Single} \
    CONFIG.C_A_Exponent_Width {8} \
    CONFIG.C_A_Fraction_Width {24} \
    CONFIG.C_Latency {2} \
    CONFIG.C_Rate {1} \
    CONFIG.Has_ARESETn {false} \
] [get_ips fp_compare]

# Generate all IP cores
generate_target all [get_ips fp_mult]
generate_target all [get_ips fp_add]
generate_target all [get_ips fp_sqrt]
generate_target all [get_ips fp_div]
generate_target all [get_ips fp_compare]

puts "FP IP cores created and generated successfully!"
close_project
