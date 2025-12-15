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
    signal mult_result_valid_gated : std_logic_vector(NUM_MULT_UNITS-1 downto 0);
    
    signal fma_result_data  : std_logic_vector(NUM_FMA_UNITS*32-1 downto 0);
    signal fma_result_tid   : std_logic_vector(NUM_FMA_UNITS*16-1 downto 0);
    signal fma_result_valid : std_logic_vector(NUM_FMA_UNITS-1 downto 0);
    signal fma_result_valid_gated : std_logic_vector(NUM_FMA_UNITS-1 downto 0);
    
    signal addsub_result_data  : std_logic_vector(NUM_ADD_UNITS*32-1 downto 0);
    signal addsub_result_tid   : std_logic_vector(NUM_ADD_UNITS*16-1 downto 0);
    signal addsub_result_valid : std_logic_vector(NUM_ADD_UNITS-1 downto 0);
    signal addsub_result_valid_gated : std_logic_vector(NUM_ADD_UNITS-1 downto 0);
    
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

    -- Valid tracking shift registers for MULT units (8 cycle latency)
    gen_mult_valid_track : for i in 0 to NUM_MULT_UNITS-1 generate
        signal valid_shift : std_logic_vector(7 downto 0) := (others => '0');
    begin
        process(clk)
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    valid_shift <= (others => '0');
                else
                    -- Shift in the FIFO rd_valid, shift out after 8 cycles
                    valid_shift <= valid_shift(6 downto 0) & mult_fifo_rd_valid(i);
                end if;
            end if;
        end process;
        -- Gate the result valid with the tracked input valid
        mult_result_valid_gated(i) <= mult_result_valid(i) and valid_shift(7);
    end generate;
    
    -- Valid tracking shift registers for FMA units (2 cycle latency observed)
    gen_fma_valid_track : for i in 0 to NUM_FMA_UNITS-1 generate
        signal valid_shift : std_logic_vector(1 downto 0) := (others => '0');
    begin
        process(clk)
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    valid_shift <= (others => '0');
                else
                    valid_shift <= valid_shift(0) & fma_fifo_rd_valid(i);
                    -- Debug for FMA0: track shift register progress
                    if i = 0 and (fma_fifo_rd_valid(i) = '1' or valid_shift /= "00") then
                        report "[FMA0_SHIFT] fifo_rd_valid=" & std_logic'image(fma_fifo_rd_valid(i)) &
                               " shift=" & to_hstring(valid_shift) &
                               " fma_valid=" & std_logic'image(fma_result_valid(i)) &
                               " shift(1)=" & std_logic'image(valid_shift(1)) &
                               " gated=" & std_logic'image(fma_result_valid_gated(i));
                    end if;
                end if;
            end if;
        end process;
        fma_result_valid_gated(i) <= fma_result_valid(i) and valid_shift(1);
    end generate;
    
    -- Valid tracking shift registers for AddSub units (assume 8 cycle latency)
    gen_addsub_valid_track : for i in 0 to NUM_ADD_UNITS-1 generate
        signal valid_shift : std_logic_vector(7 downto 0) := (others => '0');
    begin
        process(clk)
        begin
            if rising_edge(clk) then
                if reset = '1' then
                    valid_shift <= (others => '0');
                else
                    valid_shift <= valid_shift(6 downto 0) & addsub_fifo_rd_valid(i);
                end if;
            end if;
        end process;
        addsub_result_valid_gated(i) <= addsub_result_valid(i) and valid_shift(7);
    end generate;

    -- Multiplier units with input FIFOs
    gen_mult : for i in 0 to NUM_MULT_UNITS-1 generate
        signal mult_fifo_wr_accepted : std_logic;
        signal mult_fifo_rd_accepted : std_logic;
    begin
        mult_fifo_wr_accepted <= mult_wr_valid(i) and mult_wr_ready(i);
        mult_fifo_rd_accepted <= mult_fifo_rd_valid(i) and mult_fifo_rd_ready(i);
        
        -- Debug for MULT unit 0
        process(clk)
        begin
            if rising_edge(clk) then
                if i = 0 then
                    if mult_fifo_wr_accepted = '1' then
                        report "[MULT0_FIFO] Write TID=" & 
                               integer'image(to_integer(unsigned(mult_wr_tid(15 downto 0))));
                    end if;
                    if mult_fifo_rd_accepted = '1' then
                        report "[MULT0_FIFO] Read TID=" & 
                               integer'image(to_integer(unsigned(mult_fifo_rd_tid(15 downto 0)))) &
                               " a=0x" & to_hstring(mult_fifo_rd_data(31 downto 0)) &
                               " b=0x" & to_hstring(mult_fifo_rd_data(63 downto 32));
                    end if;
                    if mult_result_valid(0) = '1' then
                        report "[MULT0_FP] Result TID=" & 
                               integer'image(to_integer(unsigned(mult_result_tid(15 downto 0)))) &
                               " result=0x" & to_hstring(mult_result_data(31 downto 0)) &
                               " gated=" & std_logic'image(mult_result_valid_gated(0));
                    end if;
                end if;
            end if;
        end process;
        
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
        signal fma_fifo_wr_accepted : std_logic;
        signal fma_fifo_rd_accepted : std_logic;
    begin
        fma_fifo_wr_accepted <= fma_wr_valid(i) and fma_wr_ready(i);
        fma_fifo_rd_accepted <= fma_fifo_rd_valid(i) and fma_fifo_rd_ready(i);
        
        -- Debug for FMA unit 0
        process(clk)
        begin
            if rising_edge(clk) then
                if i = 0 then
                    if fma_fifo_wr_accepted = '1' then
                        report "[FMA0_FIFO] Write TID=" & 
                               integer'image(to_integer(unsigned(fma_wr_tid(15 downto 0))));
                    end if;
                    if fma_fifo_rd_accepted = '1' then
                        report "[FMA0_FIFO] Read TID=" & 
                               integer'image(to_integer(unsigned(fma_fifo_rd_tid(15 downto 0)))) &
                               " a=0x" & to_hstring(fma_fifo_rd_data(31 downto 0)) &
                               " b=0x" & to_hstring(fma_fifo_rd_data(63 downto 32)) &
                               " c=0x" & to_hstring(fma_fifo_rd_data(95 downto 64));
                    end if;
                    if fma_result_valid(0) = '1' then
                        report "[FMA0_FP] Result TID=" & 
                               integer'image(to_integer(unsigned(fma_result_tid(15 downto 0)))) &
                               " result=0x" & to_hstring(fma_result_data(31 downto 0)) &
                               " gated=" & std_logic'image(fma_result_valid_gated(0));
                    end if;
                end if;
            end if;
        end process;
        
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
    -- Use gated valid signals to filter out garbage outputs
    all_results_data  <= mult_result_data & fma_result_data & addsub_result_data;
    all_results_tid   <= mult_result_tid & fma_result_tid & addsub_result_tid;
    all_results_valid <= mult_result_valid_gated & fma_result_valid_gated & addsub_result_valid_gated;
    
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
            variable tid_val : std_logic_vector(15 downto 0);
            variable matched : boolean;
        begin
            prod_wr_valid <= '0';
            prod_wr_data  <= (others => '0');
            prod_wr_tid   <= (others => '0');
            matched := false;
            
            -- Check all FP units for results targeting this producer
            for i in 0 to TOTAL_FP_UNITS-1 loop
                if all_results_valid(i) = '1' then
                    -- Extract full TID and producer ID from TID upper 3 bits
                    tid_val := all_results_tid((i+1)*16-1 downto i*16);
                    producer_id := to_integer(unsigned(tid_val(15 downto 13)));
                    
                    -- Debug: show first few results from any FP unit (for producer 0 only)
                    if prod = 0 and not matched then
                        report "[Debug] FP unit " & integer'image(i) & 
                               " valid, TID=" & integer'image(to_integer(unsigned(tid_val))) &
                               " ProducerID=" & integer'image(producer_id);
                    end if;
                    
                    if producer_id = prod then
                        -- Debug: report when producer 0/1/2 gets a result (first match only)
                        if prod < 3 and not matched then
                            report "[Routing] Producer " & integer'image(prod) & 
                                   " matched FP unit " & integer'image(i) & 
                                   " TID=" & integer'image(to_integer(unsigned(tid_val)));
                        end if;
                        
                        -- This result is for us
                        prod_wr_data  <= all_results_data((i+1)*32-1 downto i*32);
                        prod_wr_tid   <= tid_val;
                        prod_wr_valid <= '1';
                        matched := true;
                        
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
