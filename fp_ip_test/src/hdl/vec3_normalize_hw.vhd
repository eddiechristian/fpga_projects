library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.vec3_pkg.all;

-- Hardware Vec3 normalize: result = v / |v|
-- Implements the Normalize() function from qbVector.h
-- 
-- Computes unit vector by dividing each component by the magnitude
-- Uses magnitude computation followed by scalar division (multiplication by reciprocal)
-- 
-- Pipeline stages:
--   Stage 1-4: Compute magnitude (58 cycles) - see vec3_magnitude_hw
--   Stage 5: Compute reciprocal 1/magnitude using division (28 cycles)
--   Stage 6: Multiply each component by reciprocal in parallel (8 cycles)
-- 
-- Performance:
--   Total Latency: 94 clock cycles (58 + 28 + 8)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 1x vec3_magnitude_hw + 1x FP_DIV + 3x FP_MULT
--   Expanded: 3x FP_MULT + 2x FP_ADD + 1x FP_SQRT + 1x FP_DIV + 3x FP_MULT
--   Total: 6x FP_MULT + 2x FP_ADD + 1x FP_SQRT + 1x FP_DIV
--   
-- Note: Division is expensive (28 cycles). For batch normalization,
-- consider sharing the divider across multiple operations.
entity vec3_normalize_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        v         : in  Vec3;
        result    : out Vec3;
        valid_out : out std_logic
    );
end entity vec3_normalize_hw;

architecture behavioral of vec3_normalize_hw is
    
    component vec3_magnitude_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            v         : in  Vec3;
            result    : out std_logic_vector(31 downto 0);
            valid_out : out std_logic
        );
    end component;
    
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
    
    -- We'll need a divide IP for computing 1/magnitude
    -- For now, using multiply with reciprocal approximation
    -- In real implementation, need FP divide IP core
    component floating_point_div
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
    
    -- Magnitude computation result
    signal magnitude : fp32;
    signal mag_valid : std_logic;
    
    -- Reciprocal (1/magnitude)
    signal reciprocal : fp32;
    signal recip_valid : std_logic;
    
    -- Constant 1.0 for division
    constant ONE : fp32 := X"3F800000";
    
    -- Delayed input vector (to match magnitude pipeline)
    -- Need to delay by 58 cycles to align with magnitude result
    type vec3_delay_array is array (0 to 57) of Vec3;
    signal v_delayed : vec3_delay_array;
    
    -- Final multiplication results
    signal result_x_valid, result_y_valid, result_z_valid : std_logic;
    
begin
    
    -- Stage 1-4: Compute magnitude
    mag_inst : vec3_magnitude_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_in,
            v         => v,
            result    => magnitude,
            valid_out => mag_valid
        );
    
    -- Delay input vector to match magnitude pipeline
    process(clk)
    begin
        if rising_edge(clk) then
            v_delayed(0) <= v;
            for i in 1 to 57 loop
                v_delayed(i) <= v_delayed(i-1);
            end loop;
        end if;
    end process;
    
    -- Stage 5: Compute reciprocal (1/magnitude)
    -- Note: This requires an FP divide IP core to be generated
    div_inst : floating_point_div
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => mag_valid,
            s_axis_a_tdata       => ONE,
            s_axis_b_tvalid      => mag_valid,
            s_axis_b_tdata       => magnitude,
            m_axis_result_tvalid => recip_valid,
            m_axis_result_tdata  => reciprocal
        );
    
    -- Stage 6: Multiply each component by reciprocal (in parallel)
    mult_x : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => recip_valid,
            s_axis_a_tdata       => v_delayed(57).x,
            s_axis_b_tvalid      => recip_valid,
            s_axis_b_tdata       => reciprocal,
            m_axis_result_tvalid => result_x_valid,
            m_axis_result_tdata  => result.x
        );
    
    mult_y : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => recip_valid,
            s_axis_a_tdata       => v_delayed(57).y,
            s_axis_b_tvalid      => recip_valid,
            s_axis_b_tdata       => reciprocal,
            m_axis_result_tvalid => result_y_valid,
            m_axis_result_tdata  => result.y
        );
    
    mult_z : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => recip_valid,
            s_axis_a_tdata       => v_delayed(57).z,
            s_axis_b_tvalid      => recip_valid,
            s_axis_b_tdata       => reciprocal,
            m_axis_result_tvalid => result_z_valid,
            m_axis_result_tdata  => result.z
        );
    
    -- All three multiplications complete at the same time
    valid_out <= result_x_valid and result_y_valid and result_z_valid;
    
end architecture behavioral;
