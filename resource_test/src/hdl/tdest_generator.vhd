library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- This module generates TDEST values for routing multiply operations
-- to different multipliers in a round-robin fashion
entity tdest_generator is
    generic (
        NUM_MULTIPLIERS : integer := 10;
        TDEST_WIDTH     : integer := 4   -- Width of TDEST field (ceil(log2(NUM_MULTIPLIERS)))
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        
        -- Input stream (from external source)
        s_axis_tdata    : in  std_logic_vector(63 downto 0); -- {operand_b, operand_a}
        s_axis_tid      : in  std_logic_vector(15 downto 0); -- Transaction ID
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;
        
        -- Output stream (to AXI interconnect with TDEST)
        m_axis_tdata    : out std_logic_vector(63 downto 0);
        m_axis_tdest    : out std_logic_vector(TDEST_WIDTH-1 downto 0);  -- Destination multiplier
        m_axis_tid      : out std_logic_vector(15 downto 0); -- Transaction ID (passthrough)
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic
    );
end tdest_generator;

architecture Behavioral of tdest_generator is
    signal current_dest : unsigned(TDEST_WIDTH-1 downto 0) := (others => '0');
begin
    
    -- Pass through data, TID, and valid
    m_axis_tdata <= s_axis_tdata;
    m_axis_tid <= s_axis_tid;
    m_axis_tvalid <= s_axis_tvalid;
    s_axis_tready <= m_axis_tready;
    
    -- Assign TDEST based on round-robin counter
    m_axis_tdest <= std_logic_vector(current_dest);
    
    -- Round-robin counter process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_dest <= (others => '0');
            else
                -- Increment destination when transaction completes
                if s_axis_tvalid = '1' and m_axis_tready = '1' then
                    if current_dest = NUM_MULTIPLIERS - 1 then
                        current_dest <= (others => '0');
                    else
                        current_dest <= current_dest + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;
