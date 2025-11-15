library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ascii_to_14seg is
    Port ( 
        ascii_in : in STD_LOGIC_VECTOR(7 downto 0);  -- ASCII input character
        segments : out STD_LOGIC_VECTOR(0 to 13)     -- 14-segment output
    );
end ascii_to_14seg;

architecture Behavioral of ascii_to_14seg is
    -- LTP-3786E Full 14-segment display mapping:
    -- Bit positions: "ABCDEFGHJKLMNP"
    -- segments(0 to 13)  ← Note: ascending order!
    --
    --           A              Bit Mapping:
    --        ───────           bit  0 = A (Top horizontal)
    --      │ \  G  / │         bit  1 = B (Top-right vertical)
    --    F │  \ | /  │ B       bit  2 = C (Bottom-right vertical)
    --      │ P \|/ H │         bit  3 = D (Bottom horizontal)
    --        ─N─ ─J─           bit  4 = E (Bottom-left vertical)
    --      │ M /|\ K │         bit  5 = F (Top-left vertical)
    --    E │  / | \  │ C       bit  6 = G (Center-top vertical)
    --      │ /  L  \ │         bit  7 = H (Top-right diagonal)
    --        ───────           bit  8 = J (Middle-right horizontal)
    --           D              bit  9 = K (Bottom-right diagonal)
    --                          bit 10 = L (Center-bottom vertical)
    --                          bit 11 = M (Bottom-left diagonal)
    --                          bit 12 = N (Middle-left horizontal)
    --                          bit 13 = P (Top-left diagonal)
    -- Active high: '1' = segment on, '0' = segment off
    
begin
    process(ascii_in)
    begin
        case ascii_in is
            -- Numbers 0-9
            -- Format: "ABCDEFGHJKLMNP"
            when X"30" => segments <= "11111100000000"; -- '0' = A B C D E F (outer rectangle)
            when X"31" => segments <= "01100000000000"; -- '1' = B C
            when X"32" => segments <= "11011000100010"; -- '2' = A B D E N J
            when X"33" => segments <= "11110000100010"; -- '3' = A B C D N J
            when X"34" => segments <= "01100100100010"; -- '4' = B C F N J
            when X"35" => segments <= "10110100100010"; -- '5' = A C D F N J
            when X"36" => segments <= "10111100100010"; -- '6' = A C D E F N J
            when X"37" => segments <= "11100000000000"; -- '7' = A B C
            when X"38" => segments <= "11111100100010"; -- '8' = A B C D E F N J
            when X"39" => segments <= "11110100100010"; -- '9' = A B C D F N J
            
            -- Uppercase letters A-Z
            -- Format: "ABCDEFGHJKLMNP"
            when X"41" => segments <= "11101100100010"; -- 'A' = A B C E F N J
            when X"42" => segments <= "11110010001000"; -- 'B' = A B C D G L
            when X"43" => segments <= "10011100000000"; -- 'C' = A D E F
            when X"44" => segments <= "11110010001000"; -- 'D' = A B C D G L
            when X"45" => segments <= "10011100100010"; -- 'E' = A D E F N J
            when X"46" => segments <= "10001100100010"; -- 'F' = A E F N J
            when X"47" => segments <= "10111100100000"; -- 'G' = A C D E F J
            when X"48" => segments <= "01101100100010"; -- 'H' = B C E F N J
            when X"49" => segments <= "10010010001000"; -- 'I' = A D G L
            when X"4A" => segments <= "01111000000000"; -- 'J' = B C D E
            when X"4B" => segments <= "00001110010100"; -- 'K' = E F H K
            when X"4C" => segments <= "00010111000000"; -- 'L' = D E F
            when X"4D" => segments <= "01101110010001"; -- 'M' = B C E F H P
            when X"4E" => segments <= "01101110000101"; -- 'N' = B C E F K P
            when X"4F" => segments <= "11110111000000"; -- 'O' = A B C D E F
            when X"50" => segments <= "11001100100010"; -- 'P' = A B E F N J
            when X"51" => segments <= "11110111000100"; -- 'Q' = A B C D E F K
            when X"52" => segments <= "11001100110010"; -- 'R' = A B E F N J K
            when X"53" => segments <= "10110100100010"; -- 'S' = A C D F N J
            when X"54" => segments <= "10000010001000"; -- 'T' = A G L
            when X"55" => segments <= "01111100000000"; -- 'U' = B C D E F
            when X"56" => segments <= "00001101000100"; -- 'V' = E F M H
            when X"57" => segments <= "01101100010100"; -- 'W' = B C E F K M
            when X"58" => segments <= "00000001010101"; -- 'X' = H K M P - all 4 diagonals
            when X"59" => segments <= "00000001001001"; -- 'Y' = H L P - Y shape
            when X"5A" => segments <= "10010001000100"; -- 'Z' = A D H M
            
            -- Special characters
            -- Format: "ABCDEFGHJKLMNP"
            when X"20" => segments <= "00000000000000"; -- space
            when X"2D" => segments <= "00000000100010"; -- '-' (minus) = N J
            when X"5F" => segments <= "00010000000000"; -- '_' (underscore) = D
            when X"3D" => segments <= "00010000100010"; -- '=' (equals) = D N J
            when X"2B" => segments <= "00000000100111"; -- '+' (plus) = N J G L P
            when X"2A" => segments <= "00000000110111"; -- '*' (asterisk) = N J H K M P (all diagonals)
            when X"2F" => segments <= "00000000000110"; -- '/' = M H
            when X"5C" => segments <= "00000000000101"; -- '\' (backslash) = K P
            when X"3F" => segments <= "11000000100010"; -- '?' = A B N J
            when X"21" => segments <= "10000000100111"; -- '!' = A G L P
            when X"2E" => segments <= "00000000000000"; -- '.' (period) - could use bit for DP if available
            
            -- Default case - all segments off
            when others => segments <= "00000000000000";
        end case;
    end process;

end Behavioral;
