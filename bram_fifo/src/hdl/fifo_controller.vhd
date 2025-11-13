library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_controller is
    Generic (
        ADDR_WIDTH : integer := 9;  -- 512 entries = 2^9
        DATA_WIDTH : integer := 32
    );
    Port (
        -- Clock and reset
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Write interface
        wr_en       : in  std_logic;
        wr_data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        full        : out std_logic;
        
        -- Read interface
        rd_en       : in  std_logic;
        rd_data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        empty       : out std_logic;
        
        -- BRAM interface (Port A for write, Port B for read)
        bram_wr_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        bram_wr_en   : out std_logic;
        bram_wr_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        bram_rd_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        bram_rd_en   : out std_logic;
        bram_rd_data : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end fifo_controller;

architecture Behavioral of fifo_controller is
    -- Read and write pointers
    signal wr_ptr : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    signal rd_ptr : unsigned(ADDR_WIDTH downto 0) := (others => '0');
    
    -- Status signals
    signal full_i  : std_logic;
    signal empty_i : std_logic;
    
    -- BRAM has 1 cycle read latency, so we need to pipeline
    signal rd_valid_pipe : std_logic := '0';
    
begin
    -- Status generation
    full_i  <= '1' when (wr_ptr(ADDR_WIDTH) /= rd_ptr(ADDR_WIDTH)) and 
                        (wr_ptr(ADDR_WIDTH-1 downto 0) = rd_ptr(ADDR_WIDTH-1 downto 0)) else '0';
    empty_i <= '1' when wr_ptr = rd_ptr else '0';
    
    full  <= full_i;
    empty <= empty_i;
    
    -- Write pointer management
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr <= (others => '0');
            elsif wr_en = '1' and full_i = '0' then
                wr_ptr <= wr_ptr + 1;
            end if;
        end if;
    end process;
    
    -- Read pointer management
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rd_ptr <= (others => '0');
            elsif rd_en = '1' and empty_i = '0' then
                rd_ptr <= rd_ptr + 1;
            end if;
        end if;
    end process;
    
    -- BRAM write interface
    bram_wr_addr <= std_logic_vector(wr_ptr(ADDR_WIDTH-1 downto 0));
    bram_wr_en   <= wr_en and (not full_i);
    bram_wr_data <= wr_data;
    
    -- BRAM read interface
    bram_rd_addr <= std_logic_vector(rd_ptr(ADDR_WIDTH-1 downto 0));
    bram_rd_en   <= rd_en and (not empty_i);
    
    -- Output data from BRAM (1 cycle delay)
    rd_data <= bram_rd_data;

end Behavioral;

