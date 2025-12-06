library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_module_tb is
end top_module_tb;

architecture Behavioral of top_module_tb is

    component top_module is
        Port (
            clk     : in  std_logic;
            reset   : in  std_logic;
            led     : out std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal led : std_logic;

    constant clk_period : time := 10 ns; -- 100 MHz

begin

    uut: top_module port map (
        clk => clk,
        reset => reset,
        led => led
    );

    clk <= not clk after clk_period / 2;

    process
    begin
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 2000 ns;
        wait;
    end process;

end Behavioral;
