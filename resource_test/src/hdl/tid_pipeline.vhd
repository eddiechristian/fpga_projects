library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- TID Pipeline - delays Transaction ID to match floating point multiplier latency
-- This module creates a shift register that delays TID values to stay synchronized
-- with the data path through the FP multiplier
entity tid_pipeline is
    generic (
        LATENCY   : integer := 8;   -- Must match FP multiplier latency
        TID_WIDTH : integer := 16   -- Transaction ID width
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        
        -- Input TID (from interconnect)
        s_tid     : in  std_logic_vector(TID_WIDTH-1 downto 0);
        s_tvalid  : in  std_logic;
        
        -- Output TID (synchronized with multiplier result)
        m_tid     : out std_logic_vector(TID_WIDTH-1 downto 0);
        m_tvalid  : out std_logic
    );
end tid_pipeline;

architecture Behavioral of tid_pipeline is
    -- Array type for shift register
    type tid_array_t is array (0 to LATENCY-1) of std_logic_vector(TID_WIDTH-1 downto 0);
    
    -- Shift registers for TID and valid
    signal tid_shift   : tid_array_t := (others => (others => '0'));
    signal valid_shift : std_logic_vector(LATENCY-1 downto 0) := (others => '0');
    
begin
    
    -- Shift register process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tid_shift   <= (others => (others => '0'));
                valid_shift <= (others => '0');
            else
                -- Shift TID through pipeline
                tid_shift(0) <= s_tid;
                for i in 1 to LATENCY-1 loop
                    tid_shift(i) <= tid_shift(i-1);
                end loop;
                
                -- Shift valid through pipeline
                valid_shift(0) <= s_tvalid;
                for i in 1 to LATENCY-1 loop
                    valid_shift(i) <= valid_shift(i-1);
                end loop;
            end if;
        end if;
    end process;
    
    -- Output the delayed values
    m_tid    <= tid_shift(LATENCY-1);
    m_tvalid <= valid_shift(LATENCY-1);
    
end Behavioral;
