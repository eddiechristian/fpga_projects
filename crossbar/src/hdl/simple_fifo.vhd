library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_fifo is
    generic (
        DATA_WIDTH : integer := 48;
        DEPTH      : integer := 8
    );
    port (
        clk        : in std_logic;
        rst        : in std_logic;
        wr_en      : in std_logic;
        wr_data    : in std_logic_vector(DATA_WIDTH-1 downto 0);
        rd_en      : in std_logic;
        rd_data    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        empty      : out std_logic;
        full       : out std_logic
    );
end simple_fifo;

architecture Behavioral of simple_fifo is

    -- Memory array for FIFO storage
    type memory_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal memory : memory_t := (others => (others => '0'));
    
    -- Read and write pointers
    signal wr_ptr : integer range 0 to DEPTH-1 := 0;
    signal rd_ptr : integer range 0 to DEPTH-1 := 0;
    
    -- Count of items in FIFO
    signal count : integer range 0 to DEPTH := 0;
    
    -- Status signals
    signal empty_i : std_logic;
    signal full_i : std_logic;

begin

    -- Status signals
    empty_i <= '1' when count = 0 else '0';
    full_i <= '1' when count = DEPTH else '0';
    
    empty <= empty_i;
    full <= full_i;
    
    -- FIFO write and read logic
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count <= 0;
                memory <= (others => (others => '0'));
            else
                -- Handle simultaneous read and write
                if wr_en = '1' and rd_en = '1' then
                    -- Both read and write - count stays the same
                    if full_i = '0' then
                        memory(wr_ptr) <= wr_data;
                        wr_ptr <= (wr_ptr + 1) mod DEPTH;
                    end if;
                    if empty_i = '0' then
                        rd_ptr <= (rd_ptr + 1) mod DEPTH;
                    end if;
                    
                elsif wr_en = '1' and full_i = '0' then
                    -- Write only
                    memory(wr_ptr) <= wr_data;
                    wr_ptr <= (wr_ptr + 1) mod DEPTH;
                    count <= count + 1;
                    
                elsif rd_en = '1' and empty_i = '0' then
                    -- Read only
                    rd_ptr <= (rd_ptr + 1) mod DEPTH;
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Read data output (combinational)
    rd_data <= memory(rd_ptr);

end Behavioral;
