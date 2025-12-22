LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY sincos_lut_simple_tb IS
END ENTITY sincos_lut_simple_tb;

ARCHITECTURE behavioral OF sincos_lut_simple_tb IS

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    
    SIGNAL angle_valid : STD_LOGIC := '0';
    SIGNAL angle : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL result_valid : STD_LOGIC;
    SIGNAL sin_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL cos_out : STD_LOGIC_VECTOR(31 DOWNTO 0);
    
    SIGNAL sim_done : BOOLEAN := FALSE;
    
BEGIN

    clk <= NOT clk AFTER CLK_PERIOD / 2 WHEN NOT sim_done ELSE '0';
    
    dut : ENTITY work.sincos_lut_simple
        PORT MAP (
            clk => clk,
            reset => reset,
            angle_valid => angle_valid,
            angle => angle,
            result_valid => result_valid,
            sin_out => sin_out,
            cos_out => cos_out
        );
    
    stimulus_proc : PROCESS
    BEGIN
        REPORT "Starting sincos LUT testbench...";
        reset <= '1';
        angle_valid <= '0';
        WAIT FOR CLK_PERIOD * 10;
        WAIT UNTIL rising_edge(clk);
        reset <= '0';
        WAIT FOR CLK_PERIOD * 5;
        
        -- Test 1: 0 degrees (0 radians)
        REPORT "Test 1: 0 radians";
        angle <= X"00000000";
        angle_valid <= '1';
        WAIT UNTIL rising_edge(clk);
        angle_valid <= '0';
        
        WAIT UNTIL result_valid = '1' OR sim_done;
        IF result_valid = '1' THEN
            REPORT "Result: sin=" & to_hstring(sin_out) & " cos=" & to_hstring(cos_out);
        ELSE
            REPORT "TIMEOUT!" SEVERITY failure;
        END IF;
        
        WAIT FOR CLK_PERIOD * 5;
        
        -- Test 2: 45 degrees (pi/4 radians = 0x3F490FDB)
        REPORT "Test 2: pi/4 radians (45 deg)";
        angle <= X"3F490FDB";
        angle_valid <= '1';
        WAIT UNTIL rising_edge(clk);
        angle_valid <= '0';
        
        WAIT UNTIL result_valid = '1' OR sim_done;
        IF result_valid = '1' THEN
            REPORT "Result: sin=" & to_hstring(sin_out) & " cos=" & to_hstring(cos_out);
        ELSE
            REPORT "TIMEOUT!" SEVERITY failure;
        END IF;
        
        REPORT "All tests complete!";
        WAIT FOR CLK_PERIOD * 10;
        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
