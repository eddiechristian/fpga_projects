----------------------------------------------------------------------------------
-- Company: Digilent Inc. (Converted to VHDL)
-- Engineer: Arthur Brown (Original Verilog), Converted to VHDL
-- 
-- Module Name: spi_ctrl
-- Project Name: OLED Demo
-- Description: SPI Controller. Sends a data byte on start flag.
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_ctrl is
    Port (
        clk        : in  std_logic;
        send_start : in  std_logic;
        send_data  : in  std_logic_vector(7 downto 0);
        send_ready : out std_logic;
        CS         : out std_logic;
        SDO        : out std_logic;
        SCLK       : out std_logic
    );
end spi_ctrl;

architecture Behavioral of spi_ctrl is
    type state_type is (Idle, Send, HoldCS, Hold);
    signal state : state_type := Idle;
    
    constant COUNTER_MID : integer := 4;
    constant COUNTER_MAX : integer := 9;
    constant SCLK_DUTY   : integer := 5;
    
    signal shift_register : std_logic_vector(7 downto 0) := (others => '0');
    signal shift_counter  : unsigned(3 downto 0) := (others => '0');
    signal counter        : unsigned(4 downto 0) := (others => '0');
    signal temp_sdo       : std_logic := '0';
    signal cs_i           : std_logic := '1';
    
begin
    -- Output assignments
    SCLK <= '1' when (counter < SCLK_DUTY or cs_i = '1') else '0';
    SDO  <= '1' when (temp_sdo = '1' or cs_i = '1' or state = HoldCS) else '0';
    CS   <= '0' when (state = Send or state = HoldCS) else '1';
    cs_i <= '0' when (state = Send or state = HoldCS) else '1';
    send_ready <= '1' when (state = Idle and send_start = '0') else '0';
    
    -- State machine
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
                when Idle =>
                    if send_start = '1' then
                        state <= Send;
                    end if;
                    
                when Send =>
                    if shift_counter = 8 and counter = COUNTER_MID then
                        state <= HoldCS;
                    end if;
                    
                when HoldCS =>
                    if shift_counter = 3 then
                        state <= Hold;
                    end if;
                    
                when Hold =>
                    if send_start = '0' then
                        state <= Idle;
                    end if;
            end case;
        end if;
    end process;
    
    -- Counter management
    process(clk)
    begin
        if rising_edge(clk) then
            if state = Send and not (counter = COUNTER_MID and shift_counter = 8) then
                if counter = COUNTER_MAX then
                    counter <= (others => '0');
                else
                    counter <= counter + 1;
                end if;
            else
                counter <= (others => '0');
            end if;
        end if;
    end process;
    
    -- Shift register and data management
    process(clk)
    begin
        if rising_edge(clk) then
            if state = Idle then
                shift_counter <= (others => '0');
                shift_register <= send_data;
                temp_sdo <= '1';
            elsif state = Send then
                if counter = COUNTER_MID then
                    temp_sdo <= shift_register(7);
                    shift_register <= shift_register(6 downto 0) & '0';
                    if shift_counter = 8 then
                        shift_counter <= (others => '0');
                    else
                        shift_counter <= shift_counter + 1;
                    end if;
                end if;
            elsif state = HoldCS then
                shift_counter <= shift_counter + 1;
            end if;
        end if;
    end process;
    
end Behavioral;
