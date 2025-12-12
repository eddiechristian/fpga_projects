library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Top module for FP32 multiply FIFO (Stage 1)
-- Uses AXI4-Stream infrastructure with Xilinx IPs for routing
entity top_module is
    generic (
        NUM_MULTIPLIERS : integer := 10  -- Configurable number of parallel multipliers
    );
    port (
        -- Clock and reset
        clk_in      : in  std_logic;
        reset       : in  std_logic;
        
        -- Input interface (external data  input - 64-bit: operand_b & operand_a)
        input_tdata  : in  std_logic_vector(63 downto 0);
        input_tvalid : in  std_logic;
        input_tready : out std_logic;
        
        -- Output interface (external result read - 32-bit FP32 result)
        output_tdata  : out std_logic_vector(31 downto 0);
        output_tvalid : out std_logic;
        output_tready : in  std_logic;
        
        -- Status signals
        clk_locked         : out std_logic
    );
end top_module;

architecture Behavioral of top_module is
    
    -- Clock wizard component
    component clk_wiz_0 is
        port (
            clk_in1  : in  std_logic;
            reset    : in  std_logic;
            clk_out1 : out std_logic;
            locked   : out std_logic
        );
    end component;
    
    -- TDEST generator component
    component tdest_generator is
        generic (
            NUM_MULTIPLIERS : integer := 10
        );
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            s_axis_tdata    : in  std_logic_vector(63 downto 0);
            s_axis_tvalid   : in  std_logic;
            s_axis_tready   : out std_logic;
            m_axis_tdata    : out std_logic_vector(63 downto 0);
            m_axis_tdest    : out std_logic_vector(3 downto 0);
            m_axis_tvalid   : out std_logic;
            m_axis_tready   : in  std_logic
        );
    end component;
    
    -- AXI4-Stream Input FIFO component
    component axis_input_fifo is
        port (
            wr_rst_busy     : out std_logic;
            rd_rst_busy     : out std_logic;
            s_aclk          : in  std_logic;
            s_aresetn       : in  std_logic;
            s_axis_tvalid   : in  std_logic;
            s_axis_tready   : out std_logic;
            s_axis_tdata    : in  std_logic_vector(63 downto 0);
            s_axis_tuser    : in  std_logic_vector(3 downto 0);
            m_axis_tvalid   : out std_logic;
            m_axis_tready   : in  std_logic;
            m_axis_tdata    : out std_logic_vector(63 downto 0);
            m_axis_tuser    : out std_logic_vector(3 downto 0)
        );
    end component;
    
    -- AXI4-Stream Interconnect component (1-to-10)
    component axis_interconnect_0 is
        port (
            ACLK    : in  std_logic;
            ARESETN : in  std_logic;
            S00_AXIS_ACLK    : in  std_logic;
            S00_AXIS_ARESETN : in  std_logic;
            S00_AXIS_TVALID  : in  std_logic;
            S00_AXIS_TREADY  : out std_logic;
            S00_AXIS_TDATA   : in  std_logic_vector(63 downto 0);
            S00_AXIS_TDEST   : in  std_logic_vector(3 downto 0);
            M00_AXIS_ACLK    : in  std_logic;
            M00_AXIS_ARESETN : in  std_logic;
            M00_AXIS_TVALID  : out std_logic;
            M00_AXIS_TREADY  : in  std_logic;
            M00_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M01_AXIS_ACLK    : in  std_logic;
            M01_AXIS_ARESETN : in  std_logic;
            M01_AXIS_TVALID  : out std_logic;
            M01_AXIS_TREADY  : in  std_logic;
            M01_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M02_AXIS_ACLK    : in  std_logic;
            M02_AXIS_ARESETN : in  std_logic;
            M02_AXIS_TVALID  : out std_logic;
            M02_AXIS_TREADY  : in  std_logic;
            M02_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M03_AXIS_ACLK    : in  std_logic;
            M03_AXIS_ARESETN : in  std_logic;
            M03_AXIS_TVALID  : out std_logic;
            M03_AXIS_TREADY  : in  std_logic;
            M03_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M04_AXIS_ACLK    : in  std_logic;
            M04_AXIS_ARESETN : in  std_logic;
            M04_AXIS_TVALID  : out std_logic;
            M04_AXIS_TREADY  : in  std_logic;
            M04_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M05_AXIS_ACLK    : in  std_logic;
            M05_AXIS_ARESETN : in  std_logic;
            M05_AXIS_TVALID  : out std_logic;
            M05_AXIS_TREADY  : in  std_logic;
            M05_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M06_AXIS_ACLK    : in  std_logic;
            M06_AXIS_ARESETN : in  std_logic;
            M06_AXIS_TVALID  : out std_logic;
            M06_AXIS_TREADY  : in  std_logic;
            M06_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M07_AXIS_ACLK    : in  std_logic;
            M07_AXIS_ARESETN : in  std_logic;
            M07_AXIS_TVALID  : out std_logic;
            M07_AXIS_TREADY  : in  std_logic;
            M07_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M08_AXIS_ACLK    : in  std_logic;
            M08_AXIS_ARESETN : in  std_logic;
            M08_AXIS_TVALID  : out std_logic;
            M08_AXIS_TREADY  : in  std_logic;
            M08_AXIS_TDATA   : out std_logic_vector(63 downto 0);
            M09_AXIS_ACLK    : in  std_logic;
            M09_AXIS_ARESETN : in  std_logic;
            M09_AXIS_TVALID  : out std_logic;
            M09_AXIS_TREADY  : in  std_logic;
            M09_AXIS_TDATA   : out std_logic_vector(63 downto 0)
        );
    end component;
    
    -- Floating point multiplier component
    component floating_point_mult is
        port (
            aclk                : in  std_logic;
            s_axis_a_tvalid     : in  std_logic;
            s_axis_a_tdata      : in  std_logic_vector(31 downto 0);
            s_axis_b_tvalid     : in  std_logic;
            s_axis_b_tdata      : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid: out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Result collector component (10-to-1 round-robin)
    component result_collector is
        generic (
            NUM_INPUTS : integer := 10
        );
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            s_tvalid : in  std_logic_vector(9 downto 0);
            s_tready : out std_logic_vector(9 downto 0);
            s_tdata  : in  std_logic_vector(319 downto 0);
            m_tvalid : out std_logic;
            m_tready : in  std_logic;
            m_tdata  : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- AXI4-Stream Output FIFO component
    component axis_output_fifo is
        port (
            wr_rst_busy     : out std_logic;
            rd_rst_busy     : out std_logic;
            s_aclk          : in  std_logic;
            s_aresetn       : in  std_logic;
            s_axis_tvalid   : in  std_logic;
            s_axis_tready   : out std_logic;
            s_axis_tdata    : in  std_logic_vector(31 downto 0);
            m_axis_tvalid   : out std_logic;
            m_axis_tready   : in  std_logic;
            m_axis_tdata    : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Internal signals
    signal clk_150        : std_logic;
    signal locked         : std_logic;
    signal aresetn        : std_logic;
    
    -- TDEST generator signals
    signal tdest_tdata    : std_logic_vector(63 downto 0);
    signal tdest_tdest    : std_logic_vector(3 downto 0);
    signal tdest_tvalid   : std_logic;
    signal tdest_tready   : std_logic;
    
    -- Input FIFO signals
    signal fifo_in_tdata  : std_logic_vector(63 downto 0);
    signal fifo_in_tuser  : std_logic_vector(3 downto 0);
    signal fifo_in_tvalid : std_logic;
    signal fifo_in_tready : std_logic;
    
    -- Interconnect to multiplier signals (10 channels)
    type axis_data_array_64 is array (0 to 9) of std_logic_vector(63 downto 0);
    signal intercon_m_tdata  : axis_data_array_64;
    signal intercon_m_tvalid : std_logic_vector(9 downto 0);
    signal intercon_m_tready : std_logic_vector(9 downto 0);
    
    -- Multiplier result signals (10 channels)
    type axis_data_array_32 is array (0 to 9) of std_logic_vector(31 downto 0);
    signal mult_result_tdata  : axis_data_array_32;
    signal mult_result_tvalid : std_logic_vector(9 downto 0);
    signal mult_result_tready : std_logic_vector(9 downto 0);
    
    -- Combiner to output FIFO signals
    signal combiner_tdata  : std_logic_vector(31 downto 0);
    signal combiner_tvalid : std_logic;
    signal combiner_tready : std_logic;
    
    -- Concatenated signals for result_collector
    signal combiner_s_tdata  : std_logic_vector(319 downto 0);
    signal combiner_s_tvalid : std_logic_vector(9 downto 0);
    signal combiner_s_tready : std_logic_vector(9 downto 0);
    
begin
    
    -- Clock wizard instantiation
    clk_inst : clk_wiz_0
        port map (
            clk_in1  => clk_in,
            reset    => reset,
            clk_out1 => clk_150,
            locked   => locked
        );
    
    clk_locked <= locked;
    aresetn <= locked; -- Active-low reset for AXI
    
    -- TDEST generator (generates round-robin routing)
    tdest_gen : tdest_generator
        generic map (
            NUM_MULTIPLIERS => NUM_MULTIPLIERS
        )
        port map (
            clk           => clk_150,
            reset         => not aresetn,
            s_axis_tdata  => input_tdata,
            s_axis_tvalid => input_tvalid,
            s_axis_tready => input_tready,
            m_axis_tdata  => tdest_tdata,
            m_axis_tdest  => tdest_tdest,
            m_axis_tvalid => tdest_tvalid,
            m_axis_tready => tdest_tready
        );
    
    -- Input FIFO (buffers operations with TDEST/TUSER routing info)
    input_fifo_inst : axis_input_fifo
        port map (
            wr_rst_busy     => open,
            rd_rst_busy     => open,
            s_aclk          => clk_150,
            s_aresetn       => aresetn,
            s_axis_tvalid   => tdest_tvalid,
            s_axis_tready   => tdest_tready,
            s_axis_tdata    => tdest_tdata,
            s_axis_tuser    => tdest_tdest,
            m_axis_tvalid   => fifo_in_tvalid,
            m_axis_tready   => fifo_in_tready,
            m_axis_tdata    => fifo_in_tdata,
            m_axis_tuser    => fifo_in_tuser
        );
    
    -- AXI4-Stream Interconnect (routes to 10 multipliers based on TDEST)
    interconnect_inst : axis_interconnect_0
        port map (
            ACLK => clk_150,
            ARESETN => aresetn,
            -- Slave interface (from input FIFO)
            S00_AXIS_ACLK    => clk_150,
            S00_AXIS_ARESETN => aresetn,
            S00_AXIS_TVALID  => fifo_in_tvalid,
            S00_AXIS_TREADY  => fifo_in_tready,
            S00_AXIS_TDATA   => fifo_in_tdata,
            S00_AXIS_TDEST   => fifo_in_tuser, -- TUSER carries TDEST
            -- Master interfaces (to 10 multipliers)
            M00_AXIS_ACLK    => clk_150,
            M00_AXIS_ARESETN => aresetn,
            M00_AXIS_TVALID  => intercon_m_tvalid(0),
            M00_AXIS_TREADY  => intercon_m_tready(0),
            M00_AXIS_TDATA   => intercon_m_tdata(0),
            M01_AXIS_ACLK    => clk_150,
            M01_AXIS_ARESETN => aresetn,
            M01_AXIS_TVALID  => intercon_m_tvalid(1),
            M01_AXIS_TREADY  => intercon_m_tready(1),
            M01_AXIS_TDATA   => intercon_m_tdata(1),
            M02_AXIS_ACLK    => clk_150,
            M02_AXIS_ARESETN => aresetn,
            M02_AXIS_TVALID  => intercon_m_tvalid(2),
            M02_AXIS_TREADY  => intercon_m_tready(2),
            M02_AXIS_TDATA   => intercon_m_tdata(2),
            M03_AXIS_ACLK    => clk_150,
            M03_AXIS_ARESETN => aresetn,
            M03_AXIS_TVALID  => intercon_m_tvalid(3),
            M03_AXIS_TREADY  => intercon_m_tready(3),
            M03_AXIS_TDATA   => intercon_m_tdata(3),
            M04_AXIS_ACLK    => clk_150,
            M04_AXIS_ARESETN => aresetn,
            M04_AXIS_TVALID  => intercon_m_tvalid(4),
            M04_AXIS_TREADY  => intercon_m_tready(4),
            M04_AXIS_TDATA   => intercon_m_tdata(4),
            M05_AXIS_ACLK    => clk_150,
            M05_AXIS_ARESETN => aresetn,
            M05_AXIS_TVALID  => intercon_m_tvalid(5),
            M05_AXIS_TREADY  => intercon_m_tready(5),
            M05_AXIS_TDATA   => intercon_m_tdata(5),
            M06_AXIS_ACLK    => clk_150,
            M06_AXIS_ARESETN => aresetn,
            M06_AXIS_TVALID  => intercon_m_tvalid(6),
            M06_AXIS_TREADY  => intercon_m_tready(6),
            M06_AXIS_TDATA   => intercon_m_tdata(6),
            M07_AXIS_ACLK    => clk_150,
            M07_AXIS_ARESETN => aresetn,
            M07_AXIS_TVALID  => intercon_m_tvalid(7),
            M07_AXIS_TREADY  => intercon_m_tready(7),
            M07_AXIS_TDATA   => intercon_m_tdata(7),
            M08_AXIS_ACLK    => clk_150,
            M08_AXIS_ARESETN => aresetn,
            M08_AXIS_TVALID  => intercon_m_tvalid(8),
            M08_AXIS_TREADY  => intercon_m_tready(8),
            M08_AXIS_TDATA   => intercon_m_tdata(8),
            M09_AXIS_ACLK    => clk_150,
            M09_AXIS_ARESETN => aresetn,
            M09_AXIS_TVALID  => intercon_m_tvalid(9),
            M09_AXIS_TREADY  => intercon_m_tready(9),
            M09_AXIS_TDATA   => intercon_m_tdata(9)
        );
    
    -- Generate 10 FP32 multipliers
    gen_multipliers : for i in 0 to 9 generate
        mult_inst : floating_point_mult
            port map (
                aclk                 => clk_150,
                s_axis_a_tvalid      => intercon_m_tvalid(i),
                s_axis_a_tdata       => intercon_m_tdata(i)(31 downto 0),   -- operand_a
                s_axis_b_tvalid      => intercon_m_tvalid(i),
                s_axis_b_tdata       => intercon_m_tdata(i)(63 downto 32),  -- operand_b
                m_axis_result_tvalid => mult_result_tvalid(i),
                m_axis_result_tdata  => mult_result_tdata(i)
            );
        -- Multipliers always ready (NonBlocking mode)
        intercon_m_tready(i) <= '1';
    end generate;
    
    -- Concatenate multiplier results for result_collector
    gen_combiner_concat : for i in 0 to 9 generate
        combiner_s_tdata((i*32+31) downto (i*32))  <= mult_result_tdata(i);
        combiner_s_tvalid(i) <= mult_result_tvalid(i);
        mult_result_tready(i) <= combiner_s_tready(i);
    end generate;
    
    -- Result collector (round-robin collects results from 10 multipliers)
    collector_inst : result_collector
        generic map (
            NUM_INPUTS => 10
        )
        port map (
            clk      => clk_150,
            reset    => not aresetn,
            s_tvalid => combiner_s_tvalid,
            s_tready => combiner_s_tready,
            s_tdata  => combiner_s_tdata,
            m_tvalid => combiner_tvalid,
            m_tready => combiner_tready,
            m_tdata  => combiner_tdata
        );
    
    -- Output FIFO (buffers results)
    output_fifo_inst : axis_output_fifo
        port map (
            wr_rst_busy     => open,
            rd_rst_busy     => open,
            s_aclk          => clk_150,
            s_aresetn       => aresetn,
            s_axis_tvalid   => combiner_tvalid,
            s_axis_tready   => combiner_tready,
            s_axis_tdata    => combiner_tdata,
            m_axis_tvalid   => output_tvalid,
            m_axis_tready   => output_tready,
            m_axis_tdata    => output_tdata
        );
    
end Behavioral;
