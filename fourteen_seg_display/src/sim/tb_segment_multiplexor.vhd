library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_segment_multiplexor is
end tb_segment_multiplexor;

architecture Behavioral of tb_segment_multiplexor is
    -- Constants
    constant NUM_DIGITS : natural := 5;
    constant CLK_DIV_MAX : natural := 4;  -- Digit changes every 4 clock cycles
    constant CLK_PERIOD : time := 10 ns;
    
    -- Component declaration
    component segment_multiplexor
        GENERIC(
            NUM_DIGITS: natural := 4;
            CLK_DIV_MAX: natural := 1
        );
        Port (
            clk   : in  std_logic;
            ascii_in : in STD_LOGIC_VECTOR(((NUM_DIGITS * 8) -1) downto 0);
            reset : in  std_logic;
            digit_selector: out STD_LOGIC_VECTOR((integer(ceil(log2(real(NUM_DIGITS))))-1) downto 0);
            segments : out STD_LOGIC_VECTOR(0 to 13)
        );
    end component;
    
    -- Signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal ascii_in : std_logic_vector((NUM_DIGITS * 8 - 1) downto 0);
    signal digit_selector : std_logic_vector(2 downto 0);  -- 3 bits for 5 digits (0-4)
    signal segments : std_logic_vector(0 to 13);
    
    -- Clock generation flag
    signal sim_done : boolean := false;
    
begin
    -- Clock generation
    clk_process: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- DUT instantiation
    uut: segment_multiplexor
        generic map (
            NUM_DIGITS => NUM_DIGITS,
            CLK_DIV_MAX => CLK_DIV_MAX
        )
        port map (
            clk => clk,
            ascii_in => ascii_in,
            reset => reset,
            digit_selector => digit_selector,
            segments => segments
        );
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initialize
        reset <= '1';
        -- Test string "HELLO" (5 ASCII characters)
        ascii_in <= X"48" & X"45" & X"4C" & X"4C" & X"4F";  -- H E L L O
        wait for CLK_PERIOD * 2;
        
        reset <= '0';
        
        -- Wait for first clock edge after reset and let signals settle
        wait until rising_edge(clk);
        wait for 1 ns;
        
        -- Let it cycle through all 5 digits multiple times
        report "Starting multiplexing through 5 digits...";
        for i in 0 to 2 loop  -- 3 complete cycles
            for digit in 0 to NUM_DIGITS-1 loop
                -- Report current state
                report "Cycle " & integer'image(i) & 
                       ", Digit: " & integer'image(to_integer(unsigned(digit_selector)));
                
                -- Verify digit_selector increments correctly
                assert to_integer(unsigned(digit_selector)) = digit
                    report "ERROR: Expected digit_selector = " & integer'image(digit) &
                           " but got " & integer'image(to_integer(unsigned(digit_selector)))
                    severity error;
                    
                wait until rising_edge(clk);
                wait for 1 ns;  -- Small delay for signal propagation
            end loop;
        end loop;
        
        -- Test reset functionality
        report "Testing reset...";
        reset <= '1';
        wait for CLK_PERIOD * 2;
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        
        assert to_integer(unsigned(digit_selector)) = 0
            report "ERROR: Reset did not return digit_selector to 0"
            severity error;
        
        -- Test with different ASCII string "12345"
        report "Testing with numeric string 12345...";
        ascii_in <= X"31" & X"32" & X"33" & X"34" & X"35";  -- 1 2 3 4 5
        
        for digit in 0 to NUM_DIGITS-1 loop
            report "Digit: " & integer'image(to_integer(unsigned(digit_selector)));
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        
        report "Testbench completed successfully!";
        sim_done <= true;
        wait;
    end process;

end Behavioral;
