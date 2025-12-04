library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.vec3_pkg.all;

-- Hardware Vec3 magnitude (length): result = sqrt(v.x² + v.y² + v.z²)
-- Implements the norm() function from qbVector.h
-- 
-- Uses 3 floating-point multipliers, 2 floating-point adders, and 1 square root
-- 
-- Pipeline stages:
--   Stage 1: 3 parallel squaring operations (v.x², v.y², v.z²) - 8 cycles
--   Stage 2: Add x² + y² - 11 cycles
--   Stage 3: Add sum + z² - 11 cycles  
--   Stage 4: Square root of sum - 28 cycles
-- 
-- Performance:
--   Total Latency: 58 clock cycles (8 + 11 + 11 + 28)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 3x FP_MULT + 2x FP_ADD + 1x FP_SQRT cores
--   
-- Note: This is used by normalize operation and distance calculations
entity vec3_magnitude_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        v         : in  Vec3;
        result    : out fp32;
        valid_out : out std_logic
    );
end entity vec3_magnitude_hw;

architecture behavioral of vec3_magnitude_hw is
    
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
    
    component floating_point_add
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
    
    component floating_point_sqrt
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    -- Stage 1: Squared values
    signal x_squared, y_squared, z_squared : fp32;
    signal x_sq_valid, y_sq_valid, z_sq_valid : std_logic;
    
    -- Stage 2: First addition (x² + y²)
    signal sum_xy : fp32;
    signal sum_xy_valid : std_logic;
    
    -- Stage 3: Second addition (x² + y² + z²)
    signal sum_xyz : fp32;
    signal sum_xyz_valid : std_logic;
    
    -- Stage 4: Square root result
    signal sqrt_valid : std_logic;
    
begin
    
    -- Stage 1: Square each component in parallel
    square_x : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => v.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => v.x,
            m_axis_result_tvalid => x_sq_valid,
            m_axis_result_tdata  => x_squared
        );
    
    square_y : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => v.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => v.y,
            m_axis_result_tvalid => y_sq_valid,
            m_axis_result_tdata  => y_squared
        );
    
    square_z : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => v.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => v.z,
            m_axis_result_tvalid => z_sq_valid,
            m_axis_result_tdata  => z_squared
        );
    
    -- Stage 2: Add first two squared values
    add_xy : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => x_sq_valid,
            s_axis_a_tdata       => x_squared,
            s_axis_b_tvalid      => y_sq_valid,
            s_axis_b_tdata       => y_squared,
            m_axis_result_tvalid => sum_xy_valid,
            m_axis_result_tdata  => sum_xy
        );
    
    -- Stage 3: Add third squared value
    add_z : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => sum_xy_valid,
            s_axis_a_tdata       => sum_xy,
            s_axis_b_tvalid      => z_sq_valid,
            s_axis_b_tdata       => z_squared,
            m_axis_result_tvalid => sum_xyz_valid,
            m_axis_result_tdata  => sum_xyz
        );
    
    -- Stage 4: Take square root
    sqrt_inst : floating_point_sqrt
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => sum_xyz_valid,
            s_axis_a_tdata       => sum_xyz,
            m_axis_result_tvalid => sqrt_valid,
            m_axis_result_tdata  => result
        );
    
    valid_out <= sqrt_valid;
    
end architecture behavioral;
