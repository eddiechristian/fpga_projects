library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Option D: Simplified pipeline with per-unit FIFOs
-- Architecture: Input FIFOs → FP Units (NonBlocking) → Output FIFOs
-- No interconnect, no demux, no collector - just FIFOs and FP units
entity pipeline_hw is
    generic (
        NUM_MULT_UNITS    : integer := 8;
        NUM_FMA_UNITS     : integer := 5;
        NUM_ADD_UNITS     : integer := 3;
        NUM_PRODUCERS     : integer := 5;
        FIFO_DEPTH        : integer := 32
    );
    port (
        -- Clock and reset
        clk_in      : in  std_logic;
        reset       : in  std_logic;
        
        -- Multiplier inputs (8 units)
        mult_wr_data  : in  std_logic_vector(NUM_MULT_UNITS*64-1 downto 0);  -- {B[31:0], A[31:0]} per unit
        mult_wr_tid   : in  std_logic_vector(NUM_MULT_UNITS*16-1 downto 0);
        mult_wr_valid : in  std_logic_vector(NUM_MULT_UNITS-1 downto 0);
        mult_wr_ready : out std_logic_vector(NUM_MULT_UNITS-1 downto 0);
        
        -- FMA inputs (5 units)
        fma_wr_data  : in  std_logic_vector(NUM_FMA_UNITS*96-1 downto 0);   -- {C[31:0], B[31:0], A[31:0]} per unit
        fma_wr_tid   : in  std_logic_vector(NUM_FMA_UNITS*16-1 downto 0);
        fma_wr_valid : in  std_logic_vector(NUM_FMA_UNITS-1 downto 0);
        fma_wr_ready : out std_logic_vector(NUM_FMA_UNITS-1 downto 0);
        
        -- AddSub inputs (3 units)
        addsub_wr_data  : in  std_logic_vector(NUM_ADD_UNITS*65-1 downto 0); -- {op[0], B[31:0], A[31:0]} per unit
        addsub_wr_tid   : in  std_logic_vector(NUM_ADD_UNITS*16-1 downto 0);
        addsub_wr_valid : in  std_logic_vector(NUM_ADD_UNITS-1 downto 0);
        addsub_wr_ready : out std_logic_vector(NUM_ADD_UNITS-1 downto 0);
        
        -- Output interfaces (per producer)
        output_rd_data  : out std_logic_vector(NUM_PRODUCERS*32-1 downto 0);
        output_rd_tid   : out std_logic_vector(NUM_PRODUCERS*16-1 downto 0);
        output_rd_valid : out std_logic_vector(NUM_PRODUCERS-1 downto 0);
        output_rd_ready : in  std_logic_vector(NUM_PRODUCERS-1 downto 0);
        
        -- Status
        clk_locked : out std_logic
    );
end pipeline_hw;

