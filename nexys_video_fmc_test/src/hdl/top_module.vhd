----------------------------------------------------------------------------------
-- Nexys Video FMC Bidirectional Test
-- Uses inout FMC ports: Switch drives FMC pin, FMC pin drives LED
-- Switch high -> drives '1' to FMC -> LED reads '1'
-- Switch low -> FMC is Hi-Z -> LED reads external signal or pull-down
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_module is
    Port (
        -- Switches (8 switches on Nexys Video)
        sw : in STD_LOGIC_VECTOR(7 downto 0);
        
        -- LEDs (8 LEDs on Nexys Video)
        led : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- FMC LA (Low Address) bidirectional pins
        -- LA00_P/N through LA07_P/N for 8 channels
        fmc_la_p : inout STD_LOGIC_VECTOR(9 downto 2);
        fmc_la_n : inout STD_LOGIC_VECTOR(9 downto 2)
    );
end top_module;

architecture Behavioral of top_module is
begin
    -- Bidirectional FMC control with tri-state buffers
    -- When switch is '1', drive the FMC pin high
    -- When switch is '0', set FMC pin to high-impedance (Hi-Z)
    gen_bidir: for i in 0 to 7 generate
        -- Positive pins: drive when switch is high, otherwise Hi-Z
        fmc_la_p(i+2) <= '1' when sw(i) = '1' else 'Z';
        
        -- Negative pins: drive complement when switch is high, otherwise Hi-Z
        fmc_la_n(i+2) <= '0' when sw(i) = '1' else 'Z';
        
        -- LEDs read the state of FMC pins
        led(i) <= fmc_la_p(i+2);
    end generate;

end Behavioral;
