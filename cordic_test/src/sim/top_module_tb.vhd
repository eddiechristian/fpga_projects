library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity top_module_tb is
end top_module_tb;

architecture Behavioral of top_module_tb is

    component top_module is
        Port (
            clk     : in  std_logic;
            reset   : in  std_logic;
            led     : out std_logic_vector(3 downto 0)
        );
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal led : std_logic_vector(3 downto 0);
    
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    
    -- Function to convert Q1.31 signed fraction to real
    function q31_to_real(q31 : std_logic_vector(31 downto 0)) return real is
        variable temp : signed(31 downto 0);
        variable result : real;
    begin
        temp := signed(q31);
        result := real(to_integer(temp)) / real(2**31);
        return result;
    end function;
    
    -- Function to check if two real values are close (within tolerance)
    function is_close(a : real; b : real; tolerance : real := 0.001) return boolean is
    begin
        return abs(a - b) < tolerance;
    end function;

begin

    uut: top_module port map (
        clk => clk,
        reset => reset,
        led => led
    );
    
    -- Clock generation
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- Stimulus process
    stim_process: process
    begin
        -- Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        
        -- Wait for all tests to complete
        -- 7 angles * 100 cycles * 10 ns = 7000 ns + overhead
        wait for 10 us;
        
        report "CORDIC Test Complete - Review waveform to verify results";
        report "Expected values:";
        report "  0 rad (0 deg):      sin=0.000, cos=1.000";
        report "  pi/6 (30 deg):      sin=0.500, cos=0.866";
        report "  pi/4 (45 deg):      sin=0.707, cos=0.707";
        report "  pi/3 (60 deg):      sin=0.866, cos=0.500";
        report "  pi/2 (90 deg):      sin=1.000, cos=0.000";
        report "  2*pi/3 (120 deg):   sin=0.866, cos=-0.500";
        report "  pi (180 deg):       sin=0.000, cos=-1.000";
        
        wait;
    end process;

end Behavioral;
