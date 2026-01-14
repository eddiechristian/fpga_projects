----------------------------------------------------------------------------------
-- Nexys Video FMC Bidirectional Test
-- Uses inout FMC ports: Switch drives FMC pin, FMC pin drives LED
-- Switch high -> drives '1' to FMC -> LED reads '1'
-- Switch low -> FMC is Hi-Z -> LED reads external signal or pull-down
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY top_module IS
    PORT (
    -- Switches (8 switches on Nexys Video)
    sw       : IN STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- LEDs (8 LEDs on Nexys Video)
    led      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

    hsync    : INOUT STD_LOGIC;
    vsync    : INOUT STD_LOGIC;

    red_in   : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    green_in : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    blue_in  : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END top_module;

ARCHITECTURE Behavioral OF top_module IS
BEGIN
    hsync    <= '0';
    vsync    <= '0';
    green_in <= (OTHERS => '0');
    blue_in  <= (OTHERS => '0');
    gen_bidir : FOR i IN 0 TO 7 GENERATE
        -- Positive pins: drive when switch is high, otherwise Hi-Z
        red_in(i) <= '1' WHEN sw(i) = '1' ELSE
        '0';

        -- Negative pins: drive complement when switch is high, otherwise Hi-Z
        -- fmc_la_n(i + 2) <= '0' WHEN sw(i) = '1' ELSE
        -- 'Z';

        -- LEDs read the state of FMC pins
        led(i) <= red_in(i);
    END GENERATE;

END Behavioral;