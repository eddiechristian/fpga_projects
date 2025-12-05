library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

-- Hardware Vec3 scalar multiplication: result = v * scalar
-- Uses 3 floating-point multipliers in parallel
-- 
-- Performance:
--   Latency: 8 clock cycles
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 3x FP_MULT cores
entity vec3_scale_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        v         : in  Vec3;
        scalar    : in  fp32;
        result    : out Vec3;
        valid_out : out std_logic
    );
end entity vec3_scale_hw;

architecture behavioral of vec3_scale_hw is
    
    component floating_point_mult
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_b_tvalid         : in  STD_LOGIC;
            s_axis_b_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    signal valid_x, valid_y, valid_z : std_logic;
    
begin
    
    -- Multiply X component by scalar
    mult_x : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => v.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => scalar,
            m_axis_result_tvalid => valid_x,
            m_axis_result_tdata  => result.x
        );
    
    -- Multiply Y component by scalar
    mult_y : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => v.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => scalar,
            m_axis_result_tvalid => valid_y,
            m_axis_result_tdata  => result.y
        );
    
    -- Multiply Z component by scalar
    mult_z : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => v.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => scalar,
            m_axis_result_tvalid => valid_z,
            m_axis_result_tdata  => result.z
        );
    
    -- All three multiplications complete at the same time
    valid_out <= valid_x and valid_y and valid_z;
    
end architecture behavioral;
