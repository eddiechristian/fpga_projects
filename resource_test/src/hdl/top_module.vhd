library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Top module for FP32 multiply FIFO (Stage 1)
-- Uses AXI4-Stream infrastructure with Xilinx IPs for routing
--
-- VHDL-2008 Refactored Version:
-- - Fully parameterizable NUM_MULTIPLIERS without code changes
-- - Uses unconstrained arrays and generate statements
-- - Custom interconnect wrapper replaces hardcoded Xilinx IP
-- - Multi-producer output routing based on TID upper bits
entity top_module is
    generic (
        NUM_MULTIPLIERS     : integer := 20;  -- Number of parallel multipliers
        TDEST_WIDTH         : integer := 5;   -- TDEST width (ceil(log2(NUM_MULTIPLIERS)))
        NUM_PRODUCERS       : integer := 5;   -- Number of producers (output ports)
        PRODUCER_ID_WIDTH   : integer := 3    -- Producer ID width (ceil(log2(NUM_PRODUCERS)))
    );
    port (
        -- Clock and reset
        clk_in      : in  std_logic;
        reset       : in  std_logic;
        
        -- Input interface (external data input - 64-bit: operand_b & operand_a)
        input_tdata  : in  std_logic_vector(63 downto 0);
        input_tid    : in  std_logic_vector(15 downto 0);
        input_tvalid : in  std_logic;
        input_tready : out std_logic;
        
        -- Output interfaces (per-producer results - 32-bit FP32 result)
        -- Producer ID encoded in TID[15:13] (upper 3 bits for 5 producers)
        output_tdata  : out std_logic_vector(NUM_PRODUCERS*32-1 downto 0);
        output_tid    : out std_logic_vector(NUM_PRODUCERS*16-1 downto 0);
        output_tvalid : out std_logic_vector(NUM_PRODUCERS-1 downto 0);
        output_tready : in  std_logic_vector(NUM_PRODUCERS-1 downto 0);
        
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
            NUM_MULTIPLIERS : integer := 10;
            TDEST_WIDTH     : integer := 4
        );
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            s_axis_tdata    : in  std_logic_vector(63 downto 0);
            s_axis_tid      : in  std_logic_vector(15 downto 0);
            s_axis_tvalid   : in  std_logic;
            s_axis_tready   : out std_logic;
            m_axis_tdata    : out std_logic_vector(63 downto 0);
            m_axis_tdest    : out std_logic_vector(TDEST_WIDTH-1 downto 0);
            m_axis_tid      : out std_logic_vector(15 downto 0);
            m_axis_tvalid   : out std_logic;
            m_axis_tready   : in  std_logic
        );
    end component;
    
    -- AXI4-Stream Input FIFO component (uses IP-generated stub)
    component axis_input_fifo is
        port (
            wr_rst_busy     : out std_logic;
            rd_rst_busy     : out std_logic;
            s_aclk          : in  std_logic;
            s_aresetn       : in  std_logic;
            s_axis_tvalid   : in  std_logic;
            s_axis_tready   : out std_logic;
            s_axis_tdata    : in  std_logic_vector(63 downto 0);
            s_axis_tuser    : in  std_logic_vector(TDEST_WIDTH-1 downto 0);
            s_axis_tid      : in  std_logic_vector(15 downto 0);
            m_axis_tvalid   : out std_logic;
            m_axis_tready   : in  std_logic;
            m_axis_tdata    : out std_logic_vector(63 downto 0);
            m_axis_tuser    : out std_logic_vector(TDEST_WIDTH-1 downto 0);
            m_axis_tid      : out std_logic_vector(15 downto 0);
            axis_data_count : out std_logic_vector(10 downto 0)
        );
    end component;
    
    -- Parameterizable AXI4-Stream Interconnect Wrapper
    component axis_interconnect_wrapper is
        generic (
            NUM_MASTERS : integer := 10;
            TDEST_WIDTH : integer := 4;
            TDATA_WIDTH : integer := 64;
            TID_WIDTH   : integer := 16
        );
        port (
            aclk          : in  std_logic;
            aresetn       : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            s_axis_tdest  : in  std_logic_vector(TDEST_WIDTH-1 downto 0);
            s_axis_tid    : in  std_logic_vector(TID_WIDTH-1 downto 0);
            m_axis_tvalid : out std_logic_vector(NUM_MASTERS-1 downto 0);
            m_axis_tready : in  std_logic_vector(NUM_MASTERS-1 downto 0);
            m_axis_tdata  : out std_logic_vector(NUM_MASTERS*TDATA_WIDTH-1 downto 0);
            m_axis_tid    : out std_logic_vector(NUM_MASTERS*TID_WIDTH-1 downto 0)
        );
    end component;
    
    -- Floating point multiplier component
    component floating_point_mult is
        port (
            aclk                : in  std_logic;
            s_axis_a_tvalid     : in  std_logic;
            s_axis_a_tready     : out std_logic;
            s_axis_a_tdata      : in  std_logic_vector(31 downto 0);
            s_axis_b_tvalid     : in  std_logic;
            s_axis_b_tready     : out std_logic;
            s_axis_b_tdata      : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid: out std_logic;
            m_axis_result_tready: in  std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- TID pipeline component (delays TID through multiplier latency)
    component tid_pipeline is
        generic (
            LATENCY   : integer := 8;
            TID_WIDTH : integer := 16
        );
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            s_tid     : in  std_logic_vector(15 downto 0);
            s_tvalid  : in  std_logic;
            m_tid     : out std_logic_vector(15 downto 0);
            m_tvalid  : out std_logic
        );
    end component;
    
    -- Result collector component (N-to-1 round-robin with dynamic sizing)
    component result_collector is
        generic (
            NUM_INPUTS : integer := 10
        );
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            s_tvalid : in  std_logic_vector(NUM_INPUTS-1 downto 0);
            s_tready : out std_logic_vector(NUM_INPUTS-1 downto 0);
            s_tdata  : in  std_logic_vector(NUM_INPUTS*32-1 downto 0);
            s_tid    : in  std_logic_vector(NUM_INPUTS*16-1 downto 0);
            m_tvalid : out std_logic;
            m_tready : in  std_logic;
            m_tdata  : out std_logic_vector(31 downto 0);
            m_tid    : out std_logic_vector(15 downto 0)
        );
    end component;
    
    -- Output Demux component (routes results to producers based on TID)
    component output_demux is
        generic (
            NUM_PRODUCERS     : integer := 5;
            PRODUCER_ID_WIDTH : integer := 3;
            TDATA_WIDTH       : integer := 32;
            TID_WIDTH         : integer := 16
        );
        port (
            aclk          : in  std_logic;
            aresetn       : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(TDATA_WIDTH-1 downto 0);
            s_axis_tid    : in  std_logic_vector(TID_WIDTH-1 downto 0);
            m_axis_tvalid : out std_logic_vector(NUM_PRODUCERS-1 downto 0);
            m_axis_tready : in  std_logic_vector(NUM_PRODUCERS-1 downto 0);
            m_axis_tdata  : out std_logic_vector(NUM_PRODUCERS*TDATA_WIDTH-1 downto 0);
            m_axis_tid    : out std_logic_vector(NUM_PRODUCERS*TID_WIDTH-1 downto 0)
        );
    end component;
    
    -- Per-producer output FIFO component declarations
    component axis_output_fifo_0 is
        port (
            wr_rst_busy   : out std_logic;
            rd_rst_busy   : out std_logic;
            s_aclk        : in  std_logic;
            s_aresetn     : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            s_axis_tid    : in  std_logic_vector(15 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0);
            m_axis_tid    : out std_logic_vector(15 downto 0);
            axis_data_count : out std_logic_vector(10 downto 0)
        );
    end component;
    
    component axis_output_fifo_1 is
        port (
            wr_rst_busy   : out std_logic;
            rd_rst_busy   : out std_logic;
            s_aclk        : in  std_logic;
            s_aresetn     : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            s_axis_tid    : in  std_logic_vector(15 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0);
            m_axis_tid    : out std_logic_vector(15 downto 0);
            axis_data_count : out std_logic_vector(10 downto 0)
        );
    end component;
    
    component axis_output_fifo_2 is
        port (
            wr_rst_busy   : out std_logic;
            rd_rst_busy   : out std_logic;
            s_aclk        : in  std_logic;
            s_aresetn     : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            s_axis_tid    : in  std_logic_vector(15 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0);
            m_axis_tid    : out std_logic_vector(15 downto 0);
            axis_data_count : out std_logic_vector(10 downto 0)
        );
    end component;
    
    component axis_output_fifo_3 is
        port (
            wr_rst_busy   : out std_logic;
            rd_rst_busy   : out std_logic;
            s_aclk        : in  std_logic;
            s_aresetn     : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            s_axis_tid    : in  std_logic_vector(15 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0);
            m_axis_tid    : out std_logic_vector(15 downto 0);
            axis_data_count : out std_logic_vector(10 downto 0)
        );
    end component;
    
    component axis_output_fifo_4 is
        port (
            wr_rst_busy   : out std_logic;
            rd_rst_busy   : out std_logic;
            s_aclk        : in  std_logic;
            s_aresetn     : in  std_logic;
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            s_axis_tid    : in  std_logic_vector(15 downto 0);
            m_axis_tvalid : out std_logic;
            m_axis_tready : in  std_logic;
            m_axis_tdata  : out std_logic_vector(31 downto 0);
            m_axis_tid    : out std_logic_vector(15 downto 0);
            axis_data_count : out std_logic_vector(10 downto 0)
        );
    end component;
    
    -- Internal signals
    signal clk_200        : std_logic;
    signal locked         : std_logic;
    signal aresetn        : std_logic;
    
    -- TDEST generator signals
    signal tdest_tdata    : std_logic_vector(63 downto 0);
    signal tdest_tdest    : std_logic_vector(TDEST_WIDTH-1 downto 0);
    signal tdest_tid      : std_logic_vector(15 downto 0);
    signal tdest_tvalid   : std_logic;
    signal tdest_tready   : std_logic;
    
    -- Input FIFO signals
    signal fifo_in_tdata  : std_logic_vector(63 downto 0);
    signal fifo_in_tuser  : std_logic_vector(TDEST_WIDTH-1 downto 0);
    signal fifo_in_tid    : std_logic_vector(15 downto 0);
    signal fifo_in_tvalid : std_logic;
    signal fifo_in_tready : std_logic;
    
    -- Interconnect to multiplier signals (parameterized)
    signal intercon_m_tvalid : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    signal intercon_m_tready : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    signal intercon_m_tdata  : std_logic_vector(NUM_MULTIPLIERS*64-1 downto 0);
    signal intercon_m_tid    : std_logic_vector(NUM_MULTIPLIERS*16-1 downto 0);
    
    -- Multiplier result signals (parameterized)
    signal mult_result_tvalid : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    signal mult_result_tready : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    signal mult_result_tdata  : std_logic_vector(NUM_MULTIPLIERS*32-1 downto 0);
    
    -- TID pipeline signals (parameterized)
    signal tid_pipe_m_tid    : std_logic_vector(NUM_MULTIPLIERS*16-1 downto 0);
    signal tid_pipe_m_tvalid : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    
    -- Combiner to output FIFO signals
    signal combiner_tdata  : std_logic_vector(31 downto 0);
    signal combiner_tid    : std_logic_vector(15 downto 0);
    signal combiner_tvalid : std_logic;
    signal combiner_tready : std_logic;
    
    -- Concatenated signals for result_collector (parameterized)
    signal combiner_s_tdata  : std_logic_vector(NUM_MULTIPLIERS*32-1 downto 0);
    signal combiner_s_tid    : std_logic_vector(NUM_MULTIPLIERS*16-1 downto 0);
    signal combiner_s_tvalid : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    signal combiner_s_tready : std_logic_vector(NUM_MULTIPLIERS-1 downto 0);
    
    -- Output demux to per-producer FIFOs signals
    signal demux_m_tvalid : std_logic_vector(NUM_PRODUCERS-1 downto 0);
    signal demux_m_tready : std_logic_vector(NUM_PRODUCERS-1 downto 0);
    signal demux_m_tdata  : std_logic_vector(NUM_PRODUCERS*32-1 downto 0);
    signal demux_m_tid    : std_logic_vector(NUM_PRODUCERS*16-1 downto 0);
    
    -- FIFO data count signals (for debug/monitoring)
    signal input_fifo_count    : std_logic_vector(10 downto 0);
    signal output_fifo_0_count : std_logic_vector(10 downto 0);
    signal output_fifo_1_count : std_logic_vector(10 downto 0);
    signal output_fifo_2_count : std_logic_vector(10 downto 0);
    signal output_fifo_3_count : std_logic_vector(10 downto 0);
    signal output_fifo_4_count : std_logic_vector(10 downto 0);
    
