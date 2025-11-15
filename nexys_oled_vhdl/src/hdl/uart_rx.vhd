----------------------------------------------------------------------------------
-- UART Receiver Module
-- Receives serial data at 9600 baud (8N1 format)
-- Clock: 100 MHz
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    Generic (
        CLK_FREQ   : integer := 100000000;  -- 100 MHz
        BAUD_RATE  : integer := 9600         -- 9600 baud
    );
    Port (
        clk        : in  std_logic;
        rstn       : in  std_logic;
        rx         : in  std_logic;
        rx_data    : out std_logic_vector(7 downto 0);
        rx_valid   : out std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is
    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;  -- ~10417 for 9600 baud
    
    type state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : state_type := IDLE;
    
    signal rx_sync      : std_logic_vector(2 downto 0) := (others => '1');
    signal clk_count    : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_index    : integer range 0 to 7 := 0;
    signal rx_byte      : std_logic_vector(7 downto 0) := (others => '0');
    
begin
    -- Synchronize RX input (prevent metastability)
    process(clk)
    begin
        if rising_edge(clk) then
            rx_sync <= rx_sync(1 downto 0) & rx;
        end if;
    end process;
    
    -- UART receiver state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                state <= IDLE;
                clk_count <= 0;
                bit_index <= 0;
                rx_valid <= '0';
                rx_data <= (others => '0');
            else
                rx_valid <= '0';  -- Default: no new data
                
                case state is
                    when IDLE =>
                        clk_count <= 0;
                        bit_index <= 0;
                        
                        -- Wait for start bit (falling edge)
                        if rx_sync(2) = '0' then
                            state <= START_BIT;
                        end if;
                    
                    when START_BIT =>
                        -- Wait until middle of start bit to confirm
                        if clk_count = CLKS_PER_BIT / 2 then
                            if rx_sync(2) = '0' then
                                clk_count <= 0;
                                state <= DATA_BITS;
                            else
                                -- False start bit
                                state <= IDLE;
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;
                    
                    when DATA_BITS =>
                        if clk_count = CLKS_PER_BIT - 1 then
                            clk_count <= 0;
                            
                            -- Sample the data bit
                            rx_byte(bit_index) <= rx_sync(2);
                            
                            if bit_index = 7 then
                                bit_index <= 0;
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        else
                            clk_count <= clk_count + 1;
                        end if;
                    
                    when STOP_BIT =>
                        if clk_count = CLKS_PER_BIT - 1 then
                            clk_count <= 0;
                            
                            -- Check for valid stop bit
                            if rx_sync(2) = '1' then
                                rx_data <= rx_byte;
                                rx_valid <= '1';
                            end if;
                            
                            state <= IDLE;
                        else
                            clk_count <= clk_count + 1;
                        end if;
                    
                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;
    
end Behavioral;
