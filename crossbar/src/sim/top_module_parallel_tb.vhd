LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

ENTITY top_module_parallel_tb IS
END ENTITY top_module_parallel_tb;

ARCHITECTURE behavioral OF top_module_parallel_tb IS

    -- Clock and reset
    SIGNAL clk       : STD_LOGIC := '0';
    SIGNAL rst       : STD_LOGIC := '1';
    SIGNAL test_done : STD_LOGIC;

    -- Clock period
    CONSTANT CLK_PERIOD : TIME := 10 ns;  -- 100 MHz
    
    -- Testbench control
    SIGNAL sim_done : BOOLEAN := FALSE;

BEGIN

    -- Clock generation
    clk <= NOT clk AFTER CLK_PERIOD / 2 WHEN NOT sim_done ELSE '0';

    -- DUT instantiation
    dut : ENTITY work.top_module_parallel
        PORT MAP(
            clk       => clk,
            rst       => rst,
            test_done => test_done
        );

    -- Stimulus process
    stimulus_proc : PROCESS
    BEGIN
        -- Hold reset for a few cycles
        rst <= '1';
        WAIT FOR CLK_PERIOD * 5;
        
        -- Release reset
        rst <= '0';
        REPORT "Reset released, test starting...";
        
        -- Wait for test to complete
        WAIT UNTIL test_done = '1';
        REPORT "Test completed!";
        
        WAIT FOR CLK_PERIOD * 10;
        
        REPORT "Simulation ending...";
        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
