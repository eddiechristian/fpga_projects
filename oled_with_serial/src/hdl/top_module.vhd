----------------------------------------------------------------------------------
-- Company: Digilent Inc. (Converted to VHDL)
-- Engineer: Arthur Brown (Original Verilog), Converted to VHDL
-- 
-- Create Date: 10/1/2016 (Converted 2025)
-- Module Name: oled_master
-- Project Name: OLED Demo
-- Target Devices: Nexys Video
-- Description: Creates OLED Demo, handles user inputs to operate OLED control module
-- 
-- Dependencies: oled_ctrl.vhd, delay_ms.vhd
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port (
        clk        : in  std_logic;
        rstn       : in  std_logic;
        uart_rxd   : in  std_logic;  -- Serial input
        led        : out std_logic_vector(3 downto 0);  -- Debug LEDs
        oled_sdin  : out std_logic;
        oled_sclk  : out std_logic;
        oled_dc    : out std_logic;
        oled_res   : out std_logic;
        oled_vbat  : out std_logic;
        oled_vdd   : out std_logic
    );
end top_module;

architecture Behavioral of oled_master is
    -- State definitions
    type state_type is (
        Idle, Init,
        ActiveWriteAlpha, ActiveUpdateAlpha, ActiveDelayAlpha,
        ActiveWriteSplash, ActiveUpdateSplash, ActiveDelaySplash,
        SerialMode, SerialWrite, SerialUpdate, SerialDelay,
        ActiveWait, Done,
        Write, WriteWait, UpdateWait, DelayWait,
        FullDisp
    );
    signal state : state_type := Idle;
    signal after_state : state_type := Idle;
    
    signal count : unsigned(5 downto 0) := (others => '0');
    
    -- Screen select constants
    constant SPLASH : std_logic := '1';
    constant ALPHA  : std_logic := '0';
    constant SERIAL : std_logic := '0';  -- Use same as ALPHA for now
    signal screen_select : std_logic := ALPHA;
    
    -- Text strings for display
    -- SPLASH screen text
    constant splash_str1 : string := "Connect serial  ";
    constant splash_str2 : string := "to computer and ";
    constant splash_str3 : string := "type. What you  ";
    constant splash_str4 : string := "type shows here.";
    -- ALPHA screen text
    constant alpha_str1  : string := "ABCDEFGHIJKLMNOP";
    constant alpha_str2  : string := "QRSTUVWXYZabcdef";
    constant alpha_str3  : string := "ghijklmnopqrstuv";
    constant alpha_str4  : string := "wxyz0123456789  ";
    
    signal rst : std_logic;
    
    -- Delay module signals
    signal delay_start    : std_logic := '0';
    signal delay_time_ms  : std_logic_vector(11 downto 0) := (others => '0');
    signal delay_done     : std_logic;
    
    -- OLED Controller signals
    signal update_start       : std_logic := '0';
    signal update_clear       : std_logic := '0';
    signal update_ready       : std_logic;
    signal disp_on_start      : std_logic := '0';
    signal disp_on_ready      : std_logic;
    signal disp_off_start     : std_logic := '0';
    signal disp_off_ready     : std_logic;
    signal toggle_disp_start  : std_logic := '0';
    signal toggle_disp_ready  : std_logic;
    signal write_start        : std_logic := '0';
    signal write_ready        : std_logic;
    signal write_base_addr    : std_logic_vector(8 downto 0) := (others => '0');
    signal write_ascii_data   : std_logic_vector(7 downto 0) := (others => '0');
    
    signal init_done  : std_logic;
    signal init_ready : std_logic;
    
    signal once : std_logic := '1';
    
    -- UART signals
    signal rx_data    : std_logic_vector(7 downto 0);
    signal rx_valid   : std_logic;
    
    -- Text buffer signals
    signal disp_row       : integer range 0 to 3;
    signal disp_col       : integer range 0 to 15;
    signal disp_char      : std_logic_vector(7 downto 0);
    signal scroll_trigger : std_logic := '0';
    signal has_data       : std_logic;
    
    -- Scrolling control
    signal scroll_counter : unsigned(26 downto 0) := (others => '0');  -- ~1.3s at 100MHz
    constant SCROLL_DELAY : unsigned(26 downto 0) := to_unsigned(100000000, 27);  -- 1 second
    signal serial_mode_active : std_logic := '0';
    
    -- Components
    component oled_ctrl
        Port (
            clk                : in  std_logic;
            write_start        : in  std_logic;
            write_ascii_data   : in  std_logic_vector(7 downto 0);
            write_base_addr    : in  std_logic_vector(8 downto 0);
            write_ready        : out std_logic;
            update_start       : in  std_logic;
            update_clear       : in  std_logic;
            update_ready       : out std_logic;
            disp_on_start      : in  std_logic;
            disp_on_ready      : out std_logic;
            disp_off_start     : in  std_logic;
            disp_off_ready     : out std_logic;
            toggle_disp_start  : in  std_logic;
            toggle_disp_ready  : out std_logic;
            SDIN               : out std_logic;
            SCLK               : out std_logic;
            DC                 : out std_logic;
            RES                : out std_logic;
            VBAT               : out std_logic;
            VDD                : out std_logic
        );
    end component;
    
    component delay_ms
        Port (
            clk            : in  std_logic;
            delay_time_ms  : in  std_logic_vector(11 downto 0);
            delay_start    : in  std_logic;
            delay_done     : out std_logic
        );
    end component;
    
    component uart_rx
        Generic (
            CLK_FREQ   : integer := 100000000;
            BAUD_RATE  : integer := 9600
        );
        Port (
            clk        : in  std_logic;
            rstn       : in  std_logic;
            rx         : in  std_logic;
            rx_data    : out std_logic_vector(7 downto 0);
            rx_valid   : out std_logic
        );
    end component;
    
    component text_buffer
        Port (
            clk           : in  std_logic;
            rstn          : in  std_logic;
            rx_data       : in  std_logic_vector(7 downto 0);
            rx_valid      : in  std_logic;
            disp_row      : in  integer range 0 to 3;
            disp_col      : in  integer range 0 to 15;
            disp_char     : out std_logic_vector(7 downto 0);
            scroll_trigger : in std_logic;
            has_data       : out std_logic
        );
    end component;
    
    -- Function to get ASCII character from string based on address
    function get_char(str : string; y : integer; x : integer) return std_logic_vector is
        variable char_index : integer;
    begin
        char_index := x + 1;  -- Strings in VHDL are 1-indexed
        if char_index > str'length or char_index < 1 then
            return x"20";  -- Return space if out of bounds
        else
            return std_logic_vector(to_unsigned(character'pos(str(char_index)), 8));
        end if;
    end function;
    
begin
    rst <= not rstn;
    
    -- Debug LEDs
    led(0) <= rx_valid;           -- Blinks when UART receives data
    led(1) <= serial_mode_active; -- ON when in serial mode
    led(2) <= has_data;           -- ON when buffer has received data
    led(3) <= uart_rxd;           -- Shows RX line state
    
    -- Parse ready signals for clarity
    init_done  <= disp_off_ready or toggle_disp_ready or write_ready or update_ready;
    init_ready <= disp_on_ready;
    
    -- OLED Controller instantiation
    OLED_INST : oled_ctrl
        port map (
            clk               => clk,
            write_start       => write_start,
            write_ascii_data  => write_ascii_data,
            write_base_addr   => write_base_addr,
            write_ready       => write_ready,
            update_start      => update_start,
            update_ready      => update_ready,
            update_clear      => update_clear,
            disp_on_start     => disp_on_start,
            disp_on_ready     => disp_on_ready,
            disp_off_start    => disp_off_start,
            disp_off_ready    => disp_off_ready,
            toggle_disp_start => toggle_disp_start,
            toggle_disp_ready => toggle_disp_ready,
            SDIN              => oled_sdin,
            SCLK              => oled_sclk,
            DC                => oled_dc,
            RES               => oled_res,
            VBAT              => oled_vbat,
            VDD               => oled_vdd
        );
    
    -- Delay module instantiation
    DELAY_INST : delay_ms
        port map (
            clk           => clk,
            delay_time_ms => delay_time_ms,
            delay_start   => delay_start,
            delay_done    => delay_done
        );
    
    -- UART receiver instantiation
    UART_INST : uart_rx
        generic map (
            CLK_FREQ  => 100000000,
            BAUD_RATE => 9600
        )
        port map (
            clk       => clk,
            rstn      => rstn,
            rx        => uart_rxd,
            rx_data   => rx_data,
            rx_valid  => rx_valid
        );
    
    -- Text buffer instantiation
    TEXT_BUF_INST : text_buffer
        port map (
            clk            => clk,
            rstn           => rstn,
            rx_data        => rx_data,
            rx_valid       => rx_valid,
            disp_row       => disp_row,
            disp_col       => disp_col,
            disp_char      => disp_char,
            scroll_trigger => scroll_trigger,
            has_data       => has_data
        );
    
    -- Combinatorial logic for ASCII data selection
    process(write_base_addr, screen_select, serial_mode_active, disp_char)
        variable y_pos : integer;
        variable x_pos : integer;
    begin
        y_pos := to_integer(unsigned(write_base_addr(8 downto 7)));
        x_pos := to_integer(unsigned(write_base_addr(6 downto 3)));
        
        disp_row <= y_pos;
        disp_col <= x_pos;
        
        if serial_mode_active = '1' then
            -- Serial mode: use text buffer
            write_ascii_data <= disp_char;
        elsif screen_select = SPLASH then
            case y_pos is
                when 0      => write_ascii_data <= get_char(splash_str1, 0, x_pos);
                when 1      => write_ascii_data <= get_char(splash_str2, 1, x_pos);
                when 2      => write_ascii_data <= get_char(splash_str3, 2, x_pos);
                when 3      => write_ascii_data <= get_char(splash_str4, 3, x_pos);
                when others => write_ascii_data <= x"20";  -- Space
            end case;
        else  -- ALPHA
            case y_pos is
                when 0      => write_ascii_data <= get_char(alpha_str1, 0, x_pos);
                when 1      => write_ascii_data <= get_char(alpha_str2, 1, x_pos);
                when 2      => write_ascii_data <= get_char(alpha_str3, 2, x_pos);
                when 3      => write_ascii_data <= get_char(alpha_str4, 3, x_pos);
                when others => write_ascii_data <= x"20";  -- Space
            end case;
        end if;
    end process;
    
    -- Scrolling control process
    process(clk)
    begin
        if rising_edge(clk) then
            if rstn = '0' or serial_mode_active = '0' then
                scroll_counter <= (others => '0');
                scroll_trigger <= '0';
            else
                scroll_trigger <= '0';  -- Default
                
                if scroll_counter >= SCROLL_DELAY then
                    scroll_counter <= (others => '0');
                    scroll_trigger <= '1';  -- Trigger scroll
                else
                    scroll_counter <= scroll_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Main state machine
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
                when Idle =>
                    if (rst = '1' or once = '1') and init_ready = '1' then
                        disp_on_start <= '1';
                        state <= Init;
                        once <= '0';
                    end if;
                
                when Init =>
                    disp_on_start <= '0';
                    if rst = '0' and init_done = '1' then
                        state <= ActiveWriteAlpha;
                    end if;
                
                when ActiveWriteAlpha =>
                    write_start <= '1';
                    write_base_addr <= (others => '0');
                    screen_select <= ALPHA;
                    after_state <= ActiveUpdateAlpha;
                    state <= WriteWait;
                
                when ActiveUpdateAlpha =>
                    after_state <= ActiveDelayAlpha;
                    state <= UpdateWait;
                    update_start <= '1';
                    update_clear <= '0';
                
                when ActiveDelayAlpha =>
                    after_state <= ActiveWriteSplash;
                    state <= DelayWait;
                    delay_start <= '1';
                    delay_time_ms <= x"FA0";  -- 4000 decimal
                
                when ActiveWriteSplash =>
                    write_start <= '1';
                    write_base_addr <= (others => '0');
                    screen_select <= SPLASH;
                    after_state <= ActiveUpdateSplash;
                    state <= WriteWait;
                
                when ActiveUpdateSplash =>
                    after_state <= ActiveDelaySplash;
                    state <= UpdateWait;
                    update_start <= '1';
                    update_clear <= '0';
                
                when ActiveDelaySplash =>
                    after_state <= SerialMode;
                    state <= DelayWait;
                    delay_start <= '1';
                    delay_time_ms <= x"BB8";  -- 3000 ms = 3 seconds
                
                when SerialMode =>
                    -- Enter serial mode - continuously refresh display
                    serial_mode_active <= '1';
                    state <= SerialWrite;
                
                when SerialWrite =>
                    write_start <= '1';
                    write_base_addr <= (others => '0');
                    after_state <= SerialUpdate;
                    state <= WriteWait;
                
                when SerialUpdate =>
                    after_state <= SerialDelay;
                    state <= UpdateWait;
                    update_start <= '1';
                    update_clear <= '0';
                
                when SerialDelay =>
                    after_state <= SerialMode;
                    state <= DelayWait;
                    delay_start <= '1';
                    delay_time_ms <= x"032";  -- 50 ms refresh rate
                
                when ActiveWait =>
                    if rst = '1' and disp_off_ready = '1' then
                        disp_off_start <= '1';
                        state <= Done;
                    end if;
                
                when Write =>
                    write_start <= '1';
                    write_base_addr <= std_logic_vector(unsigned(write_base_addr) + 8);
                    state <= WriteWait;
                
                when DelayWait =>
                    delay_start <= '0';
                    if delay_done = '1' then
                        state <= after_state;
                    end if;
                
                when WriteWait =>
                    write_start <= '0';
                    if write_ready = '1' then
                        if write_base_addr = "111111000" then  -- 0x1F8
                            state <= after_state;
                        else
                            state <= Write;
                        end if;
                    end if;
                
                when UpdateWait =>
                    update_start <= '0';
                    if update_ready = '1' then
                        state <= after_state;
                    end if;
                
                when Done =>
                    disp_off_start <= '0';
                    serial_mode_active <= '0';
                    if rst = '0' and disp_on_ready = '1' then
                        state <= Idle;
                    end if;
                
                when FullDisp =>
                    toggle_disp_start <= '0';
                    if init_ready = '1' then
                        state <= after_state;
                    end if;
                
                when others =>
                    state <= Idle;
            end case;
        end if;
    end process;
    
end Behavioral;
