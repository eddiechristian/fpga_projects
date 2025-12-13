library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Parameterizable wrapper for AXI4-Stream Interconnect
-- Uses VHDL-2008 unconstrained arrays to support any number of masters
entity axis_interconnect_wrapper is
    generic (
        NUM_MASTERS   : integer := 10;
        TDEST_WIDTH   : integer := 4;
        TDATA_WIDTH   : integer := 64;
        TID_WIDTH     : integer := 16
    );
    port (
        aclk          : in  std_logic;
        aresetn       : in  std_logic;
        
        -- Slave interface (from input FIFO)
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
        s_axis_tdest  : in  std_logic_vector(TDEST_WIDTH-1 downto 0);
        s_axis_tid    : in  std_logic_vector(TID_WIDTH-1 downto 0);
        
        -- Master interfaces (to multipliers) - unconstrained arrays
        m_axis_tvalid : out std_logic_vector(NUM_MASTERS-1 downto 0);
        m_axis_tready : in  std_logic_vector(NUM_MASTERS-1 downto 0);
        m_axis_tdata  : out std_logic_vector(NUM_MASTERS*TDATA_WIDTH-1 downto 0);
        m_axis_tid    : out std_logic_vector(NUM_MASTERS*TID_WIDTH-1 downto 0)
    );
end axis_interconnect_wrapper;

architecture Behavioral of axis_interconnect_wrapper is
    
    -- Pipeline stage registers
    signal pipe_tvalid : std_logic := '0';
    signal pipe_tdata  : std_logic_vector(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal pipe_tdest  : std_logic_vector(TDEST_WIDTH-1 downto 0) := (others => '0');
    signal pipe_tid    : std_logic_vector(TID_WIDTH-1 downto 0) := (others => '0');
    signal pipe_ready  : std_logic;
    
    signal dest_idx    : integer range 0 to NUM_MASTERS-1 := 0;
    
begin
    
    -- Pipeline register stage (breaks critical path)
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                pipe_tvalid <= '0';
                pipe_tdata  <= (others => '0');
                pipe_tdest  <= (others => '0');
                pipe_tid    <= (others => '0');
            else
                -- Register input when downstream is ready or pipeline is empty
                if s_axis_tvalid = '1' and (pipe_ready = '1' or pipe_tvalid = '0') then
                    pipe_tvalid <= s_axis_tvalid;
                    pipe_tdata  <= s_axis_tdata;
                    pipe_tdest  <= s_axis_tdest;
                    pipe_tid    <= s_axis_tid;
                elsif pipe_ready = '1' then
                    pipe_tvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Input ready when pipeline can accept data
    s_axis_tready <= pipe_ready or not pipe_tvalid;
    
    -- Decode TDEST (registered)
    dest_idx <= to_integer(unsigned(pipe_tdest)) when to_integer(unsigned(pipe_tdest)) < NUM_MASTERS else 0;
    
    -- Demux logic (now operates on pipelined signals)
    process(pipe_tvalid, dest_idx, m_axis_tready, pipe_tdata, pipe_tid)
    begin
        -- Default: no masters active
        m_axis_tvalid <= (others => '0');
        pipe_ready <= '0';
        
        -- Route to selected master
        if pipe_tvalid = '1' then
            m_axis_tvalid(dest_idx) <= '1';
            pipe_ready <= m_axis_tready(dest_idx);
        else
            pipe_ready <= '1';  -- Pipeline ready when empty
        end if;
        
        -- Broadcast data and TID to all masters (only selected one will use it)
        for i in 0 to NUM_MASTERS-1 loop
            m_axis_tdata((i+1)*TDATA_WIDTH-1 downto i*TDATA_WIDTH) <= pipe_tdata;
            m_axis_tid((i+1)*TID_WIDTH-1 downto i*TID_WIDTH) <= pipe_tid;
        end loop;
    end process;
    
end Behavioral;
