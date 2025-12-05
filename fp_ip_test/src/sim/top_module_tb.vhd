library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity top_module_tb is
end top_module_tb;

architecture Behavioral of top_module_tb is

    -- Component declaration
    component top_module
        Port (
            clk       : in  STD_LOGIC;
            reset     : in  STD_LOGIC;
            heartbeat : out STD_LOGIC
        );
    end component;

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- Signals
    signal clk       : STD_LOGIC := '0';
    signal reset     : STD_LOGIC := '0';
    signal heartbeat : STD_LOGIC;
    signal sim_done  : BOOLEAN := false;

    -- Helper function to convert IEEE 754 single precision to real
    function fp32_to_real(fp : std_logic_vector(31 downto 0)) return real is
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable result : real;
    begin
        -- Extract fields
        sign := fp(31);
        exponent := to_integer(unsigned(fp(30 downto 23)));
        
        -- Handle special cases
        if exponent = 0 then
            return 0.0;  -- Zero or denormal (treat as zero)
        elsif exponent = 255 then
            return 0.0;  -- Infinity or NaN (treat as zero for display)
        end if;
        
        -- Calculate mantissa (with implicit 1)
        mantissa := 1.0 + real(to_integer(unsigned(fp(22 downto 0)))) / (2.0 ** 23);
        
        -- Calculate result
        result := mantissa * (2.0 ** real(exponent - 127));
        
        if sign = '1' then
            result := -result;
        end if;
        
        return result;
    end function;
    
    -- Helper function to convert real to IEEE 754 single precision
    function real_to_fp32(r : real) return std_logic_vector is
        variable result : std_logic_vector(31 downto 0);
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable exp_bits : unsigned(7 downto 0);
        variable mant_bits : unsigned(22 downto 0);
        variable temp : real;
    begin
        -- Handle zero
        if r = 0.0 then
            return X"00000000";
        end if;
        
        -- Determine sign
        if r < 0.0 then
            sign := '1';
            temp := -r;
        else
            sign := '0';
            temp := r;
        end if;
        
        -- Calculate exponent and mantissa
        exponent := integer(floor(log2(temp)));
        mantissa := temp / (2.0 ** real(exponent));
        
        -- Bias exponent (127 for single precision)
        exp_bits := to_unsigned(exponent + 127, 8);
        
        -- Extract mantissa bits (remove implicit 1)
        mantissa := mantissa - 1.0;
        mant_bits := to_unsigned(integer(mantissa * (2.0 ** 23)), 23);
        
        -- Combine sign, exponent, and mantissa
        result := sign & std_logic_vector(exp_bits) & std_logic_vector(mant_bits);
        
        return result;
    end function;

begin

    -- Instantiate UUT
    uut : top_module
        port map (
            clk       => clk,
            reset     => reset,
            heartbeat => heartbeat
        );

    -- Clock generation
    clk_process : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 50 ns;

        -- Run simulation for vec3 operations
        report "Running vec3 operations...";
        wait for 1200 ns;

        -- End simulation
        report "Simulation complete";
        sim_done <= true;
        wait;
    end process;

end Behavioral;
