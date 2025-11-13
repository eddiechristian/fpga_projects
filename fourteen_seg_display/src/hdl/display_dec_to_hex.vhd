library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_dec_to_hex is
    GENERIC(
        NUM_DIGITS: natural := 4
    );
    Port ( 
        decimal_num: in std_logic_vector((NUM_DIGITS*4 - 1) downto 0);  -- NUM_DIGITS hex digits (4 bits each)
        hex_ascii_digit_out: out std_logic_vector((NUM_DIGITS*8 - 1) downto 0);  -- NUM_DIGITS ASCII characters (8 bits each)
        blank_digits: out std_logic_vector((NUM_DIGITS - 1) downto 0)  -- bitmask for blanking digits
    );
end display_dec_to_hex;

architecture Behavioral of display_dec_to_hex is
    -- Function to convert a 4-bit hex value to ASCII
    function hex_to_ascii(hex_val : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable ascii : std_logic_vector(7 downto 0);
    begin
        case hex_val is
            when "0000" => ascii := x"30";  -- '0'
            when "0001" => ascii := x"31";  -- '1'
            when "0010" => ascii := x"32";  -- '2'
            when "0011" => ascii := x"33";  -- '3'
            when "0100" => ascii := x"34";  -- '4'
            when "0101" => ascii := x"35";  -- '5'
            when "0110" => ascii := x"36";  -- '6'
            when "0111" => ascii := x"37";  -- '7'
            when "1000" => ascii := x"38";  -- '8'
            when "1001" => ascii := x"39";  -- '9'
            when "1010" => ascii := x"41";  -- 'A'
            when "1011" => ascii := x"42";  -- 'B'
            when "1100" => ascii := x"43";  -- 'C'
            when "1101" => ascii := x"44";  -- 'D'
            when "1110" => ascii := x"45";  -- 'E'
            when "1111" => ascii := x"46";  -- 'F'
            when others => ascii := x"30";  -- Default to '0'
        end case;
        return ascii;
    end function;
    
begin
    process(decimal_num)
        variable decimal_unsigned : unsigned((NUM_DIGITS*4 - 1) downto 0);
    begin
        -- Convert each nibble to ASCII
        -- MSB first (left) to LSB last (right)
        for i in 0 to NUM_DIGITS-1 loop
            hex_ascii_digit_out((NUM_DIGITS-i)*8 - 1 downto (NUM_DIGITS-i-1)*8) <= 
                hex_to_ascii(decimal_num((NUM_DIGITS-i)*4 - 1 downto (NUM_DIGITS-i-1)*4));
        end loop;
        
        -- Convert to unsigned for comparison
        decimal_unsigned := unsigned(decimal_num);
        
        -- Determine which digits to blank based on value
        -- Generic logic that works for any NUM_DIGITS
        for i in 0 to NUM_DIGITS-1 loop
            -- Calculate threshold: 16^(i+1) - 1
            -- If value > threshold, show digit at position (NUM_DIGITS-1-i)
            if decimal_unsigned > to_unsigned(16**(i+1) - 1, NUM_DIGITS*4) then
                blank_digits(NUM_DIGITS-1-i) <= '0';  -- Show this digit
            else
                blank_digits(NUM_DIGITS-1-i) <= '1';  -- Blank this digit
            end if;
        end loop;
    end process;

end Behavioral;