architecture Behavioral of pipeline_hw is

    constant TOTAL_FP_UNITS : integer := NUM_MULT_UNITS + NUM_FMA_UNITS + NUM_ADD_UNITS;

    -- Clock wizard
    component clk_wiz_0 is
        port (
            clk_in1  : in  std_logic;
            reset    : in  std_logic;
            clk_out1 : out std_logic;
            locked   : out std_logic
        );
    end component;
    
    -- Custom FIFO
    component sync_fifo is
        generic (
            DATA_WIDTH : integer := 32;
            TID_WIDTH  : integer := 16;
            DEPTH      : integer := 32
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            wr_data     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            wr_tid      : in  std_logic_vector(TID_WIDTH-1 downto 0);
            wr_valid    : in  std_logic;
            wr_ready    : out std_logic;
            rd_data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
            rd_tid      : out std_logic_vector(TID_WIDTH-1 downto 0);
            rd_valid    : out std_logic;
            rd_ready    : in  std_logic;
            full        : out std_logic;
            empty       : out std_logic;
            almost_full : out std_logic
        );
    end component;
    
    -- FP Multiplier (NonBlocking mode)
    component floating_point_mult is
        port (
            aclk                : in  std_logic;
            s_axis_a_tvalid     : in  std_logic;
            s_axis_a_tdata      : in  std_logic_vector(31 downto 0);
            s_axis_a_tuser      : in  std_logic_vector(15 downto 0);
            s_axis_b_tvalid     : in  std_logic;
            s_axis_b_tdata      : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid: out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0);
            m_axis_result_tuser : out std_logic_vector(15 downto 0)
        );
    end component;
    
    -- FP FMA (NonBlocking mode)
    component floating_point_fma is
        port (
            aclk                  : in  std_logic;
            s_axis_a_tvalid       : in  std_logic;
            s_axis_a_tdata        : in  std_logic_vector(31 downto 0);
            s_axis_a_tuser        : in  std_logic_vector(15 downto 0);
            s_axis_b_tvalid       : in  std_logic;
            s_axis_b_tdata        : in  std_logic_vector(31 downto 0);
            s_axis_c_tvalid       : in  std_logic;
            s_axis_c_tdata        : in  std_logic_vector(31 downto 0);
            s_axis_operation_tvalid : in  std_logic;
            s_axis_operation_tdata  : in  std_logic_vector(7 downto 0);
            m_axis_result_tvalid  : out std_logic;
            m_axis_result_tdata   : out std_logic_vector(31 downto 0);
            m_axis_result_tuser   : out std_logic_vector(15 downto 0)
        );
    end component;
    
    -- FP AddSub (NonBlocking mode)
    component floating_point_addsub is
        port (
            aclk                  : in  std_logic;
            s_axis_a_tvalid       : in  std_logic;
            s_axis_a_tdata        : in  std_logic_vector(31 downto 0);
            s_axis_a_tuser        : in  std_logic_vector(15 downto 0);
            s_axis_b_tvalid       : in  std_logic;
            s_axis_b_tdata        : in  std_logic_vector(31 downto 0);
            s_axis_operation_tvalid : in  std_logic;
            s_axis_operation_tdata  : in  std_logic_vector(7 downto 0);
            m_axis_result_tvalid  : out std_logic;
            m_axis_result_tdata   : out std_logic_vector(31 downto 0);
            m_axis_result_tuser   : out std_logic_vector(15 downto 0)
        );
    end component;

    -- Signals
    signal clk : std_logic;
    signal locked : std_logic;
    signal reset_n : std_logic;
    
    -- Input FIFO → FP unit signals
    signal mult_fifo_rd_data  : std_logic_vector(NUM_MULT_UNITS*64-1 downto 0);
    signal mult_fifo_rd_tid   : std_logic_vector(NUM_MULT_UNITS*16-1 downto 0);
    signal mult_fifo_rd_valid : std_logic_vector(NUM_MULT_UNITS-1 downto 0);
    signal mult_fifo_rd_ready : std_logic_vector(NUM_MULT_UNITS-1 downto 0);
    
    signal fma_fifo_rd_data  : std_logic_vector(NUM_FMA_UNITS*96-1 downto 0);
    signal fma_fifo_rd_tid   : std_logic_vector(NUM_FMA_UNITS*16-1 downto 0);
    signal fma_fifo_rd_valid : std_logic_vector(NUM_FMA_UNITS-1 downto 0);
    signal fma_fifo_rd_ready : std_logic_vector(NUM_FMA_UNITS-1 downto 0);
    
    signal addsub_fifo_rd_data  : std_logic_vector(NUM_ADD_UNITS*65-1 downto 0);
    signal addsub_fifo_rd_tid   : std_logic_vector(NUM_ADD_UNITS*16-1 downto 0);
    signal addsub_fifo_rd_valid : std_logic_vector(NUM_ADD_UNITS-1 downto 0);
    signal addsub_fifo_rd_ready : std_logic_vector(NUM_ADD_UNITS-1 downto 0);
    
    -- FP unit → Output FIFO signals  
    signal mult_result_data  : std_logic_vector(NUM_MULT_UNITS*32-1 downto 0);
    signal mult_result_tid   : std_logic_vector(NUM_MULT_UNITS*16-1 downto 0);
    signal mult_result_valid : std_logic_vector(NUM_MULT_UNITS-1 downto 0);
    
    signal fma_result_data  : std_logic_vector(NUM_FMA_UNITS*32-1 downto 0);
    signal fma_result_tid   : std_logic_vector(NUM_FMA_UNITS*16-1 downto 0);
    signal fma_result_valid : std_logic_vector(NUM_FMA_UNITS-1 downto 0);
    
    signal addsub_result_data  : std_logic_vector(NUM_ADD_UNITS*32-1 downto 0);
    signal addsub_result_tid   : std_logic_vector(NUM_ADD_UNITS*16-1 downto 0);
    signal addsub_result_valid : std_logic_vector(NUM_ADD_UNITS-1 downto 0);
    
    -- Combined results from all FP units (for output routing)
    signal all_results_data  : std_logic_vector(TOTAL_FP_UNITS*32-1 downto 0);
    signal all_results_tid   : std_logic_vector(TOTAL_FP_UNITS*16-1 downto 0);
    signal all_results_valid : std_logic_vector(TOTAL_FP_UNITS-1 downto 0);
    signal all_results_ready : std_logic_vector(TOTAL_FP_UNITS-1 downto 0);
    
