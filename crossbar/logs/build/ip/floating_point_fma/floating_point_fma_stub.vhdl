-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
-- Date        : Sun Dec 14 21:17:45 2025
-- Host        : eddie-HP-Pavilion-Gaming-Laptop-16-a0xxx running 64-bit Ubuntu 24.04.3 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/eddie/fpga_projects/crossbar/logs/build/ip/floating_point_fma/floating_point_fma_stub.vhdl
-- Design      : floating_point_fma
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a200tsbg484-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity floating_point_fma is
  Port ( 
    aclk : in STD_LOGIC;
    s_axis_a_tvalid : in STD_LOGIC;
    s_axis_a_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_b_tvalid : in STD_LOGIC;
    s_axis_b_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_c_tvalid : in STD_LOGIC;
    s_axis_c_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s_axis_operation_tvalid : in STD_LOGIC;
    s_axis_operation_tdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    m_axis_result_tvalid : out STD_LOGIC;
    m_axis_result_tdata : out STD_LOGIC_VECTOR ( 31 downto 0 )
  );

  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of floating_point_fma : entity is "floating_point_fma,floating_point_v7_1_19,{}";
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of floating_point_fma : entity is "floating_point_fma,floating_point_v7_1_19,{x_ipProduct=Vivado 2024.2,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=floating_point,x_ipVersion=7.1,x_ipCoreRevision=19,x_ipLanguage=VHDL,x_ipSimLanguage=VHDL,C_XDEVICEFAMILY=artix7,C_PART=xc7a200tsbg484-1,C_HAS_ADD=0,C_HAS_SUBTRACT=0,C_HAS_MULTIPLY=0,C_HAS_DIVIDE=0,C_HAS_SQRT=0,C_HAS_COMPARE=0,C_HAS_FIX_TO_FLT=0,C_HAS_FLT_TO_FIX=0,C_HAS_FLT_TO_FLT=0,C_HAS_RECIP=0,C_HAS_RECIP_SQRT=0,C_HAS_ABSOLUTE=0,C_HAS_LOGARITHM=0,C_HAS_EXPONENTIAL=0,C_HAS_FMA=1,C_HAS_FMS=1,C_HAS_UNFUSED_MULTIPLY_ADD=0,C_HAS_UNFUSED_MULTIPLY_SUB=0,C_HAS_UNFUSED_MULTIPLY_ACCUMULATOR_A=0,C_HAS_UNFUSED_MULTIPLY_ACCUMULATOR_S=0,C_HAS_ACCUMULATOR_A=0,C_HAS_ACCUMULATOR_S=0,C_HAS_ACCUMULATOR_PRIMITIVE_A=0,C_HAS_ACCUMULATOR_PRIMITIVE_S=0,C_A_WIDTH=32,C_A_FRACTION_WIDTH=24,C_B_WIDTH=32,C_B_FRACTION_WIDTH=24,C_C_WIDTH=32,C_C_FRACTION_WIDTH=24,C_RESULT_WIDTH=32,C_RESULT_FRACTION_WIDTH=24,C_COMPARE_OPERATION=8,C_LATENCY=2,C_OPTIMIZATION=1,C_MULT_USAGE=2,C_BRAM_USAGE=0,C_RATE=1,C_ACCUM_INPUT_MSB=32,C_ACCUM_MSB=32,C_ACCUM_LSB=-31,C_HAS_UNDERFLOW=0,C_HAS_OVERFLOW=0,C_HAS_INVALID_OP=0,C_HAS_DIVIDE_BY_ZERO=0,C_HAS_ACCUM_OVERFLOW=0,C_HAS_ACCUM_INPUT_OVERFLOW=0,C_HAS_ACLKEN=0,C_HAS_ARESETN=0,C_THROTTLE_SCHEME=3,C_HAS_A_TUSER=0,C_HAS_A_TLAST=0,C_HAS_B=1,C_HAS_B_TUSER=0,C_HAS_B_TLAST=0,C_HAS_C=1,C_HAS_C_TUSER=0,C_HAS_C_TLAST=0,C_HAS_OPERATION=1,C_HAS_OPERATION_TUSER=0,C_HAS_OPERATION_TLAST=0,C_HAS_RESULT_TUSER=0,C_HAS_RESULT_TLAST=0,C_TLAST_RESOLUTION=0,C_A_TDATA_WIDTH=32,C_A_TUSER_WIDTH=1,C_B_TDATA_WIDTH=32,C_B_TUSER_WIDTH=1,C_C_TDATA_WIDTH=32,C_C_TUSER_WIDTH=1,C_OPERATION_TDATA_WIDTH=8,C_OPERATION_TUSER_WIDTH=1,C_RESULT_TDATA_WIDTH=32,C_RESULT_TUSER_WIDTH=1,C_FIXED_DATA_UNSIGNED=0}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of floating_point_fma : entity is "yes";
end floating_point_fma;

