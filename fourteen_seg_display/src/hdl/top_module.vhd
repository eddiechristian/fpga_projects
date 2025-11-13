----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/08/2025 11:27:57 PM
-- Design Name: 
-- Module Name: top_module - Behavioral
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

entity top_module is
Port (
    CLK:     in  std_logic;  -- 100 MHz clock
    RST:     in  std_logic;  -- Reset button
    SW:      in  std_logic_vector(7 downto 0);
    BTN:     in std_logic_vector(4 downto 0);
    LED:     out std_logic_vector(7 downto 0);
    SEG:     out std_logic_vector(13 downto 0);  -- 14 segment signals
    DIG:     out std_logic_vector(3 downto 0)    -- 4 digit select signals
    );
end top_module;

architecture Behavioral of top_module is
    -- Constants
    constant NUM_DIGITS : natural := 4;  -- 2 displays × 2 digits each
    constant CLK_DIV_MAX : natural := 100_000;  -- ~1ms refresh rate at 100MHz
    
    -- Component declarations
    component debouncer
        Generic(
            DEBNC_CLOCKS : integer;
            PORT_WIDTH : integer);
        Port(
            SIGNAL_I : in std_logic_vector(5 downto 0);
            CLK_I : in std_logic;          
            SIGNAL_O : out std_logic_vector(5 downto 0)
        );
    end component;
    
    component display_dec_to_hex
        GENERIC(
            NUM_DIGITS: natural := 4
        );
        Port ( 
            decimal_num: in std_logic_vector((NUM_DIGITS*4 - 1) downto 0);
            hex_ascii_digit_out: out std_logic_vector((NUM_DIGITS*8 - 1) downto 0);
            blank_digits: out std_logic_vector((NUM_DIGITS - 1) downto 0)
        );
    end component;
    
    component segment_multiplexor
        GENERIC(
            NUM_DIGITS: natural := 4;
            CLK_DIV_MAX: natural := 1
        );
        Port (
            clk   : in  std_logic;
            ascii_in : in STD_LOGIC_VECTOR(((NUM_DIGITS * 8) -1) downto 0);
            reset : in  std_logic;
            digit_selector: out STD_LOGIC_VECTOR((integer(ceil(log2(real(NUM_DIGITS))))-1) downto 0);
            segments : out STD_LOGIC_VECTOR(13 downto 0)
        );
    end component;
    
    component counter
        Generic(
            WIDTH : natural := 16
        );
        Port(
            clk : in std_logic;
            reset : in std_logic;
            enable : in std_logic;
            count : out std_logic_vector(WIDTH-1 downto 0)
        );
    end component;
    
    -- Signals
    signal btnReg : std_logic_vector (4 downto 0) := "00000";
    signal btnDeBnc : std_logic_vector(5 downto 0);
    
    signal count_val : std_logic_vector(15 downto 0);
    signal ascii_digits : std_logic_vector(31 downto 0);  -- 4 digits × 8 bits
    signal blank_mask : std_logic_vector(3 downto 0);
    signal digit_sel : std_logic_vector(1 downto 0);
    signal digit_sel_decoded : std_logic_vector(3 downto 0);


begin
    -- Debounce buttons
    Inst_btn_debounce: debouncer 
        generic map(
            DEBNC_CLOCKS => (2**16),
            PORT_WIDTH => 6)
        port map(
            SIGNAL_I => RST & BTN,
            CLK_I => CLK,
            SIGNAL_O => btnDeBnc
        );
    
    -- Register debounced buttons for edge detection
    btn_reg_process : process (CLK)
    begin
        if (rising_edge(CLK)) then
            btnReg <= btnDeBnc(4 downto 0);
        end if;
    end process;
    
    -- Counter - counts from 0 to 65535
    Inst_counter: counter
        generic map(
            WIDTH => 16
        )
        port map(
            clk => CLK,
            reset => btnDeBnc(5),  -- reset from debounced RST button
            enable => '1',
            count => count_val
        );
    
    -- Convert counter value to hex ASCII digits
    Inst_dec_to_hex: display_dec_to_hex
        generic map(
            NUM_DIGITS => NUM_DIGITS
        )
        port map(
            decimal_num => count_val,
            hex_ascii_digit_out => ascii_digits,
            blank_digits => blank_mask
        );
    
    -- Multiplexor - cycles through digits and outputs segments
    Inst_mux: segment_multiplexor
        generic map(
            NUM_DIGITS => NUM_DIGITS,
            CLK_DIV_MAX => CLK_DIV_MAX
        )
        port map(
            clk => CLK,
            ascii_in => ascii_digits,
            reset => btnDeBnc(5),
            digit_selector => digit_sel,
            segments => SEG
        );
    
    -- Decode digit selector to individual digit enable signals
    -- Only one digit is active at a time (active LOW for common anode displays)
    process(digit_sel, blank_mask)
    begin
        digit_sel_decoded <= (others => '1');  -- Default all off (HIGH = off for common anode)
        
        case digit_sel is
            when "00" =>
                if blank_mask(0) = '0' then
                    digit_sel_decoded(0) <= '0';  -- Enable digit 0
                end if;
            when "01" =>
                if blank_mask(1) = '0' then
                    digit_sel_decoded(1) <= '0';  -- Enable digit 1
                end if;
            when "10" =>
                if blank_mask(2) = '0' then
                    digit_sel_decoded(2) <= '0';  -- Enable digit 2
                end if;
            when "11" =>
                if blank_mask(3) = '0' then
                    digit_sel_decoded(3) <= '0';  -- Enable digit 3
                end if;
            when others =>
                digit_sel_decoded <= (others => '1');
        end case;
    end process;
    
    DIG <= digit_sel_decoded;
    
    -- Debug: Show counter value on LEDs
    LED <= count_val(7 downto 0);

end Behavioral;
