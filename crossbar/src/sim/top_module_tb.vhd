library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

library work;
use work.crossbar_pkg.all;
use work.lin_alg_pkg.all;

-- Testbench for top module with dot product producer
entity top_module_tb is
end entity top_module_tb;

architecture behavioral of top_module_tb is

    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Control signals
    signal input_valid : std_logic := '0';
    
    -- Input vectors (flattened)
    signal a_x, a_y, a_z : std_logic_vector(31 downto 0) := (others => '0');
    signal b_x, b_y, b_z : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Output
    signal result       : std_logic_vector(31 downto 0);
    signal result_valid : std_logic_vector(0 downto 0);
    
    -- Testbench control
    signal sim_done : boolean := false;
    
    -- Helper function to convert real to FP32
    function real_to_fp32(val : real) return std_logic_vector is
        variable result : std_logic_vector(31 downto 0);
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable mantissa_int : integer;
        variable exp_biased : unsigned(7 downto 0);
        variable mant_bits : unsigned(22 downto 0);
    begin
        if val = 0.0 then
            return X"00000000";
        end if;
        
        -- Determine sign
        if val < 0.0 then
            sign := '1';
            mantissa := -val;
        else
            sign := '0';
            mantissa := val;
        end if;
        
        -- Normalize and find exponent
        exponent := 0;
        while mantissa >= 2.0 loop
            mantissa := mantissa / 2.0;
            exponent := exponent + 1;
        end loop;
        while mantissa < 1.0 loop
            mantissa := mantissa * 2.0;
            exponent := exponent - 1;
        end loop;
        
        -- Bias exponent (127 for single precision)
        exp_biased := to_unsigned(exponent + 127, 8);
        
        -- Extract mantissa (remove leading 1)
        mantissa := mantissa - 1.0;
        mantissa_int := integer(mantissa * (2.0 ** 23));
        mant_bits := to_unsigned(mantissa_int, 23);
        
        -- Assemble FP32
        result := sign & std_logic_vector(exp_biased) & std_logic_vector(mant_bits);
        return result;
    end function;
    
    -- Helper function to convert FP32 to real (approximate)
    function fp32_to_real(fp : std_logic_vector(31 downto 0)) return real is
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable result : real;
    begin
        sign := fp(31);
        exponent := to_integer(unsigned(fp(30 downto 23))) - 127;
        mantissa := 1.0 + real(to_integer(unsigned(fp(22 downto 0)))) / (2.0 ** 23);
        result := mantissa * (2.0 ** exponent);
        if sign = '1' then
            result := -result;
        end if;
        return result;
    end function;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    
    -- DUT instantiation
    dut : entity work.top_module
        port map (
            clk          => clk,
            rst          => rst,
            input_valid  => input_valid,
            a_x          => a_x,
            a_y          => a_y,
            a_z          => a_z,
            b_x          => b_x,
            b_y          => b_y,
            b_z          => b_z,
            result       => result,
            result_valid => result_valid
        );
    
    -- Test stimulus process
    stimulus_proc : process
        variable line_v : line;
        variable result_real : real;
        variable expected : real;
    begin
        -- Reset
        rst <= '1';
        input_valid <= '0';
        wait for CLK_PERIOD * 10;
        wait until rising_edge(clk);
        rst <= '0';
        wait for CLK_PERIOD * 5;
        
        report "Starting dot product tests...";
        
        -- Test 1: Simple dot product [1, 2, 3] . [4, 5, 6] = 4 + 10 + 18 = 32
        report "Test 1: [1, 2, 3] . [4, 5, 6] = 32";
        a_x <= real_to_fp32(1.0);
        a_y <= real_to_fp32(2.0);
        a_z <= real_to_fp32(3.0);
        b_x <= real_to_fp32(4.0);
        b_y <= real_to_fp32(5.0);
        b_z <= real_to_fp32(6.0);
        expected := 32.0;
        
        wait until rising_edge(clk);
        input_valid <= '1';
        wait until rising_edge(clk);
        input_valid <= '0';
        
        -- Wait for result
        wait until result_valid(0) = '1';
        wait for CLK_PERIOD;
        
        result_real := fp32_to_real(result);
        write(line_v, string'("Test 1 result: "));
        write(line_v, result_real);
        write(line_v, string'(" (expected "));
        write(line_v, expected);
        write(line_v, string'(")"));
        writeline(output, line_v);
        
        wait for CLK_PERIOD * 10;
        
        -- Test 2: Unit vectors [1, 0, 0] . [0, 1, 0] = 0
        report "Test 2: [1, 0, 0] . [0, 1, 0] = 0";
        a_x <= real_to_fp32(1.0);
        a_y <= real_to_fp32(0.0);
        a_z <= real_to_fp32(0.0);
        b_x <= real_to_fp32(0.0);
        b_y <= real_to_fp32(1.0);
        b_z <= real_to_fp32(0.0);
        expected := 0.0;
        
        wait until rising_edge(clk);
        input_valid <= '1';
        wait until rising_edge(clk);
        input_valid <= '0';
        
        wait until result_valid(0) = '1';
        wait for CLK_PERIOD;
        
        result_real := fp32_to_real(result);
        write(line_v, string'("Test 2 result: "));
        write(line_v, result_real);
        write(line_v, string'(" (expected "));
        write(line_v, expected);
        write(line_v, string'(")"));
        writeline(output, line_v);
        
        wait for CLK_PERIOD * 10;
        
        -- Test 3: Same vector [2, 3, 4] . [2, 3, 4] = 4 + 9 + 16 = 29
        report "Test 3: [2, 3, 4] . [2, 3, 4] = 29";
        a_x <= real_to_fp32(2.0);
        a_y <= real_to_fp32(3.0);
        a_z <= real_to_fp32(4.0);
        b_x <= real_to_fp32(2.0);
        b_y <= real_to_fp32(3.0);
        b_z <= real_to_fp32(4.0);
        expected := 29.0;
        
        wait until rising_edge(clk);
        input_valid <= '1';
        wait until rising_edge(clk);
        input_valid <= '0';
        
        wait until result_valid(0) = '1';
        wait for CLK_PERIOD;
        
        result_real := fp32_to_real(result);
        write(line_v, string'("Test 3 result: "));
        write(line_v, result_real);
        write(line_v, string'(" (expected "));
        write(line_v, expected);
        write(line_v, string'(")"));
        writeline(output, line_v);
        
        wait for CLK_PERIOD * 10;
        
        report "All tests completed!";
        sim_done <= true;
        wait;
    end process;

end architecture behavioral;
