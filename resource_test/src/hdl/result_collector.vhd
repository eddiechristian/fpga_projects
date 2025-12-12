library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple round-robin collector for multiplier results
-- Takes any valid result from 10 inputs and forwards it
entity result_collector is
    generic (
        NUM_INPUTS : integer := 10
    );
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        
        -- Input from multipliers
        s_tvalid        : in  std_logic_vector(NUM_INPUTS-1 downto 0);
        s_tready        : out std_logic_vector(NUM_INPUTS-1 downto 0);
        s_tdata         : in  std_logic_vector(NUM_INPUTS*32-1 downto 0);
        
        -- Output
        m_tvalid        : out std_logic;
        m_tready        : in  std_logic;
        m_tdata         : out std_logic_vector(31 downto 0)
    );
end result_collector;

architecture Behavioral of result_collector is
    signal current_input : integer range 0 to NUM_INPUTS-1 := 0;
    signal selected_valid : std_logic;
    signal selected_data : std_logic_vector(31 downto 0);
    signal m_tvalid_int : std_logic;
begin

    -- Round-robin arbiter
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_input <= 0;
            elsif m_tvalid_int = '1' and m_tready = '1' then
                -- Move to next input after successful transaction
                if current_input = NUM_INPUTS-1 then
                    current_input <= 0;
                else
                    current_input <= current_input + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Mux for data selection
    process(s_tdata, current_input)
    begin
        selected_data <= s_tdata((current_input*32+31) downto (current_input*32));
    end process;
    
    -- Valid selection
    selected_valid <= s_tvalid(current_input);
    m_tvalid_int <= selected_valid;
    
    -- Output assignments
    m_tvalid <= m_tvalid_int;
    m_tdata  <= selected_data;
    
    -- Ready signals - only selected input sees ready
    gen_ready : for i in 0 to NUM_INPUTS-1 generate
        s_tready(i) <= m_tready when (i = current_input and selected_valid = '1') else '0';
    end generate;

end Behavioral;
