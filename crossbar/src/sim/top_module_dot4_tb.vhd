library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;
use work.lin_alg_pkg.all;

-- Testbench for DOT4 verification test
-- This testbench starts the DOT4 test module and monitors completion and pass/fail status
entity top_module_dot4_tb is
end entity top_module_dot4_tb;

architecture behavioral of top_module_dot4_tb is

    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Outputs
    signal test_done : std_logic;
    signal test_pass : std_logic;
    
    -- Testbench control
    signal sim_done : boolean := false;
    
begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    
    -- DUT instantiation
    dut : entity work.top_module_dot4
        port map (
            clk       => clk,
            rst       => rst,
            test_done => test_done,
            test_pass => test_pass
        );
    
    -- Test stimulus process
    stimulus_proc : process
    begin
        -- Hold reset for a few cycles
        report "Starting DOT4 verification test...";
        rst <= '1';
        wait for CLK_PERIOD * 20;
        wait until rising_edge(clk);
        rst <= '0';
        
        report "Reset released - DOT4 test running";
        
        -- Wait for test to complete
        wait until test_done = '1';
        
        -- Check pass/fail status
        if test_pass = '1' then
            report "========================================";
            report "DOT4 VERIFICATION TEST: ALL TESTS PASSED";
            report "========================================";
        else
            report "========================================";
            report "DOT4 VERIFICATION TEST: SOME TESTS FAILED";
            report "========================================";
            report "Check simulation log for detailed error messages" severity ERROR;
        end if;
        
        -- Let simulation run a bit longer to see final state
        wait for CLK_PERIOD * 20;
        
        report "Simulation ending...";
        sim_done <= true;
        wait;
    end process;

end architecture behavioral;
