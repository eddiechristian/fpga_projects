library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Generic (
        SINE_FREQ   : integer := 10  -- Sine wave frequency in Hz (default 10 Hz)
    );
    Port (
        clk         : in  std_logic;  -- 100 MHz system clock
        rst_n       : in  std_logic;  -- Active-low reset (button)
        -- Status LEDs
        led_busy1   : out std_logic;
        led_busy2   : out std_logic;
        led_busy3   : out std_logic;
        -- I2C Bus 1 (DAC #1)
        scl1        : inout std_logic;
        sda1        : inout std_logic;
        -- I2C Bus 2 (DAC #2)
        scl2        : inout std_logic;
        sda2        : inout std_logic;
        -- I2C Bus 3 (DAC #3)
        scl3        : inout std_logic;
        sda3        : inout std_logic
    );
end top_module;

architecture Behavioral of triple_dac_top is
    component mcp4725_driver is
        Generic (
            CLK_FREQ    : integer;
            I2C_FREQ    : integer;
            I2C_ADDR    : std_logic_vector(6 downto 0)
        );
        Port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            dac_value   : in  std_logic_vector(11 downto 0);
            update      : in  std_logic;
            busy        : out std_logic;
            done        : out std_logic;
            scl         : inout std_logic;
            sda         : inout std_logic
        );
    end component;
    
    component sine_generator is
        Generic (
            CLK_FREQ        : integer;
            SINE_FREQ       : integer;
            PHASE_OFFSET    : integer
        );
        Port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            enable      : in  std_logic;
            sine_out    : out std_logic_vector(11 downto 0);
            update_tick : out std_logic
        );
    end component;
    
    signal rst : std_logic;
    signal done1, done2, done3 : std_logic;
    
    -- Sine generator signals
    signal sine1_value, sine2_value, sine3_value : std_logic_vector(11 downto 0);
    signal sine1_tick, sine2_tick, sine3_tick : std_logic;

begin
    -- Active-low to active-high reset conversion
    rst <= not rst_n;
    
    -- DAC 1 - I2C Address 0x60
    dac1_inst : mcp4725_driver
        generic map (
            CLK_FREQ => 100_000_000,
            I2C_FREQ => 100_000,
            I2C_ADDR => "1100000"  -- 0x60
        )
        port map (
            clk       => clk,
            rst       => rst,
            dac_value => sine1_value,
            update    => sine1_tick,
            busy      => led_busy1,
            done      => done1,
            scl       => scl1,
            sda       => sda1
        );
    
    -- DAC 2 - I2C Address 0x61
    dac2_inst : mcp4725_driver
        generic map (
            CLK_FREQ => 100_000_000,
            I2C_FREQ => 100_000,
            I2C_ADDR => "1100001"  -- 0x61
        )
        port map (
            clk       => clk,
            rst       => rst,
            dac_value => sine2_value,
            update    => sine2_tick,
            busy      => led_busy2,
            done      => done2,
            scl       => scl2,
            sda       => sda2
        );
    
    -- DAC 3 - I2C Address 0x62
    dac3_inst : mcp4725_driver
        generic map (
            CLK_FREQ => 100_000_000,
            I2C_FREQ => 100_000,
            I2C_ADDR => "1100010"  -- 0x62
        )
        port map (
            clk       => clk,
            rst       => rst,
            dac_value => sine3_value,
            update    => sine3_tick,
            busy      => led_busy3,
            done      => done3,
            scl       => scl3,
            sda       => sda3
        );

end Behavioral;
