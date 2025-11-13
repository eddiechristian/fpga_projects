library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ascii_to_14seg is
    Port ( 
        ascii_in : in STD_LOGIC_VECTOR(7 downto 0);  -- ASCII input character
        segments : out STD_LOGIC_VECTOR(13 downto 0) -- 14-segment output
    );
end ascii_to_14seg;

architecture Behavioral of ascii_to_14seg is
    -- 14-segment display mapping:
    -- segments(13 downto 0) = (a1, a2, b, c, d1, d2, e, f, g1, g2, h, i, j, k)
    --
    --       a1  a2
    --      ___  ___
    --  f |  |i |j|  | b
    --     |__g1_g2__|
    --  e |  |h |k|  | c
    --     |___  ___|
    --       d1  d2
    --
    -- Active high: '1' = segment on, '0' = segment off
    
begin
    process(ascii_in)
    begin
        case ascii_in is
            -- Numbers 0-9
            when X"30" => segments <= "11110011110000"; -- '0'
            when X"31" => segments <= "00010010010000"; -- '1'
            when X"32" => segments <= "11011001101000"; -- '2'
            when X"33" => segments <= "11011011001000"; -- '3'
            when X"34" => segments <= "00111010001000"; -- '4'
            when X"35" => segments <= "11101011000100"; -- '5'
            when X"36" => segments <= "11101011100100"; -- '6'
            when X"37" => segments <= "11010010000000"; -- '7'
            when X"38" => segments <= "11111011101100"; -- '8'
            when X"39" => segments <= "11111011001000"; -- '9'
            
            -- Uppercase letters A-Z
            when X"41" => segments <= "11111010101100"; -- 'A'
            when X"42" => segments <= "11011011001011"; -- 'B'
            when X"43" => segments <= "11100001100000"; -- 'C'
            when X"44" => segments <= "11011011000011"; -- 'D'
            when X"45" => segments <= "11101001100100"; -- 'E'
            when X"46" => segments <= "11101000100100"; -- 'F'
            when X"47" => segments <= "11101011100000"; -- 'G'
            when X"48" => segments <= "00111010101100"; -- 'H'
            when X"49" => segments <= "11001001000011"; -- 'I'
            when X"4A" => segments <= "00011011100000"; -- 'J'
            when X"4B" => segments <= "00101000100110"; -- 'K'
            when X"4C" => segments <= "00100001100000"; -- 'L'
            when X"4D" => segments <= "00110110100100"; -- 'M'
            when X"4E" => segments <= "00110110101000"; -- 'N'
            when X"4F" => segments <= "11110011100000"; -- 'O'
            when X"50" => segments <= "11111000101100"; -- 'P'
            when X"51" => segments <= "11110011101000"; -- 'Q'
            when X"52" => segments <= "11111000101110"; -- 'R'
            when X"53" => segments <= "11101011001100"; -- 'S'
            when X"54" => segments <= "11001000000011"; -- 'T'
            when X"55" => segments <= "00110011100000"; -- 'U'
            when X"56" => segments <= "00100000100110"; -- 'V'
            when X"57" => segments <= "00110010101010"; -- 'W'
            when X"58" => segments <= "00000100000110"; -- 'X'
            when X"59" => segments <= "00000100000101"; -- 'Y'
            when X"5A" => segments <= "11000001000110"; -- 'Z'
            
            -- Special characters
            when X"20" => segments <= "00000000000000"; -- space
            when X"2D" => segments <= "00001000001000"; -- '-' (minus/dash)
            when X"5F" => segments <= "00000001000000"; -- '_' (underscore)
            when X"3D" => segments <= "00001001001000"; -- '=' (equals)
            when X"2B" => segments <= "00001000001011"; -- '+' (plus)
            when X"2A" => segments <= "00001100001111"; -- '*' (asterisk)
            when X"2F" => segments <= "00000000000110"; -- '/' (forward slash)
            when X"5C" => segments <= "00000100001000"; -- '\' (backslash)
            when X"3F" => segments <= "11011000000001"; -- '?' (question mark)
            when X"21" => segments <= "11010000000001"; -- '!' (exclamation)
            when X"2E" => segments <= "00000000000000"; -- '.' (period)
            
            -- Default case - all segments off
            when others => segments <= "00000000000000";
        end case;
    end process;

end Behavioral;