begin
    
    -- Clock wizard instantiation
    clk_inst : clk_wiz_0
        port map (
            clk_in1  => clk_in,
            reset    => reset,
            clk_out1 => clk_200,
            locked   => locked
        );
    
    clk_locked <= locked;
    aresetn <= locked; -- Active-low reset for AXI
    
    -- TDEST generator (generates round-robin routing)
    tdest_gen : tdest_generator
        generic map (
            NUM_MULTIPLIERS => NUM_MULTIPLIERS,
            TDEST_WIDTH     => TDEST_WIDTH
        )
        port map (
            clk           => clk_200,
            reset         => not aresetn,
            s_axis_tdata  => input_tdata,
            s_axis_tid    => input_tid,
            s_axis_tvalid => input_tvalid,
            s_axis_tready => input_tready,
            m_axis_tdata  => tdest_tdata,
            m_axis_tdest  => tdest_tdest,
            m_axis_tid    => tdest_tid,
            m_axis_tvalid => tdest_tvalid,
            m_axis_tready => tdest_tready
        );
    
    -- Input FIFO (buffers operations with TDEST/TUSER routing info and TID)
    input_fifo_inst : axis_input_fifo
        port map (
            wr_rst_busy     => open,
            rd_rst_busy     => open,
            s_aclk          => clk_200,
            s_aresetn       => aresetn,
            s_axis_tvalid   => tdest_tvalid,
            s_axis_tready   => tdest_tready,
            s_axis_tdata    => tdest_tdata,
            s_axis_tuser    => tdest_tdest,
            s_axis_tid      => tdest_tid,
            m_axis_tvalid   => fifo_in_tvalid,
            m_axis_tready   => fifo_in_tready,
            m_axis_tdata    => fifo_in_tdata,
            m_axis_tuser    => fifo_in_tuser,
            m_axis_tid      => fifo_in_tid,
            axis_data_count => input_fifo_count
        );
    
    -- AXI4-Stream Interconnect Wrapper (parameterizable 1-to-N routing)
    interconnect_inst : axis_interconnect_wrapper
        generic map (
            NUM_MASTERS => NUM_MULTIPLIERS,
            TDEST_WIDTH => TDEST_WIDTH,
            TDATA_WIDTH => 64,
            TID_WIDTH   => 16
        )
        port map (
            aclk          => clk_200,
            aresetn       => aresetn,
            s_axis_tvalid => fifo_in_tvalid,
            s_axis_tready => fifo_in_tready,
            s_axis_tdata  => fifo_in_tdata,
            s_axis_tdest  => fifo_in_tuser,
            s_axis_tid    => fifo_in_tid,
            m_axis_tvalid => intercon_m_tvalid,
            m_axis_tready => intercon_m_tready,
            m_axis_tdata  => intercon_m_tdata,
            m_axis_tid    => intercon_m_tid
        );
    
    -- Generate N FP32 multipliers and TID pipelines (fully parameterized)
    gen_multipliers : for i in 0 to NUM_MULTIPLIERS-1 generate
        -- FP32 multiplier instance
        mult_inst : floating_point_mult
            port map (
                aclk                 => clk_200,
                s_axis_a_tvalid      => intercon_m_tvalid(i),
                s_axis_a_tready      => intercon_m_tready(i),
                s_axis_a_tdata       => intercon_m_tdata(i*64+31 downto i*64),      -- operand_a (lower 32 bits)
                s_axis_b_tvalid      => intercon_m_tvalid(i),
                s_axis_b_tready      => open,  -- Both channels synchronized, only monitor a_tready
                s_axis_b_tdata       => intercon_m_tdata(i*64+63 downto i*64+32),   -- operand_b (upper 32 bits)
                m_axis_result_tvalid => mult_result_tvalid(i),
                m_axis_result_tready => mult_result_tready(i),
                m_axis_result_tdata  => mult_result_tdata((i+1)*32-1 downto i*32)
            );
        
        -- TID pipeline (delays TID by 8 cycles to match multiplier latency)
        tid_pipe_inst : tid_pipeline
            generic map (
                LATENCY   => 8,
                TID_WIDTH => 16
            )
            port map (
                clk      => clk_200,
                reset    => not aresetn,
                s_tid    => intercon_m_tid((i+1)*16-1 downto i*16),
                s_tvalid => intercon_m_tvalid(i),
                m_tid    => tid_pipe_m_tid((i+1)*16-1 downto i*16),
            m_tvalid => tid_pipe_m_tvalid(i)
            );
    end generate;
    
    -- Concatenate multiplier results and TIDs for result_collector
    gen_combiner_concat : for i in 0 to NUM_MULTIPLIERS-1 generate
        combiner_s_tdata((i+1)*32-1 downto i*32)  <= mult_result_tdata((i+1)*32-1 downto i*32);
        combiner_s_tid((i+1)*16-1 downto i*16)    <= tid_pipe_m_tid((i+1)*16-1 downto i*16);
        combiner_s_tvalid(i) <= mult_result_tvalid(i);
        mult_result_tready(i) <= combiner_s_tready(i);
    end generate;
    
    -- Result collector (round-robin collects results and TIDs from N multipliers)
    collector_inst : result_collector
        generic map (
            NUM_INPUTS => NUM_MULTIPLIERS
        )
        port map (
            clk      => clk_200,
            reset    => not aresetn,
            s_tvalid => combiner_s_tvalid,
            s_tready => combiner_s_tready,
            s_tdata  => combiner_s_tdata,
            s_tid    => combiner_s_tid,
            m_tvalid => combiner_tvalid,
            m_tready => combiner_tready,
            m_tdata  => combiner_tdata,
            m_tid    => combiner_tid
        );
    
    -- Output Demux (routes results to correct producer based on TID upper bits)
    demux_inst : output_demux
        generic map (
            NUM_PRODUCERS     => NUM_PRODUCERS,
            PRODUCER_ID_WIDTH => PRODUCER_ID_WIDTH,
            TDATA_WIDTH       => 32,
            TID_WIDTH         => 16
        )
        port map (
            aclk          => clk_200,
            aresetn       => aresetn,
            s_axis_tvalid => combiner_tvalid,
            s_axis_tready => combiner_tready,
            s_axis_tdata  => combiner_tdata,
            s_axis_tid    => combiner_tid,
            m_axis_tvalid => demux_m_tvalid,
            m_axis_tready => demux_m_tready,
            m_axis_tdata  => demux_m_tdata,
            m_axis_tid    => demux_m_tid
        );
    
    -- Instantiate all 5 output FIFOs
    output_fifo_0_inst : axis_output_fifo_0
        port map (
            wr_rst_busy   => open,
            rd_rst_busy   => open,
            s_aclk        => clk_200,
            s_aresetn     => aresetn,
            s_axis_tvalid => demux_m_tvalid(0),
            s_axis_tready => demux_m_tready(0),
            s_axis_tdata => demux_m_tdata(31 downto 0),
            s_axis_tid => demux_m_tid(15 downto 0),
            m_axis_tvalid => output_tvalid(0),
            m_axis_tready => output_tready(0),
            m_axis_tdata => output_tdata(31 downto 0),
            m_axis_tid => output_tid(15 downto 0),
            axis_data_count => output_fifo_0_count
        );
    
    output_fifo_1_inst : axis_output_fifo_1
        port map (
            wr_rst_busy   => open,
            rd_rst_busy   => open,
            s_aclk        => clk_200,
            s_aresetn     => aresetn,
            s_axis_tvalid => demux_m_tvalid(1),
            s_axis_tready => demux_m_tready(1),
            s_axis_tdata => demux_m_tdata(63 downto 32),
            s_axis_tid => demux_m_tid(31 downto 16),
            m_axis_tvalid => output_tvalid(1),
            m_axis_tready => output_tready(1),
            m_axis_tdata => output_tdata(63 downto 32),
            m_axis_tid => output_tid(31 downto 16),
            axis_data_count => output_fifo_1_count
        );
    
    output_fifo_2_inst : axis_output_fifo_2
        port map (
            wr_rst_busy   => open,
            rd_rst_busy   => open,
            s_aclk        => clk_200,
            s_aresetn     => aresetn,
            s_axis_tvalid => demux_m_tvalid(2),
            s_axis_tready => demux_m_tready(2),
            s_axis_tdata => demux_m_tdata(95 downto 64),
            s_axis_tid => demux_m_tid(47 downto 32),
            m_axis_tvalid => output_tvalid(2),
            m_axis_tready => output_tready(2),
            m_axis_tdata => output_tdata(95 downto 64),
            m_axis_tid => output_tid(47 downto 32),
            axis_data_count => output_fifo_2_count
        );
    
    output_fifo_3_inst : axis_output_fifo_3
        port map (
            wr_rst_busy   => open,
            rd_rst_busy   => open,
            s_aclk        => clk_200,
            s_aresetn     => aresetn,
            s_axis_tvalid => demux_m_tvalid(3),
            s_axis_tready => demux_m_tready(3),
            s_axis_tdata => demux_m_tdata(127 downto 96),
            s_axis_tid => demux_m_tid(63 downto 48),
            m_axis_tvalid => output_tvalid(3),
            m_axis_tready => output_tready(3),
            m_axis_tdata => output_tdata(127 downto 96),
            m_axis_tid => output_tid(63 downto 48),
            axis_data_count => output_fifo_3_count
        );
    
    output_fifo_4_inst : axis_output_fifo_4
        port map (
            wr_rst_busy   => open,
            rd_rst_busy   => open,
            s_aclk        => clk_200,
            s_aresetn     => aresetn,
            s_axis_tvalid => demux_m_tvalid(4),
            s_axis_tready => demux_m_tready(4),
            s_axis_tdata => demux_m_tdata(159 downto 128),
            s_axis_tid => demux_m_tid(79 downto 64),
            m_axis_tvalid => output_tvalid(4),
            m_axis_tready => output_tready(4),
            m_axis_tdata => output_tdata(159 downto 128),
            m_axis_tid => output_tid(79 downto 64),
            axis_data_count => output_fifo_4_count
        );
    
end Behavioral;
