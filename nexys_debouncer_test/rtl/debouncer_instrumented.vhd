----------------------------------------------------------------------------
--	debouncer_instrumented.vhd -- Signal Debouncer with Debug Outputs
----------------------------------------------------------------------------
-- Modified version of debouncer.vhd with internal signals exposed
-- Based on original by Sam Bobrowicz, Copyright 2011 Digilent, Inc.
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;
USE IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

entity debouncer_instrumented is
    Generic ( DEBNC_CLOCKS : INTEGER range 2 to (INTEGER'high) := 2**16;
              PORT_WIDTH : INTEGER range 1 to (INTEGER'high) := 4);
    Port ( SIGNAL_I : in  STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
           CLK_I : in  STD_LOGIC;
           SIGNAL_O : out  STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
           -- Debug outputs
           DEBUG_COUNTER : out STD_LOGIC_VECTOR(23 downto 0);  -- Counter value (top 24 bits)
           DEBUG_SIG_OUT_REG : out STD_LOGIC_VECTOR ((PORT_WIDTH - 1) downto 0);
           DEBUG_COUNTER_ACTIVE : out STD_LOGIC);  -- High when counter is running
end debouncer_instrumented;

architecture Behavioral of debouncer_instrumented is

constant CNTR_WIDTH : integer := natural(ceil(LOG2(real(DEBNC_CLOCKS))));
constant CNTR_MAX : std_logic_vector((CNTR_WIDTH - 1) downto 0) := std_logic_vector(to_unsigned((DEBNC_CLOCKS - 1), CNTR_WIDTH));
type VECTOR_ARRAY_TYPE is array (integer range <>) of std_logic_vector((CNTR_WIDTH - 1) downto 0);

signal sig_cntrs_ary : VECTOR_ARRAY_TYPE (0 to (PORT_WIDTH - 1)) := (others=>(others=>'0'));

signal sig_out_reg : std_logic_vector((PORT_WIDTH - 1) downto 0) := (others => '0');

begin

debounce_process : process (CLK_I)
begin
   if (rising_edge(CLK_I)) then
   for index in 0 to (PORT_WIDTH - 1) loop
      if (sig_cntrs_ary(index) = CNTR_MAX) then
         sig_out_reg(index) <= not(sig_out_reg(index));
      end if;
   end loop;
   end if;
end process;

counter_process : process (CLK_I)
begin
	if (rising_edge(CLK_I)) then
	for index in 0 to (PORT_WIDTH - 1) loop
	
		if ((sig_out_reg(index) = '1') xor (SIGNAL_I(index) = '1')) then
			if (sig_cntrs_ary(index) = CNTR_MAX) then
				sig_cntrs_ary(index) <= (others => '0');
			else
				sig_cntrs_ary(index) <= sig_cntrs_ary(index) + 1;
			end if;
		else
			sig_cntrs_ary(index) <= (others => '0');
		end if;
		
	end loop;
	end if;
end process;

SIGNAL_O <= sig_out_reg;

-- Debug outputs
DEBUG_SIG_OUT_REG <= sig_out_reg;

-- Output top 24 bits of counter (or pad with zeros if counter is smaller)
debug_counter_output : process(sig_cntrs_ary)
begin
    if CNTR_WIDTH >= 24 then
        -- Take top 24 bits
        DEBUG_COUNTER <= sig_cntrs_ary(0)(CNTR_WIDTH-1 downto CNTR_WIDTH-24);
    else
        -- Pad with zeros and use all bits
        DEBUG_COUNTER <= (23 downto CNTR_WIDTH => '0') & sig_cntrs_ary(0);
    end if;
end process;

-- Counter active when non-zero
DEBUG_COUNTER_ACTIVE <= '1' when (sig_cntrs_ary(0) /= (CNTR_WIDTH - 1 downto 0 => '0')) else '0';

end Behavioral;
