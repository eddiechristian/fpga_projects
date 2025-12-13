library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Output Demultiplexer for Multi-Producer Results Routing
-- Extracts producer ID from upper TID bits and routes results to correct output FIFO
-- Uses VHDL-2008 unconstrained arrays to support any number of producers
entity output_demux is
    generic (
        NUM_PRODUCERS     : integer := 5;      -- Number of producers (output ports)
        PRODUCER_ID_WIDTH : integer := 3;      -- Width of producer ID field in TID
        TDATA_WIDTH       : integer := 32;     -- Data width (FP32 result)
        TID_WIDTH         : integer := 16      -- Full TID width
    );
    port (
        aclk          : in  std_logic;
        aresetn       : in  std_logic;
        
        -- Slave interface (from result_collector)
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        s_axis_tid    : in  std_logic_vector(TID_WIDTH-1 downto 0);
        
        -- Master interfaces (to per-producer output FIFOs)
        m_axis_tvalid : out std_logic_vector(NUM_PRODUCERS-1 downto 0);
        m_axis_tready : in  std_logic_vector(NUM_PRODUCERS-1 downto 0);
        m_axis_tdata  : out std_logic_vector(NUM_PRODUCERS*TDATA_WIDTH-1 downto 0);
        m_axis_tid    : out std_logic_vector(NUM_PRODUCERS*TID_WIDTH-1 downto 0)
    );
end output_demux;

architecture Behavioral of output_demux is
    
    -- Pipeline stage registers
    signal pipe_tvalid : std_logic := '0';
    signal pipe_tdata  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal pipe_tid    : std_logic_vector(TID_WIDTH-1 downto 0) := (others => '0');
    signal pipe_ready  : std_logic;
    
    -- Producer ID extracted from TID upper bits
    signal producer_id : integer range 0 to NUM_PRODUCERS-1 := 0;
    
begin
    
    -- Pipeline register stage (breaks critical path)
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                pipe_tvalid <= '0';
                pipe_tdata  <= (others => '0');
                pipe_tid    <= (others => '0');
            else
                -- Register input when downstream is ready or pipeline is empty
                if s_axis_tvalid = '1' and (pipe_ready = '1' or pipe_tvalid = '0') then
                    pipe_tvalid <= s_axis_tvalid;
                    pipe_tdata  <= s_axis_tdata;
                    pipe_tid    <= s_axis_tid;
                elsif pipe_ready = '1' then
                    pipe_tvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Input ready when pipeline can accept data
    s_axis_tready <= pipe_ready or not pipe_tvalid;
    
    -- Extract producer ID from TID upper bits
    -- For 5 producers (NUM_PRODUCERS=5), need 3 bits (PRODUCER_ID_WIDTH=3)
    -- Producer ID is in TID[15:13] (upper 3 bits)
    producer_id <= to_integer(unsigned(pipe_tid(TID_WIDTH-1 downto TID_WIDTH-PRODUCER_ID_WIDTH))) 
                   when to_integer(unsigned(pipe_tid(TID_WIDTH-1 downto TID_WIDTH-PRODUCER_ID_WIDTH))) < NUM_PRODUCERS 
                   else 0;
    
    -- Demux logic (operates on pipelined signals)
    process(pipe_tvalid, producer_id, m_axis_tready, pipe_tdata, pipe_tid)
    begin
        -- Default: no producers active
        m_axis_tvalid <= (others => '0');
        pipe_ready <= '0';
        
        -- Route to selected producer
        if pipe_tvalid = '1' then
            m_axis_tvalid(producer_id) <= '1';
            pipe_ready <= m_axis_tready(producer_id);
        else
            pipe_ready <= '1';  -- Pipeline ready when empty
        end if;
        
        -- Broadcast data and TID to all producers (only selected one will use it)
        for i in 0 to NUM_PRODUCERS-1 loop
            m_axis_tdata((i+1)*TDATA_WIDTH-1 downto i*TDATA_WIDTH) <= pipe_tdata;
            m_axis_tid((i+1)*TID_WIDTH-1 downto i*TID_WIDTH) <= pipe_tid;
        end loop;
    end process;
    
end Behavioral;
