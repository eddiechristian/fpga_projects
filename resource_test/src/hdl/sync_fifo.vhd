library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple synchronous FIFO with TID support
-- Stores {data, tid} pairs
entity sync_fifo is
    generic (
        DATA_WIDTH : integer := 32;
        TID_WIDTH  : integer := 16;
        DEPTH      : integer := 32
    );
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        
        -- Write interface
        wr_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        wr_tid     : in  std_logic_vector(TID_WIDTH-1 downto 0);
        wr_valid   : in  std_logic;
        wr_ready   : out std_logic;
        
        -- Read interface
        rd_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_tid     : out std_logic_vector(TID_WIDTH-1 downto 0);
        rd_valid   : out std_logic;
        rd_ready   : in  std_logic;
        
        -- Status
        full       : out std_logic;
        empty      : out std_logic;
        almost_full : out std_logic  -- Asserts when >= 3/4 full
    );
end sync_fifo;

architecture Behavioral of sync_fifo is
    constant TOTAL_WIDTH : integer := DATA_WIDTH + TID_WIDTH;
    constant ALMOST_FULL_THRESHOLD : integer := (DEPTH * 3) / 4;
    
    type fifo_array_t is array (0 to DEPTH-1) of std_logic_vector(TOTAL_WIDTH-1 downto 0);
    signal fifo_mem : fifo_array_t := (others => (others => '0'));
    
    -- Add ram_style attribute to infer BRAM
    attribute ram_style : string;
    attribute ram_style of fifo_mem : signal is "block";
    
    signal wr_ptr : integer range 0 to DEPTH-1 := 0;
    signal rd_ptr : integer range 0 to DEPTH-1 := 0;
    signal count  : integer range 0 to DEPTH := 0;
    
    signal full_int       : std_logic;
    signal empty_int      : std_logic;
    signal almost_full_int : std_logic;
    
    -- Registered read output for BRAM timing
    signal rd_data_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal rd_tid_reg  : std_logic_vector(TID_WIDTH-1 downto 0);
    signal rd_valid_reg : std_logic := '0';
    
begin

    -- Status flags
    full_int  <= '1' when count = DEPTH else '0';
    empty_int <= '1' when count = 0 else '0';
    almost_full_int <= '1' when count >= ALMOST_FULL_THRESHOLD else '0';
    
    full  <= full_int;
    empty <= empty_int;
    almost_full <= almost_full_int;
    
    -- Write ready when not full
    wr_ready <= not full_int;
    
    -- Read valid (registered to match read data/TID delay)
    rd_valid <= rd_valid_reg;
    
    -- Write process
    process(clk)
        variable wr_combined : std_logic_vector(TOTAL_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count <= 0;
            else
                -- Handle write
                if wr_valid = '1' and full_int = '0' then
                    wr_combined := wr_tid & wr_data;
                    fifo_mem(wr_ptr) <= wr_combined;
                    
                    if wr_ptr = DEPTH-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;
                
                -- Handle read
                if rd_ready = '1' and empty_int = '0' then
                    if rd_ptr = DEPTH-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;
                
                -- Update count
                if (wr_valid = '1' and full_int = '0') and (rd_ready = '1' and empty_int = '0') then
                    -- Simultaneous read and write - count unchanged
                    count <= count;
                elsif wr_valid = '1' and full_int = '0' then
                    -- Write only
                    count <= count + 1;
                elsif rd_ready = '1' and empty_int = '0' then
                    -- Read only
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Read output (registered for BRAM)
    process(clk)
        variable rd_combined : std_logic_vector(TOTAL_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rd_valid_reg <= '0';
            else
                -- Register valid signal to match data/TID delay
                rd_valid_reg <= not empty_int;
            end if;
            
            rd_combined := fifo_mem(rd_ptr);
            rd_data_reg <= rd_combined(DATA_WIDTH-1 downto 0);
            rd_tid_reg  <= rd_combined(TOTAL_WIDTH-1 downto DATA_WIDTH);
        end if;
    end process;
    
    rd_data <= rd_data_reg;
    rd_tid  <= rd_tid_reg;

end Behavioral;
