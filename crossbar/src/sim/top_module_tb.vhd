library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

library work;
use work.crossbar_pkg.all;
use work.lin_alg_pkg.all;

-- Testbench for top module throughput test
-- This testbench just starts the self-contained test and monitors completion
entity top_module_tb is
end entity top_module_tb;

architecture behavioral of top_module_tb is

    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Output
    signal test_done : std_logic;
    
    -- Testbench control
    signal sim_done : boolean := false;
    
begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    
    -- DUT instantiation
    dut : entity work.top_module
        port map (
            clk       => clk,
            rst       => rst,
            test_done => test_done
        );
    
    -- Test stimulus process
    stimulus_proc : process
    begin
        -- Hold reset for a few cycles
        report "Starting throughput test...";
        rst <= '1';
        wait for CLK_PERIOD * 20;
        wait until rising_edge(clk);
        rst <= '0';
        
        report "Reset released - test running automatically";
        
        -- Wait for test to complete (monitor test_done signal)
        wait until test_done = '1';
        
        report "Test completed! (test_done asserted)";
        report "Check the simulation log for detailed cycle counts and throughput metrics";
        
        -- Let simulation run a bit longer to see final state
        wait for CLK_PERIOD * 20;
        
        report "Simulation ending...";
        sim_done <= true;
        wait;
    end process;

end architecture behavioral;
