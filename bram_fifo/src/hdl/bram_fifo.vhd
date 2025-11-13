library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity bram_fifo is
    Generic (
        DATA_WIDTH : integer := 32;
        FIFO_DEPTH : integer := 512;
        ADDR_WIDTH : integer := 9
    );
    Port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        
        -- Write interface
        wr_en   : in  std_logic;
        wr_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        full    : out std_logic;
        
        -- Read interface
        rd_en   : in  std_logic;
        rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
        empty   : out std_logic
    );
end bram_fifo;

architecture Structural of bram_fifo is
    -- Component declaration for BRAM IP (True Dual Port)
    component bram_tdp
        port (
            clka  : in  std_logic;
            wea   : in  std_logic_vector(0 downto 0);
            addra : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            dina  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            douta : out std_logic_vector(DATA_WIDTH-1 downto 0);
            
            clkb  : in  std_logic;
            web   : in  std_logic_vector(0 downto 0);
            addrb : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            dinb  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            doutb : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- Component declaration for FIFO controller
    component fifo_controller is
        Generic (
            ADDR_WIDTH : integer := 9;
            DATA_WIDTH : integer := 32
        );
        Port (
            clk          : in  std_logic;
            rst          : in  std_logic;
            wr_en        : in  std_logic;
            wr_data      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            full         : out std_logic;
            rd_en        : in  std_logic;
            rd_data      : out std_logic_vector(DATA_WIDTH-1 downto 0);
            empty        : out std_logic;
            bram_wr_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
            bram_wr_en   : out std_logic;
            bram_wr_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
            bram_rd_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
            bram_rd_en   : out std_logic;
            bram_rd_data : in  std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- Internal signals connecting controller to BRAM
    signal bram_wr_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal bram_wr_en   : std_logic;
    signal bram_wr_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal bram_rd_addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
    signal bram_rd_en   : std_logic;
    signal bram_rd_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Convert single bit enable to vector for BRAM IP
    signal wea_vec : std_logic_vector(0 downto 0);
    signal web_vec : std_logic_vector(0 downto 0);
    
begin
    -- Convert enable signals to vectors
    wea_vec(0) <= bram_wr_en;
    web_vec(0) <= '0';  -- Port B is read-only
    
    -- Instantiate FIFO controller
    fifo_ctrl_inst : fifo_controller
        generic map (
            ADDR_WIDTH => ADDR_WIDTH,
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk          => clk,
            rst          => rst,
            wr_en        => wr_en,
            wr_data      => wr_data,
            full         => full,
            rd_en        => rd_en,
            rd_data      => rd_data,
            empty        => empty,
            bram_wr_addr => bram_wr_addr,
            bram_wr_en   => bram_wr_en,
            bram_wr_data => bram_wr_data,
            bram_rd_addr => bram_rd_addr,
            bram_rd_en   => bram_rd_en,
            bram_rd_data => bram_rd_data
        );
    
    -- Instantiate BRAM IP (True Dual Port)
    bram_inst : bram_tdp
        port map (
            -- Port A: Write port
            clka  => clk,
            wea   => wea_vec,
            addra => bram_wr_addr,
            dina  => bram_wr_data,
            douta => open,
            
            -- Port B: Read port
            clkb  => clk,
            web   => web_vec,
            addrb => bram_rd_addr,
            dinb  => (others => '0'),
            doutb => bram_rd_data
        );

end Structural;

