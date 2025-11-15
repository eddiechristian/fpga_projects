library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sine_generator is
    Generic (
        CLK_FREQ        : integer := 100_000_000;  -- System clock frequency
        SINE_FREQ       : integer := 1000;          -- Output sine wave frequency in Hz
        PHASE_OFFSET    : integer := 0              -- Phase offset in degrees (0, 120, 240)
    );
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        enable      : in  std_logic;
        sine_out    : out std_logic_vector(11 downto 0);
        update_tick : out std_logic  -- Pulse when new value is ready
    );
end sine_generator;

architecture Behavioral of sine_generator is
    -- Sine lookup table: 64 samples for one complete cycle
    -- Values scaled to 12-bit range (0-4095), offset to center at 2048
    type sine_lut_type is array (0 to 63) of integer range 0 to 4095;
    constant SINE_LUT : sine_lut_type := (
        2048, 2248, 2447, 2642, 2831, 3013, 3185, 3346,
        3495, 3630, 3750, 3853, 3939, 4007, 4056, 4085,
        4095, 4085, 4056, 4007, 3939, 3853, 3750, 3630,
        3495, 3346, 3185, 3013, 2831, 2642, 2447, 2248,
        2048, 1847, 1648, 1453, 1264, 1082,  910,  749,
         600,  465,  345,  242,  156,   88,   39,   10,
           0,   10,   39,   88,  156,  242,  345,  465,
         600,  749,  910, 1082, 1264, 1453, 1648, 1847
    );
    
    -- Calculate samples per period based on frequency
    constant SAMPLES_PER_PERIOD : integer := 64;
    constant CLOCKS_PER_SAMPLE : integer := CLK_FREQ / (SINE_FREQ * SAMPLES_PER_PERIOD);
    
    -- Phase offset in samples (0, 21, 42 for 0°, 120°, 240°)
    constant PHASE_SAMPLES : integer := (PHASE_OFFSET * SAMPLES_PER_PERIOD) / 360;
    
    signal sample_counter : integer range 0 to CLOCKS_PER_SAMPLE - 1 := 0;
    signal phase_index : integer range 0 to SAMPLES_PER_PERIOD - 1 := PHASE_SAMPLES;
    signal update_tick_int : std_logic := '0';

begin
    update_tick <= update_tick_int;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sample_counter <= 0;
                phase_index <= PHASE_SAMPLES;
                update_tick_int <= '0';
                sine_out <= std_logic_vector(to_unsigned(SINE_LUT(PHASE_SAMPLES), 12));
            else
                update_tick_int <= '0';
                
                if enable = '1' then
                    if sample_counter = CLOCKS_PER_SAMPLE - 1 then
                        sample_counter <= 0;
                        
                        -- Update sine output
                        sine_out <= std_logic_vector(to_unsigned(SINE_LUT(phase_index), 12));
                        update_tick_int <= '1';
                        
                        -- Increment phase
                        if phase_index = SAMPLES_PER_PERIOD - 1 then
                            phase_index <= 0;
                        else
                            phase_index <= phase_index + 1;
                        end if;
                    else
                        sample_counter <= sample_counter + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
