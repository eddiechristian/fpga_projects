----------------------------------------------------------------------------------
-- Company: Digilent Inc. (Converted to VHDL)
-- Engineer: Arthur Brown (Original Verilog), Converted to VHDL
-- 
-- Module Name: delay_ms
-- Project Name: OLED Demo
-- Target Devices: Nexys Video
-- Description: Handles N-millisecond delays. On start flag, assert done after 
--              delay_time_ms milliseconds.
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity delay_ms is
    Port (
        clk            : in  std_logic;
        delay_time_ms  : in  std_logic_vector(11 downto 0);
        delay_start    : in  std_logic;
        delay_done     : out std_logic
    );
end delay_ms;

architecture Behavioral of delay_ms is
    type state_type is (Idle, Hold, Done);
    signal state : state_type := Idle;
    
    -- For 100 MHz clock: 100,000 cycles = 1ms
    constant MAX : integer := 99999;
    
    signal stop_time   : unsigned(11 downto 0) := (others => '0');
    signal ms_counter  : unsigned(11 downto 0) := (others => '0');
    signal clk_counter : unsigned(16 downto 0) := (others => '0');
    
begin
    delay_done <= '1' when (state = Idle and delay_start = '0') else '0';
    
    -- State machine
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
                when Idle =>
                    stop_time <= unsigned(delay_time_ms);
                    if delay_start = '1' then
                        state <= Hold;
                    end if;
                    
                when Hold =>
                    if ms_counter = stop_time and clk_counter = MAX then
                        if delay_start = '1' then
                            state <= Done;
                        else
                            state <= Idle;
                        end if;
                    end if;
                    
                when Done =>
                    if delay_start = '0' then
                        state <= Idle;
                    end if;
            end case;
        end if;
    end process;
    
    -- Counter management
    process(clk)
    begin
        if rising_edge(clk) then
            if state = Hold then
                if clk_counter = MAX then
                    clk_counter <= (others => '0');
                    if ms_counter = stop_time then
                        ms_counter <= (others => '0');
                    else
                        ms_counter <= ms_counter + 1;
                    end if;
                else
                    clk_counter <= clk_counter + 1;
                end if;
            else
                clk_counter <= (others => '0');
                ms_counter <= (others => '0');
            end if;
        end if;
    end process;
    
end Behavioral;
