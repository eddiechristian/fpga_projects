library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.vec3_pkg.all;

-- Hardware Vec3 subtraction: result = a - b
-- Uses 3 floating-point adders in parallel (subtraction via negation)
-- 
-- Implementation: Negate b by flipping sign bit, then add
--   result.x = a.x + (-b.x)
--   result.y = a.y + (-b.y)
--   result.z = a.z + (-b.z)
--
-- Performance:
--   Latency: 11 clock cycles (same as add)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 3x FP_ADD cores
--   
-- Note: Subtraction is implemented as addition with negated operand.
-- Negation is done by XOR'ing the sign bit (bit 31) with '1'.
entity vec3_sub_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Vec3;
        b         : in  Vec3;
        result    : out Vec3;
        valid_out : out std_logic
    );
end entity vec3_sub_hw;

architecture behavioral of vec3_sub_hw is
    
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
    
    -- Negated b vector (sign bits flipped)
    signal b_neg : Vec3;
    
    signal valid_x, valid_y, valid_z : std_logic;
    
begin
    
    -- Negate b by flipping sign bit (bit 31) of each component
    b_neg.x <= not b.x(31) & b.x(30 downto 0);
    b_neg.y <= not b.y(31) & b.y(30 downto 0);
    b_neg.z <= not b.z(31) & b.z(30 downto 0);
    
    -- Subtract X components (a.x - b.x = a.x + (-b.x))
    sub_x : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b_neg.x,
            m_axis_result_tvalid => valid_x,
            m_axis_result_tdata  => result.x
        );
    
    -- Subtract Y components (a.y - b.y = a.y + (-b.y))
    sub_y : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b_neg.y,
            m_axis_result_tvalid => valid_y,
            m_axis_result_tdata  => result.y
        );
    
    -- Subtract Z components (a.z - b.z = a.z + (-b.z))
    sub_z : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b_neg.z,
            m_axis_result_tvalid => valid_z,
            m_axis_result_tdata  => result.z
        );
    
    -- All three subtractions complete at the same time (same latency)
    valid_out <= valid_x and valid_y and valid_z;
    
end architecture behavioral;