begin

    reset_n <= not reset;
    clk_locked <= locked;

    -- Clock wizard
    clk_inst : clk_wiz_0
        port map (
            clk_in1  => clk_in,
            reset    => reset,
            clk_out1 => clk,
            locked   => locked
        );

    -- Multiplier units with input FIFOs
    gen_mult : for i in 0 to NUM_MULT_UNITS-1 generate
        -- Input FIFO
        mult_fifo : sync_fifo
            generic map (
                DATA_WIDTH => 64,
                TID_WIDTH  => 16,
                DEPTH      => FIFO_DEPTH
            )
            port map (
                clk      => clk,
                reset    => reset,
                wr_data  => mult_wr_data((i+1)*64-1 downto i*64),
                wr_tid   => mult_wr_tid((i+1)*16-1 downto i*16),
                wr_valid => mult_wr_valid(i),
                wr_ready => mult_wr_ready(i),
                rd_data  => mult_fifo_rd_data((i+1)*64-1 downto i*64),
                rd_tid   => mult_fifo_rd_tid((i+1)*16-1 downto i*16),
                rd_valid => mult_fifo_rd_valid(i),
                rd_ready => mult_fifo_rd_ready(i),
                full     => open,
                empty    => open,
                almost_full => open
            );
        
        -- FP Multiplier
        mult_inst : floating_point_mult
            port map (
                aclk                 => clk,
                s_axis_a_tvalid      => mult_fifo_rd_valid(i),
                s_axis_a_tdata       => mult_fifo_rd_data(i*64+31 downto i*64),
                s_axis_a_tuser       => mult_fifo_rd_tid((i+1)*16-1 downto i*16),
                s_axis_b_tvalid      => mult_fifo_rd_valid(i),
                s_axis_b_tdata       => mult_fifo_rd_data((i+1)*64-1 downto i*64+32),
                m_axis_result_tvalid => mult_result_valid(i),
                m_axis_result_tdata  => mult_result_data((i+1)*32-1 downto i*32),
                m_axis_result_tuser  => mult_result_tid((i+1)*16-1 downto i*16)
            );
        
        -- In NonBlocking mode, always ready to accept from FIFO
        mult_fifo_rd_ready(i) <= '1';
    end generate;

    -- FMA units with input FIFOs
    gen_fma : for i in 0 to NUM_FMA_UNITS-1 generate
        -- Input FIFO
        fma_fifo : sync_fifo
            generic map (
                DATA_WIDTH => 96,
                TID_WIDTH  => 16,
                DEPTH      => FIFO_DEPTH
            )
            port map (
                clk      => clk,
                reset    => reset,
                wr_data  => fma_wr_data((i+1)*96-1 downto i*96),
                wr_tid   => fma_wr_tid((i+1)*16-1 downto i*16),
                wr_valid => fma_wr_valid(i),
                wr_ready => fma_wr_ready(i),
                rd_data  => fma_fifo_rd_data((i+1)*96-1 downto i*96),
                rd_tid   => fma_fifo_rd_tid((i+1)*16-1 downto i*16),
                rd_valid => fma_fifo_rd_valid(i),
                rd_ready => fma_fifo_rd_ready(i),
                full     => open,
                empty    => open,
                almost_full => open
            );
        
        -- FP FMA
        fma_inst : floating_point_fma
            port map (
                aclk                     => clk,
                s_axis_a_tvalid          => fma_fifo_rd_valid(i),
                s_axis_a_tdata           => fma_fifo_rd_data(i*96+31 downto i*96),
                s_axis_a_tuser           => fma_fifo_rd_tid((i+1)*16-1 downto i*16),
                s_axis_b_tvalid          => fma_fifo_rd_valid(i),
                s_axis_b_tdata           => fma_fifo_rd_data(i*96+63 downto i*96+32),
                s_axis_c_tvalid          => fma_fifo_rd_valid(i),
                s_axis_c_tdata           => fma_fifo_rd_data((i+1)*96-1 downto i*96+64),
                s_axis_operation_tvalid  => fma_fifo_rd_valid(i),
                s_axis_operation_tdata   => x"00",  -- FMA operation
                m_axis_result_tvalid     => fma_result_valid(i),
                m_axis_result_tdata      => fma_result_data((i+1)*32-1 downto i*32),
                m_axis_result_tuser      => fma_result_tid((i+1)*16-1 downto i*16)
            );
        
        fma_fifo_rd_ready(i) <= '1';
    end generate;

    -- AddSub units with input FIFOs
    gen_addsub : for i in 0 to NUM_ADD_UNITS-1 generate
        -- Input FIFO
        addsub_fifo : sync_fifo
            generic map (
                DATA_WIDTH => 65,
                TID_WIDTH  => 16,
                DEPTH      => FIFO_DEPTH
            )
            port map (
                clk      => clk,
                reset    => reset,
                wr_data  => addsub_wr_data((i+1)*65-1 downto i*65),
                wr_tid   => addsub_wr_tid((i+1)*16-1 downto i*16),
                wr_valid => addsub_wr_valid(i),
                wr_ready => addsub_wr_ready(i),
                rd_data  => addsub_fifo_rd_data((i+1)*65-1 downto i*65),
                rd_tid   => addsub_fifo_rd_tid((i+1)*16-1 downto i*16),
                rd_valid => addsub_fifo_rd_valid(i),
                rd_ready => addsub_fifo_rd_ready(i),
                full     => open,
                empty    => open,
                almost_full => open
            );
        
        -- FP AddSub
        addsub_inst : floating_point_addsub
            port map (
                aclk                     => clk,
                s_axis_a_tvalid          => addsub_fifo_rd_valid(i),
                s_axis_a_tdata           => addsub_fifo_rd_data(i*65+31 downto i*65),
                s_axis_a_tuser           => addsub_fifo_rd_tid((i+1)*16-1 downto i*16),
                s_axis_b_tvalid          => addsub_fifo_rd_valid(i),
                s_axis_b_tdata           => addsub_fifo_rd_data(i*65+63 downto i*65+32),
                s_axis_operation_tvalid  => addsub_fifo_rd_valid(i),
                s_axis_operation_tdata   => "0000000" & addsub_fifo_rd_data(i*65+64),  -- 0=add, 1=sub
                m_axis_result_tvalid     => addsub_result_valid(i),
                m_axis_result_tdata      => addsub_result_data((i+1)*32-1 downto i*32),
                m_axis_result_tuser      => addsub_result_tid((i+1)*16-1 downto i*16)
            );
        
        addsub_fifo_rd_ready(i) <= '1';
    end generate;

    -- Combine all FP unit results into arrays for routing
    all_results_data  <= mult_result_data & fma_result_data & addsub_result_data;
    all_results_tid   <= mult_result_tid & fma_result_tid & addsub_result_tid;
    all_results_valid <= mult_result_valid & fma_result_valid & addsub_result_valid;
    
    -- All FP units always ready in NonBlocking mode (no backpressure)
    all_results_ready <= (others => '1');
    
    -- Output FIFOs (one per producer)
    gen_output : for prod in 0 to NUM_PRODUCERS-1 generate
        signal prod_wr_data  : std_logic_vector(31 downto 0);
        signal prod_wr_tid   : std_logic_vector(15 downto 0);
        signal prod_wr_valid : std_logic;
        signal prod_wr_ready : std_logic;
    begin
        -- Merge results from all FP units targeting this producer
        -- Producer ID is encoded in TID[15:13]
        -- Combinational routing process
        process(all_results_valid, all_results_data, all_results_tid, prod_wr_ready)
            variable producer_id : integer;
        begin
            prod_wr_valid <= '0';
            prod_wr_data  <= (others => '0');
            prod_wr_tid   <= (others => '0');
            
            -- Check all FP units for results targeting this producer
            for i in 0 to TOTAL_FP_UNITS-1 loop
                if all_results_valid(i) = '1' then
                    -- Extract producer ID from TID upper 3 bits
                    producer_id := to_integer(unsigned(all_results_tid((i+1)*16-1 downto i*16+13)));
                    
                    if producer_id = prod then
                        -- This result is for us
                        prod_wr_data  <= all_results_data((i+1)*32-1 downto i*32);
                        prod_wr_tid   <= all_results_tid((i+1)*16-1 downto i*16);
                        prod_wr_valid <= '1';
                        exit;  -- Only take one result per cycle
                    end if;
                end if;
            end loop;
        end process;
        
        -- Output FIFO for this producer
        out_fifo : sync_fifo
            generic map (
                DATA_WIDTH => 32,
                TID_WIDTH  => 16,
                DEPTH      => FIFO_DEPTH
            )
            port map (
                clk      => clk,
                reset    => reset,
                wr_data  => prod_wr_data,
                wr_tid   => prod_wr_tid,
                wr_valid => prod_wr_valid,
                wr_ready => prod_wr_ready,
                rd_data  => output_rd_data((prod+1)*32-1 downto prod*32),
                rd_tid   => output_rd_tid((prod+1)*16-1 downto prod*16),
                rd_valid => output_rd_valid(prod),
                rd_ready => output_rd_ready(prod),
                full     => open,
                empty    => open,
                almost_full => open
            );
    end generate;

end Behavioral;
