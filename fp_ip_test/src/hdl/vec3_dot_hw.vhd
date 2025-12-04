library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.vec3_pkg.all;

-- Hardware Vec3 dot product: result = a.x*b.x + a.y*b.y + a.z*b.z
-- Uses 3 floating-point multipliers and 2 floating-point adders
-- 
-- Pipeline stages:
--   Stage 1: 3 parallel multiplications (8 cycles)
--   Stage 2: Add mult_x + mult_y (11 cycles)
--   Stage 3: Add sum_xy + mult_z (11 cycles)
-- 
-- Performance:
--   Total Latency: 30 clock cycles (8 + 11 + 11)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 3x FP_MULT + 2x FP_ADD cores
--   
-- Note: The addition stages must be sequential (cannot be parallelized further)
-- because we need to sum 3 values which requires 2 addition operations.
entity vec3_dot_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Vec3;
        b         : in  Vec3;
        result    : out fp32;
        valid_out : out std_logic
    );
end entity vec3_dot_hw;

architecture behavioral of vec3_dot_hw is
    
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
    
    -- Stage 1: Multiplication results
    signal mult_x, mult_y, mult_z : fp32;
    signal mult_x_valid, mult_y_valid, mult_z_valid : std_logic;
    
    -- Stage 2: First addition result (mult_x + mult_y)
    signal sum_xy : fp32;
    signal sum_xy_valid : std_logic;
    
    -- Stage 3: Final addition result (sum_xy + mult_z)
    signal final_valid : std_logic;
    
begin
    
    -- Stage 1: Multiply corresponding components
    mult_x_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.x,
            m_axis_result_tvalid => mult_x_valid,
            m_axis_result_tdata  => mult_x
        );
    
    mult_y_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.y,
            m_axis_result_tvalid => mult_y_valid,
            m_axis_result_tdata  => mult_y
        );
    
    mult_z_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.z,
            m_axis_result_tvalid => mult_z_valid,
            m_axis_result_tdata  => mult_z
        );
    
    -- Stage 2: Add first two products
    add_xy_inst : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => mult_x_valid,
            s_axis_a_tdata       => mult_x,
            s_axis_b_tvalid      => mult_y_valid,
            s_axis_b_tdata       => mult_y,
            m_axis_result_tvalid => sum_xy_valid,
            m_axis_result_tdata  => sum_xy
        );
    
    -- Stage 3: Add third product to the sum
    add_final_inst : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => sum_xy_valid,
            s_axis_a_tdata       => sum_xy,
            s_axis_b_tvalid      => mult_z_valid,
            s_axis_b_tdata       => mult_z,
            m_axis_result_tvalid => final_valid,
            m_axis_result_tdata  => result
        );
    
    valid_out <= final_valid;
    
end architecture behavioral;
