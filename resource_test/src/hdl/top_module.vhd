library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Top module wrapper - minimal interface for FPGA
-- All pipeline I/O will be accessed via other means (e.g., ILA, future interfaces)
entity top_module is
    port (
        clk_in : in  std_logic;
        reset  : in  std_logic
    );
end top_module;

architecture Behavioral of top_module is

    component pipeline_hw is
        generic (
            NUM_MULT_UNITS    : integer := 8;
            NUM_FMA_UNITS     : integer := 5;
            NUM_ADD_UNITS     : integer := 3;
            NUM_PRODUCERS     : integer := 5;
            FIFO_DEPTH        : integer := 32
        );
        port (
            clk_in      : in  std_logic;
            reset       : in  std_logic;
            mult_wr_data  : in  std_logic_vector(NUM_MULT_UNITS*64-1 downto 0);
            mult_wr_tid   : in  std_logic_vector(NUM_MULT_UNITS*16-1 downto 0);
            mult_wr_valid : in  std_logic_vector(NUM_MULT_UNITS-1 downto 0);
            mult_wr_ready : out std_logic_vector(NUM_MULT_UNITS-1 downto 0);
            fma_wr_data  : in  std_logic_vector(NUM_FMA_UNITS*96-1 downto 0);
            fma_wr_tid   : in  std_logic_vector(NUM_FMA_UNITS*16-1 downto 0);
            fma_wr_valid : in  std_logic_vector(NUM_FMA_UNITS-1 downto 0);
            fma_wr_ready : out std_logic_vector(NUM_FMA_UNITS-1 downto 0);
            addsub_wr_data  : in  std_logic_vector(NUM_ADD_UNITS*65-1 downto 0);
            addsub_wr_tid   : in  std_logic_vector(NUM_ADD_UNITS*16-1 downto 0);
            addsub_wr_valid : in  std_logic_vector(NUM_ADD_UNITS-1 downto 0);
            addsub_wr_ready : out std_logic_vector(NUM_ADD_UNITS-1 downto 0);
            output_rd_data  : out std_logic_vector(NUM_PRODUCERS*32-1 downto 0);
            output_rd_tid   : out std_logic_vector(NUM_PRODUCERS*16-1 downto 0);
            output_rd_valid : out std_logic_vector(NUM_PRODUCERS-1 downto 0);
            output_rd_ready : in  std_logic_vector(NUM_PRODUCERS-1 downto 0);
            clk_locked : out std_logic
        );
    end component;
    
    -- Tie off all pipeline I/O (not used in this wrapper)
    signal mult_wr_data  : std_logic_vector(8*64-1 downto 0) := (others => '0');
    signal mult_wr_tid   : std_logic_vector(8*16-1 downto 0) := (others => '0');
    signal mult_wr_valid : std_logic_vector(7 downto 0) := (others => '0');
    signal mult_wr_ready : std_logic_vector(7 downto 0);
    
    signal fma_wr_data  : std_logic_vector(5*96-1 downto 0) := (others => '0');
    signal fma_wr_tid   : std_logic_vector(5*16-1 downto 0) := (others => '0');
    signal fma_wr_valid : std_logic_vector(4 downto 0) := (others => '0');
    signal fma_wr_ready : std_logic_vector(4 downto 0);
    
    signal addsub_wr_data  : std_logic_vector(3*65-1 downto 0) := (others => '0');
    signal addsub_wr_tid   : std_logic_vector(3*16-1 downto 0) := (others => '0');
    signal addsub_wr_valid : std_logic_vector(2 downto 0) := (others => '0');
    signal addsub_wr_ready : std_logic_vector(2 downto 0);
    
    signal output_rd_data  : std_logic_vector(5*32-1 downto 0);
    signal output_rd_tid   : std_logic_vector(5*16-1 downto 0);
    signal output_rd_valid : std_logic_vector(4 downto 0);
    signal output_rd_ready : std_logic_vector(4 downto 0) := (others => '0');
    
    signal clk_locked : std_logic;

begin

    -- Instantiate pipeline
    pipeline_inst : pipeline_hw
        generic map (
            NUM_MULT_UNITS => 8,
            NUM_FMA_UNITS  => 5,
            NUM_ADD_UNITS  => 3,
            NUM_PRODUCERS  => 5,
            FIFO_DEPTH     => 32
        )
        port map (
            clk_in          => clk_in,
            reset           => reset,
            mult_wr_data    => mult_wr_data,
            mult_wr_tid     => mult_wr_tid,
            mult_wr_valid   => mult_wr_valid,
            mult_wr_ready   => mult_wr_ready,
            fma_wr_data     => fma_wr_data,
            fma_wr_tid      => fma_wr_tid,
            fma_wr_valid    => fma_wr_valid,
            fma_wr_ready    => fma_wr_ready,
            addsub_wr_data  => addsub_wr_data,
            addsub_wr_tid   => addsub_wr_tid,
            addsub_wr_valid => addsub_wr_valid,
            addsub_wr_ready => addsub_wr_ready,
            output_rd_data  => output_rd_data,
            output_rd_tid   => output_rd_tid,
            output_rd_valid => output_rd_valid,
            output_rd_ready => output_rd_ready,
            clk_locked      => clk_locked
        );

end Behavioral;
