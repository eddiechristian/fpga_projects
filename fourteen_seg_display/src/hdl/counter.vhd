library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- Required for unsigned/signed arithmetic operations

entity counter is
 GENERIC(
        WIDTH: natural := 8
    );
    Port (
        clk   : in  std_logic;
        reset : in  std_logic;
        count : out std_logic_vector ((WIDTH-1) downto 0) -- WIDTH -bit output
    );
end counter;



architecture Behavioral of counter is
    signal current_count : unsigned ((WIDTH-1) downto 0) := (others => '0'); -- Internal signal for counting
begin

    process (clk, reset)
    begin
        if reset = '1' then
            current_count <= (others => '0'); -- Reset to 0
        elsif rising_edge(clk) then
            current_count <= current_count + 1; -- Increment on rising clock edge
        end if;
    end process;

    count <= std_logic_vector(current_count); -- Assign the internal count to the output port

end Behavioral;