----------------------------------------------------------------------------------
-- debounce_test_top.vhd
-- 
-- Top level design for testing debouncer with Analog Discovery 2
-- 
-- Pmod JA Outputs:
--   Pin 1: Raw button signal (btnc)
--   Pin 2: Debounced button output (SIGNAL_O)
--   Pin 3: sig_out_reg internal state
--   Pin 4: Counter active flag
--   Pin 5: GND (ground reference)
--   Pin 7-10: Counter bits [23:20] (MSBs)
--
-- Pmod JB Outputs:
--   Pin 1-4: Counter bits [19:16]
--   Pin 5: GND (ground reference)
--   Pin 7-10: Counter bits [15:12]
--
-- Pmod JC Outputs:
--   Pin 1-4: Counter bits [11:8]
--   Pin 5: GND (ground reference)
--   Pin 7-10: Counter bits [7:4]
--
-- Pmod JD Outputs:
--   Pin 1-4: Counter bits [3:0] (LSBs)
--   Pin 5: GND (ground reference)
--   Pin 7: Clock signal (divided for visibility)
--   Pin 8-10: Unused
--
-- This allows comprehensive analysis with Analog Discovery 2 at safe 3.3V levels
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debounce_test_top is
    Port ( 
        clk          : in  STD_LOGIC;  -- 100MHz system clock
        btnc         : in  STD_LOGIC;  -- Center button input
        ja           : out STD_LOGIC_VECTOR(7 downto 0);  -- Pmod JA connector
        jb           : out STD_LOGIC_VECTOR(7 downto 0);  -- Pmod JB connector
        jc           : out STD_LOGIC_VECTOR(7 downto 0);  -- Pmod JC connector
        jd           : out STD_LOGIC_VECTOR(7 downto 0)   -- Pmod JD connector
    );
end debounce_test_top;

architecture Behavioral of debounce_test_top is

    -- Instrumented Debouncer component declaration
    component debouncer_instrumented is
        Generic ( 
            DEBNC_CLOCKS : INTEGER range 2 to (INTEGER'high) := 2**16;
            PORT_WIDTH   : INTEGER range 1 to (INTEGER'high) := 4
        );
        Port ( 
            SIGNAL_I : in  STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
            CLK_I    : in  STD_LOGIC;
            SIGNAL_O : out  STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
            DEBUG_COUNTER : out STD_LOGIC_VECTOR(23 downto 0);
            DEBUG_SIG_OUT_REG : out STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
            DEBUG_COUNTER_ACTIVE : out STD_LOGIC
        );
    end component;
    
    -- Debounce time: 10ms at 100MHz = 1,000,000 clocks
    constant DEBOUNCE_CLOCKS : integer := 1_000_000;
    
    -- Internal signals
    signal btn_raw     : std_logic_vector(0 downto 0);
    signal btn_debounced : std_logic_vector(0 downto 0);
    signal debug_counter : std_logic_vector(23 downto 0);
    signal debug_sig_out_reg : std_logic_vector(0 downto 0);
    signal debug_counter_active : std_logic;
    
    -- Clock divider for visible clock signal (divide by 2^20 for ~95Hz)
    signal clk_div_counter : unsigned(19 downto 0) := (others => '0');
    signal clk_divided : std_logic := '0';

begin

    -- Connect button input
    btn_raw(0) <= btnc;
    
    -- Clock divider for visible clock reference
    clk_div_process : process(clk)
    begin
        if rising_edge(clk) then
            clk_div_counter <= clk_div_counter + 1;
            clk_divided <= clk_div_counter(19);  -- ~95.37 Hz
        end if;
    end process;
    
    -- Instantiate instrumented debouncer
    debouncer_inst : debouncer_instrumented
        generic map (
            DEBNC_CLOCKS => DEBOUNCE_CLOCKS,
            PORT_WIDTH   => 1
        )
        port map (
            SIGNAL_I => btn_raw,
            CLK_I    => clk,
            SIGNAL_O => btn_debounced,
            DEBUG_COUNTER => debug_counter,
            DEBUG_SIG_OUT_REG => debug_sig_out_reg,
            DEBUG_COUNTER_ACTIVE => debug_counter_active
        );
    
    -- Pmod JA Outputs
    ja(0) <= btnc;                      -- JA1: Raw button (shows bounce)
    ja(1) <= btn_debounced(0);          -- JA2: Debounced output
    ja(2) <= debug_sig_out_reg(0);      -- JA3: sig_out_reg internal state
    ja(3) <= debug_counter_active;      -- JA4: Counter active flag
    ja(4) <= debug_counter(23);         -- JA7: Counter bit 23 (MSB)
    ja(5) <= debug_counter(22);         -- JA8: Counter bit 22
    ja(6) <= debug_counter(21);         -- JA9: Counter bit 21
    ja(7) <= debug_counter(20);         -- JA10: Counter bit 20
    
    -- Pmod JB Outputs - Counter bits [19:12]
    jb(0) <= debug_counter(19);         -- JB1: Counter bit 19
    jb(1) <= debug_counter(18);         -- JB2: Counter bit 18
    jb(2) <= debug_counter(17);         -- JB3: Counter bit 17
    jb(3) <= debug_counter(16);         -- JB4: Counter bit 16
    jb(4) <= debug_counter(15);         -- JB7: Counter bit 15
    jb(5) <= debug_counter(14);         -- JB8: Counter bit 14
    jb(6) <= debug_counter(13);         -- JB9: Counter bit 13
    jb(7) <= debug_counter(12);         -- JB10: Counter bit 12
    
    -- Pmod JC Outputs - Counter bits [11:4]
    jc(0) <= debug_counter(11);         -- JC1: Counter bit 11
    jc(1) <= debug_counter(10);         -- JC2: Counter bit 10
    jc(2) <= debug_counter(9);          -- JC3: Counter bit 9
    jc(3) <= debug_counter(8);          -- JC4: Counter bit 8
    jc(4) <= debug_counter(7);          -- JC7: Counter bit 7
    jc(5) <= debug_counter(6);          -- JC8: Counter bit 6
    jc(6) <= debug_counter(5);          -- JC9: Counter bit 5
    jc(7) <= debug_counter(4);          -- JC10: Counter bit 4
    
    -- Pmod JD Outputs - Counter bits [3:0] and clock
    jd(0) <= debug_counter(3);          -- JD1: Counter bit 3
    jd(1) <= debug_counter(2);          -- JD2: Counter bit 2
    jd(2) <= debug_counter(1);          -- JD3: Counter bit 1
    jd(3) <= debug_counter(0);          -- JD4: Counter bit 0 (LSB)
    jd(4) <= clk_divided;               -- JD7: Divided clock (~95Hz)
    jd(5) <= '0';                       -- JD8: Unused
    jd(6) <= '0';                       -- JD9: Unused
    jd(7) <= '0';                       -- JD10: Unused

end Behavioral;
