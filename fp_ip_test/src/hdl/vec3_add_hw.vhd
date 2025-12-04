library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.vec3_pkg.all;

-- Hardware Vec3 addition: result = a + b
-- Uses 3 floating-point adders in parallel
-- Latency: 11 clock cycles (per FP add IP configuration)
entity vec3_add_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Vec3;
        b         : in  Vec3;
        result    : out Vec3;
        valid_out : out std_logic
    );
end entity vec3_add_hw;

architecture behavioral of vec3_add_hw is
    
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
    
    signal valid_x, valid_y, valid_z : std_logic;
    
begin
    
    -- Add X components
    add_x : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.x,
            m_axis_result_tvalid => valid_x,
            m_axis_result_tdata  => result.x
        );
    
    -- Add Y components
    add_y : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.y,
            m_axis_result_tvalid => valid_y,
            m_axis_result_tdata  => result.y
        );
    
    -- Add Z components
    add_z : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.z,
            m_axis_result_tvalid => valid_z,
            m_axis_result_tdata  => result.z
        );
    
    -- All three additions complete at the same time (same latency)
    valid_out <= valid_x and valid_y and valid_z;
    
end architecture behavioral;
