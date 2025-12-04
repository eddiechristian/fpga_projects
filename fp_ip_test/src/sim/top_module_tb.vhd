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
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            a_in        : in  STD_LOGIC_VECTOR(31 downto 0);
            b_in        : in  STD_LOGIC_VECTOR(31 downto 0);
            valid_in    : in  STD_LOGIC;
            sqrt_out    : out STD_LOGIC_VECTOR(31 downto 0);
            mult_out    : out STD_LOGIC_VECTOR(31 downto 0);
            add_out     : out STD_LOGIC_VECTOR(31 downto 0);
            compare_out : out STD_LOGIC_VECTOR(7 downto 0);
            valid_out   : out STD_LOGIC
        );
    end component;

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

    -- Signals
    signal clk          : STD_LOGIC := '0';
    signal reset        : STD_LOGIC := '0';
    signal a_in         : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal b_in         : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal valid_in     : STD_LOGIC := '0';
    signal sqrt_out     : STD_LOGIC_VECTOR(31 downto 0);
    signal mult_out     : STD_LOGIC_VECTOR(31 downto 0);
    signal add_out      : STD_LOGIC_VECTOR(31 downto 0);
    signal compare_out  : STD_LOGIC_VECTOR(7 downto 0);
    signal valid_out    : STD_LOGIC;

    signal sim_done     : BOOLEAN := false;

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
            clk         => clk,
            reset       => reset,
            a_in        => a_in,
            b_in        => b_in,
            valid_in    => valid_in,
            sqrt_out    => sqrt_out,
            mult_out    => mult_out,
            add_out     => add_out,
            compare_out => compare_out,
            valid_out   => valid_out
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

        -- Test case 1: a=9.0, b=3.0
        report "Test 1: a=9.0, b=3.0";
        a_in <= real_to_fp32(9.0);
        b_in <= real_to_fp32(3.0);
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        wait for 200 ns;

        -- Test case 2: a=16.0, b=4.0
        report "Test 2: a=16.0, b=4.0";
        a_in <= real_to_fp32(16.0);
        b_in <= real_to_fp32(4.0);
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        wait for 200 ns;

        -- Test case 3: a=2.5, b=1.5
        report "Test 3: a=2.5, b=1.5";
        a_in <= real_to_fp32(2.5);
        b_in <= real_to_fp32(1.5);
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        wait for 200 ns;

        -- Test case 4: a=100.0, b=50.0
        report "Test 4: a=100.0, b=50.0";
        a_in <= real_to_fp32(100.0);
        b_in <= real_to_fp32(50.0);
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        wait for 200 ns;

        -- Test case 5: a=0.25, b=0.5
        report "Test 5: a=0.25, b=0.5";
        a_in <= real_to_fp32(0.25);
        b_in <= real_to_fp32(0.5);
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        wait for 500 ns;

        -- End simulation
        report "Simulation complete";
        sim_done <= true;
        wait;
    end process;

    -- Monitor process
    monitor_proc: process(valid_out)
        variable sqrt_str, mult_str, add_str, cmp_str : line;
    begin
        if valid_out = '1' then
            hwrite(sqrt_str, sqrt_out);
            hwrite(mult_str, mult_out);
            hwrite(add_str, add_out);
            hwrite(cmp_str, compare_out);
            report "Results ready - sqrt_out: " & sqrt_str.all &
                   ", mult_out: " & mult_str.all &
                   ", add_out: " & add_str.all &
                   ", compare_out: " & cmp_str.all;
            deallocate(sqrt_str);
            deallocate(mult_str);
            deallocate(add_str);
            deallocate(cmp_str);
        end if;
    end process;

end Behavioral;
