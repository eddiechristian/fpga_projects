library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

-- Hardware Vec3 cross product: result = a × b
-- Cross product formula:
--   result.x = a.y * b.z - a.z * b.y
--   result.y = a.z * b.x - a.x * b.z
--   result.z = a.x * b.y - a.y * b.x
-- 
-- Uses 6 floating-point multipliers and 3 floating-point adders
-- (Note: subtraction is implemented as addition with negated operand)
-- 
-- Pipeline stages:
--   Stage 1: 6 parallel multiplications (8 cycles)
--   Stage 2: 3 parallel subtractions (11 cycles)
-- 
-- Performance:
--   Total Latency: 19 clock cycles (8 + 11)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 6x FP_MULT + 3x FP_ADD cores
--   
-- Note: All three result components can be computed in parallel,
-- making this more efficient than dot product despite using more cores.
entity vec3_cross_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Vec3;
        b         : in  Vec3;
        result    : out Vec3;
        valid_out : out std_logic
    );
end entity vec3_cross_hw;

architecture behavioral of vec3_cross_hw is
    
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
    -- For X component: a.y * b.z and a.z * b.y
    signal mult_ay_bz, mult_az_by : fp32;
    signal mult_ay_bz_valid, mult_az_by_valid : std_logic;
    
    -- For Y component: a.z * b.x and a.x * b.z
    signal mult_az_bx, mult_ax_bz : fp32;
    signal mult_az_bx_valid, mult_ax_bz_valid : std_logic;
    
    -- For Z component: a.x * b.y and a.y * b.x
    signal mult_ax_by, mult_ay_bx : fp32;
    signal mult_ax_by_valid, mult_ay_bx_valid : std_logic;
    
    -- Stage 2: Subtraction results (negated second operand)
    signal mult_az_by_neg, mult_ax_bz_neg, mult_ay_bx_neg : fp32;
    signal result_x_valid, result_y_valid, result_z_valid : std_logic;
    
begin
    
    -- ========== Stage 1: All 6 multiplications in parallel ==========
    
    -- X component multiplications
    mult_ay_bz_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.z,
            m_axis_result_tvalid => mult_ay_bz_valid,
            m_axis_result_tdata  => mult_ay_bz
        );
    
    mult_az_by_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.y,
            m_axis_result_tvalid => mult_az_by_valid,
            m_axis_result_tdata  => mult_az_by
        );
    
    -- Y component multiplications
    mult_az_bx_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.z,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.x,
            m_axis_result_tvalid => mult_az_bx_valid,
            m_axis_result_tdata  => mult_az_bx
        );
    
    mult_ax_bz_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.z,
            m_axis_result_tvalid => mult_ax_bz_valid,
            m_axis_result_tdata  => mult_ax_bz
        );
    
    -- Z component multiplications
    mult_ax_by_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.x,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.y,
            m_axis_result_tvalid => mult_ax_by_valid,
            m_axis_result_tdata  => mult_ax_by
        );
    
    mult_ay_bx_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => valid_in,
            s_axis_a_tdata       => a.y,
            s_axis_b_tvalid      => valid_in,
            s_axis_b_tdata       => b.x,
            m_axis_result_tvalid => mult_ay_bx_valid,
            m_axis_result_tdata  => mult_ay_bx
        );
    
    -- ========== Stage 2: All 3 subtractions in parallel ==========
    -- Subtraction is done by negating the sign bit and adding
    
    mult_az_by_neg <= not mult_az_by(31) & mult_az_by(30 downto 0);
    mult_ax_bz_neg <= not mult_ax_bz(31) & mult_ax_bz(30 downto 0);
    mult_ay_bx_neg <= not mult_ay_bx(31) & mult_ay_bx(30 downto 0);
    
    -- X = a.y * b.z - a.z * b.y
    sub_x_inst : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => mult_ay_bz_valid,
            s_axis_a_tdata       => mult_ay_bz,
            s_axis_b_tvalid      => mult_az_by_valid,
            s_axis_b_tdata       => mult_az_by_neg,
            m_axis_result_tvalid => result_x_valid,
            m_axis_result_tdata  => result.x
        );
    
    -- Y = a.z * b.x - a.x * b.z
    sub_y_inst : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => mult_az_bx_valid,
            s_axis_a_tdata       => mult_az_bx,
            s_axis_b_tvalid      => mult_ax_bz_valid,
            s_axis_b_tdata       => mult_ax_bz_neg,
            m_axis_result_tvalid => result_y_valid,
            m_axis_result_tdata  => result.y
        );
    
    -- Z = a.x * b.y - a.y * b.x
    sub_z_inst : floating_point_add
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => mult_ax_by_valid,
            s_axis_a_tdata       => mult_ax_by,
            s_axis_b_tvalid      => mult_ay_bx_valid,
            s_axis_b_tdata       => mult_ay_bx_neg,
            m_axis_result_tvalid => result_z_valid,
            m_axis_result_tdata  => result.z
        );
    
    -- All three components complete at the same time
    valid_out <= result_x_valid and result_y_valid and result_z_valid;
    
end architecture behavioral;
