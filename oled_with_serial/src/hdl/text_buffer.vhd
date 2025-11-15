----------------------------------------------------------------------------------
-- Text Buffer Module
-- Stores incoming serial characters and manages scrolling display
-- Buffer size: 256 characters (16 lines of 16 chars each for scrolling)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity text_buffer is
    Port (
        clk           : in  std_logic;
        rstn          : in  std_logic;
        
        -- UART interface
        rx_data       : in  std_logic_vector(7 downto 0);
        rx_valid      : in  std_logic;
        
        -- Display interface (4 rows x 16 chars)
        disp_row      : in  integer range 0 to 3;
        disp_col      : in  integer range 0 to 15;
        disp_char     : out std_logic_vector(7 downto 0);
        
        -- Scrolling control
        scroll_trigger : in std_logic;  -- Pulse to scroll one line
        has_data       : out std_logic  -- Indicates buffer has received data
    );
end text_buffer;

architecture Behavioral of text_buffer is
    -- Buffer storage: 256 characters (16 lines x 16 chars)
    type buffer_array_type is array (0 to 255) of std_logic_vector(7 downto 0);
    signal buffer_ram : buffer_array_type := (others => x"20");  -- Initialize with spaces
    
    signal write_ptr     : unsigned(7 downto 0) := (others => '0');  -- Circular write pointer
    signal scroll_offset : unsigned(3 downto 0) := (others => '0');  -- Line offset (0-15)
    signal data_received : std_logic := '0';
    
    signal read_addr : integer range 0 to 255;
    
begin
    has_data <= data_received;
    
    -- Write process: store incoming characters
    process(clk)
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                write_ptr <= (others => '0');
                data_received <= '0';
                -- Clear buffer
                for i in 0 to 255 loop
                    buffer_ram(i) <= x"20";  -- Space character
                end loop;
            else
                if rx_valid = '1' then
                    data_received <= '1';
                    
                    -- Handle special characters
                    if rx_data = x"0D" or rx_data = x"0A" then
                        -- Carriage return or line feed: move to next line
                        -- Round up to next multiple of 16
                        write_ptr <= (write_ptr(7 downto 4) + 1) & "0000";
                    elsif rx_data = x"08" then
                        -- Backspace: move back one position
                        if write_ptr /= 0 then
                            write_ptr <= write_ptr - 1;
                            buffer_ram(to_integer(write_ptr - 1)) <= x"20";  -- Clear with space
                        end if;
                    elsif rx_data >= x"20" and rx_data <= x"7E" then
                        -- Printable ASCII character
                        buffer_ram(to_integer(write_ptr)) <= rx_data;
                        write_ptr <= write_ptr + 1;
                    end if;
                end if;
                
                -- Handle scroll trigger
                if scroll_trigger = '1' and data_received = '1' then
                    scroll_offset <= scroll_offset + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Read process: provide characters for display
    -- Maps display position (row 0-3, col 0-15) to buffer with scrolling
    process(disp_row, disp_col, scroll_offset)
        variable display_line : unsigned(3 downto 0);
        variable buffer_line  : unsigned(3 downto 0);
    begin
        -- Calculate which line to display (with wrapping)
        display_line := to_unsigned(disp_row, 4);
        buffer_line := display_line + scroll_offset;
        
        -- Calculate buffer address
        read_addr <= to_integer(buffer_line & to_unsigned(disp_col, 4));
    end process;
    
    -- Output character from buffer
    disp_char <= buffer_ram(read_addr);
    
end Behavioral;
