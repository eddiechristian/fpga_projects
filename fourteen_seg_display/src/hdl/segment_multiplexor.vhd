----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/10/2025 09:16:10 PM
-- Design Name: 
-- Module Name: segment_multiplexor - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity segment_multiplexor is
  GENERIC(
        NUM_DIGITS: natural := 4;
        CLK_DIV_MAX: natural := 1  -- Number of clock cycles before digit changes
    );
    Port (
        clk   : in  std_logic;
        ascii_in : in STD_LOGIC_VECTOR(((NUM_DIGITS * 8) -1) downto 0);  -- ASCII input character
        reset : in  std_logic;
        digit_selector: out STD_LOGIC_VECTOR((integer(ceil(log2(real(NUM_DIGITS))))-1) downto 0);
        segments : out STD_LOGIC_VECTOR(0 to 13) -- 14-segment output (A=0, B=1, ...P=13)
    );
end segment_multiplexor;

architecture Behavioral of segment_multiplexor is
    constant SELECTOR_WIDTH : natural := integer(ceil(log2(real(NUM_DIGITS))));
    constant DIVIDER_WIDTH : natural := integer(ceil(log2(real(CLK_DIV_MAX))));
    
    signal digit_sel : unsigned (SELECTOR_WIDTH-1 downto 0) := (others => '0'); -- Digit selector
    signal clk_divider : unsigned (DIVIDER_WIDTH-1 downto 0) := (others => '0'); -- Clock divider counter
    signal current_ascii : std_logic_vector(7 downto 0);
    signal segments_internal : std_logic_vector(0 to 13); -- Internal signal before inversion
    
    -- Component declaration
    component ascii_to_14seg
        Port ( 
            ascii_in : in STD_LOGIC_VECTOR(7 downto 0);
            segments : out STD_LOGIC_VECTOR(0 to 13)
        );
    end component;
    
begin
    process (clk, reset)
    begin
        if reset = '1' then
            digit_sel <= (others => '0'); -- Reset digit selector
            clk_divider <= (others => '0'); -- Reset clock divider
        elsif rising_edge(clk) then
            if clk_divider = CLK_DIV_MAX - 1 then
                clk_divider <= (others => '0'); -- Reset divider counter
                -- Increment digit selector when divider reaches max
                if digit_sel = NUM_DIGITS - 1 then
                    digit_sel <= (others => '0'); -- Wrap around
                else
                    digit_sel <= digit_sel + 1; -- Increment
                end if;
            else
                clk_divider <= clk_divider + 1; -- Increment divider counter
            end if;
        end if;
    end process;
    
    digit_selector <= std_logic_vector(digit_sel);
    
    -- Select the appropriate 8-bit ASCII character from ascii_in
    process(ascii_in, digit_sel)
        variable idx : integer;
    begin
        idx := to_integer(digit_sel);
        current_ascii <= ascii_in((idx+1)*8-1 downto idx*8);
    end process;
    
    -- Instantiate ascii to 14-segment decoder
    ascii_decoder: ascii_to_14seg
        port map (
            ascii_in => current_ascii,
            segments => segments_internal
        );
    
    -- Invert segments for common-anode display (active-low)
    -- LTP-3786E requires pulling segments LOW to turn them ON
    segments <= not segments_internal;
        
end Behavioral;