architecture stub of floating_point_fma is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "aclk,s_axis_a_tvalid,s_axis_a_tdata[31:0],s_axis_b_tvalid,s_axis_b_tdata[31:0],s_axis_c_tvalid,s_axis_c_tdata[31:0],s_axis_operation_tvalid,s_axis_operation_tdata[7:0],m_axis_result_tvalid,m_axis_result_tdata[31:0]";
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of aclk : signal is "xilinx.com:signal:clock:1.0 aclk_intf CLK";
  attribute X_INTERFACE_MODE : string;
  attribute X_INTERFACE_MODE of aclk : signal is "slave";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of aclk : signal is "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF S_AXIS_OPERATION:M_AXIS_RESULT:S_AXIS_C:S_AXIS_B:S_AXIS_A, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 10000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axis_a_tvalid : signal is "xilinx.com:interface:axis:1.0 S_AXIS_A TVALID";
  attribute X_INTERFACE_MODE of s_axis_a_tvalid : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axis_a_tvalid : signal is "XIL_INTERFACENAME S_AXIS_A, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axis_a_tdata : signal is "xilinx.com:interface:axis:1.0 S_AXIS_A TDATA";
  attribute X_INTERFACE_INFO of s_axis_b_tvalid : signal is "xilinx.com:interface:axis:1.0 S_AXIS_B TVALID";
  attribute X_INTERFACE_MODE of s_axis_b_tvalid : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axis_b_tvalid : signal is "XIL_INTERFACENAME S_AXIS_B, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axis_b_tdata : signal is "xilinx.com:interface:axis:1.0 S_AXIS_B TDATA";
  attribute X_INTERFACE_INFO of s_axis_c_tvalid : signal is "xilinx.com:interface:axis:1.0 S_AXIS_C TVALID";
  attribute X_INTERFACE_MODE of s_axis_c_tvalid : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axis_c_tvalid : signal is "XIL_INTERFACENAME S_AXIS_C, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axis_c_tdata : signal is "xilinx.com:interface:axis:1.0 S_AXIS_C TDATA";
  attribute X_INTERFACE_INFO of s_axis_operation_tvalid : signal is "xilinx.com:interface:axis:1.0 S_AXIS_OPERATION TVALID";
  attribute X_INTERFACE_MODE of s_axis_operation_tvalid : signal is "slave";
  attribute X_INTERFACE_PARAMETER of s_axis_operation_tvalid : signal is "XIL_INTERFACENAME S_AXIS_OPERATION, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s_axis_operation_tdata : signal is "xilinx.com:interface:axis:1.0 S_AXIS_OPERATION TDATA";
  attribute X_INTERFACE_INFO of m_axis_result_tvalid : signal is "xilinx.com:interface:axis:1.0 M_AXIS_RESULT TVALID";
  attribute X_INTERFACE_MODE of m_axis_result_tvalid : signal is "master";
  attribute X_INTERFACE_PARAMETER of m_axis_result_tvalid : signal is "XIL_INTERFACENAME M_AXIS_RESULT, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of m_axis_result_tdata : signal is "xilinx.com:interface:axis:1.0 M_AXIS_RESULT TDATA";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of stub : architecture is "floating_point_v7_1_19,Vivado 2024.2";
begin
end;
