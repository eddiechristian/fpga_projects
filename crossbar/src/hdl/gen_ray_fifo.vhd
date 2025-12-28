library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple FIFO for generate_ray pipeline stage data handoff
-- Uses circular buffer with head/tail pointers
entity gen_ray_fifo is
    generic (
        DATA_WIDTH : integer := 32;
        DEPTH      : integer := 4  -- Must be power of 2 for efficiency
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        
        -- Write interface
        wr_en    : in  std_logic;
        wr_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        full     : out std_logic;
        
        -- Read interface
        rd_en    : in  std_logic;
        rd_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        empty    : out std_logic
    );
end entity gen_ray_fifo;

architecture behavioral of gen_ray_fifo is
    
    -- Memory array for FIFO storage
    type mem_array_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mem : mem_array_t := (others => (others => '0'));
    
    -- Pointers (use DEPTH bits to allow full/empty distinction)
    signal head : unsigned(DEPTH downto 0) := (others => '0');  -- Write pointer
    signal tail : unsigned(DEPTH downto 0) := (others => '0');  -- Read pointer
    
    -- Count for full/empty detection
    signal count : integer range 0 to DEPTH := 0;
    
begin
    
    -- Full when count = DEPTH
    full <= '1' when count = DEPTH else '0';
    
    -- Empty when count = 0
    empty <= '1' when count = 0 else '0';
    
    -- Always output data at read pointer (combinational read)
    -- Use modulo to wrap pointer within array bounds
    rd_data <= mem(to_integer(tail) mod DEPTH);
    
    -- FIFO control
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                head <= (others => '0');
                tail <= (others => '0');
                count <= 0;
                
            else
                -- Handle simultaneous read and write
                if wr_en = '1' and rd_en = '1' and count > 0 and count < DEPTH then
                    -- Both operations: count stays the same
                    mem(to_integer(head) mod DEPTH) <= wr_data;
                    head <= head + 1;
                    tail <= tail + 1;
                    -- count unchanged
                    
                elsif wr_en = '1' and count < DEPTH then
                    -- Write only
                    mem(to_integer(head) mod DEPTH) <= wr_data;
                    head <= head + 1;
                    count <= count + 1;
                    
                elsif rd_en = '1' and count > 0 then
                    -- Read only
                    tail <= tail + 1;
                    count <= count - 1;
                end if;
                
            end if;
        end if;
    end process;
    
end architecture behavioral;
