library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple Sine/Cosine Lookup Table
-- 45-degree increments (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)
-- Input/Output: IEEE-754 single precision floating point
-- Latency: 1 cycle

entity sincos_lut_simple is
    Port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        
        -- Input: angle in radians (IEEE-754 FP32)
        angle_valid     : in  std_logic;
        angle           : in  std_logic_vector(31 downto 0);
        
        -- Output: sin and cos (IEEE-754 FP32)
        result_valid    : out std_logic;
        sin_out         : out std_logic_vector(31 downto 0);
        cos_out         : out std_logic_vector(31 downto 0)
    );
end sincos_lut_simple;

architecture Behavioral of sincos_lut_simple is

    -- Pre-computed sine values for 45° increments
    -- Index 0-7 represents 0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°
    type fp32_lut_t is array (0 to 7) of std_logic_vector(31 downto 0);
    
    constant SIN_LUT : fp32_lut_t := (
        0 => x"00000000",  -- sin(0°)   = 0.0
        1 => x"3F3504F3",  -- sin(45°)  = 0.707107
        2 => x"3F800000",  -- sin(90°)  = 1.0
        3 => x"3F3504F3",  -- sin(135°) = 0.707107
        4 => x"00000000",  -- sin(180°) = 0.0
        5 => x"BF3504F3",  -- sin(225°) = -0.707107
        6 => x"BF800000",  -- sin(270°) = -1.0
        7 => x"BF3504F3"   -- sin(315°) = -0.707107
    );
    
    constant COS_LUT : fp32_lut_t := (
        0 => x"3F800000",  -- cos(0°)   = 1.0
        1 => x"3F3504F3",  -- cos(45°)  = 0.707107
        2 => x"00000000",  -- cos(90°)  = 0.0
        3 => x"BF3504F3",  -- cos(135°) = -0.707107
        4 => x"BF800000",  -- cos(180°) = -1.0
        5 => x"BF3504F3",  -- cos(225°) = -0.707107
        6 => x"00000000",  -- cos(270°) = 0.0
        7 => x"3F3504F3"   -- cos(315°) = 0.707107
    );
    
    signal lut_index : integer range 0 to 7 := 0;
    signal valid_pipe : std_logic := '0';
    
    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of lut_index : signal is "TRUE";
    attribute MARK_DEBUG of angle : signal is "TRUE";
    attribute MARK_DEBUG of angle_valid : signal is "TRUE";
    attribute MARK_DEBUG of result_valid : signal is "TRUE";
    attribute MARK_DEBUG of sin_out : signal is "TRUE";
    attribute MARK_DEBUG of cos_out : signal is "TRUE";

begin

    process(clk)
        variable exp : unsigned(7 downto 0);
        variable angle_deg : integer;
        variable idx : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                result_valid <= '0';
                valid_pipe <= '0';
            else
                valid_pipe <= angle_valid;
                
                -- Stage 0: Decode angle to index
                if angle_valid = '1' then
                    -- Map specific angles to LUT indices
                    -- Check for exact or close matches to our 8 angles
                    -- 0° = 0x00000000
                    -- 45° = π/4 = 0x3F490FDB
                    -- 90° = π/2 = 0x3FC90FDB
                    -- 135° = 3π/4 = 0x4016CBE4
                    -- 180° = π = 0x40490FDB
                    -- 225° = 5π/4 = 0x409F6B8C
                    -- 270° = 3π/2 = 0x40C90FDB
                    -- 315° = 7π/4 = 0x40F6CBE4
                    
                    -- Direct angle matching (checking exp+mantissa ranges)
                    case angle(30 downto 20) is
                        when "00000000000" => lut_index <= 0;  -- 0°
                        when "01111110100" => lut_index <= 1;  -- 45° (π/4)
                        when "01111111100" => lut_index <= 2;  -- 90° (π/2)
                        when "10000000001" => lut_index <= 3;  -- 135° (3π/4)
                        when "10000000100" => lut_index <= 4;  -- 180° (π)
                        when "10000001011" => lut_index <= 5;  -- 225° (5π/4)
                        when "10000010010" => lut_index <= 6;  -- 270° (3π/2)
                        when "10000011000" => lut_index <= 7;  -- 315° (7π/4)
                        when others => lut_index <= 0;  -- Default to 0°
                    end case;
                end if;
                
                -- Stage 1: Output from LUT
                if valid_pipe = '1' then
                    sin_out <= SIN_LUT(lut_index);
                    cos_out <= COS_LUT(lut_index);
                    result_valid <= '1';
                else
                    result_valid <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
