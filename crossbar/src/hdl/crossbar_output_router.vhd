library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;

entity crossbar_output_router is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        
        -- FP unit outputs
        mult_outputs    : in fp_mult_output_array_t;
        fma_outputs     : in fp_fma_output_array_t;
        addsub_outputs  : in fp_addsub_output_array_t;
        
        -- Producer results
        prod_results    : out producer_result_array_t
    );
end crossbar_output_router;

architecture Behavioral of crossbar_output_router is

    -- Simple FIFO for producer outputs
    component simple_fifo is
        generic (
            DATA_WIDTH : integer := 48;  -- 32 bits data + 16 bits TID
            DEPTH      : integer := OUTPUT_FIFO_DEPTH
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
    end component;
    
    -- Aggregated results from all FP units
    constant TOTAL_FP_UNITS_CONST : integer := TOTAL_FP_UNITS;
    type aggregated_results_t is array (0 to TOTAL_FP_UNITS_CONST-1) of fp_unit_output_t;
    signal all_fp_outputs : aggregated_results_t;
    
    -- FIFO interface signals per producer
    type fifo_data_array_t is array (0 to NUM_PRODUCERS-1) of std_logic_vector(47 downto 0);  -- 32 data + 16 TID
    signal fifo_wr_en   : std_logic_vector(0 to NUM_PRODUCERS-1);
    signal fifo_wr_data : fifo_data_array_t;
    signal fifo_rd_en   : std_logic_vector(0 to NUM_PRODUCERS-1);
    signal fifo_rd_data : fifo_data_array_t;
    signal fifo_empty   : std_logic_vector(0 to NUM_PRODUCERS-1);
    signal fifo_full    : std_logic_vector(0 to NUM_PRODUCERS-1);
    
    -- Routing signals
    type producer_id_array_t is array (0 to TOTAL_FP_UNITS_CONST-1) of integer range 0 to NUM_PRODUCERS-1;
    signal decoded_producer_ids : producer_id_array_t;

begin

    -- Aggregate all FP unit outputs into single array for easier processing
    process(mult_outputs, fma_outputs, addsub_outputs)
        variable idx : integer;
    begin
        idx := 0;  -- Reset at start of each evaluation
        
        -- Collect MULT outputs
        for i in 0 to NUM_MULT_UNITS-1 loop
            all_fp_outputs(idx) <= mult_outputs(i);
            idx := idx + 1;
        end loop;
        
        -- Collect FMA outputs
        for i in 0 to NUM_FMA_UNITS-1 loop
            all_fp_outputs(idx) <= fma_outputs(i);
            idx := idx + 1;
        end loop;
        
        -- Collect ADDSUB outputs
        for i in 0 to NUM_ADDSUB_UNITS-1 loop
            all_fp_outputs(idx) <= addsub_outputs(i);
            idx := idx + 1;
        end loop;
    end process;
    
    -- Decode producer IDs from TIDs
    process(all_fp_outputs)
    begin
        for i in 0 to TOTAL_FP_UNITS_CONST-1 loop
            decoded_producer_ids(i) <= get_producer_id(all_fp_outputs(i).tid);
        end loop;
    end process;
    
    -- Route FP outputs to appropriate producer FIFOs
    -- Priority encoder: if multiple FP units output to same producer, lower index wins
    process(all_fp_outputs, decoded_producer_ids, fifo_full)
        variable prod_id : integer range 0 to NUM_PRODUCERS-1;
    begin
        -- Default: no writes
        fifo_wr_en <= (others => '0');
        fifo_wr_data <= (others => (others => '0'));
        
        -- For each FP unit, try to write to its target producer FIFO
        for fp_idx in 0 to TOTAL_FP_UNITS_CONST-1 loop
            if all_fp_outputs(fp_idx).valid = '1' then
                prod_id := decoded_producer_ids(fp_idx);
                
                -- Only write if FIFO not full and no earlier FP unit has claimed this producer
                if fifo_full(prod_id) = '0' and fifo_wr_en(prod_id) = '0' then
                    fifo_wr_en(prod_id) <= '1';
                    fifo_wr_data(prod_id)(31 downto 0) <= all_fp_outputs(fp_idx).data;
                    fifo_wr_data(prod_id)(47 downto 32) <= all_fp_outputs(fp_idx).tid;
                end if;
            end if;
        end loop;
    end process;
    
    -- Generate output FIFOs for each producer
    gen_producer_fifos: for i in 0 to NUM_PRODUCERS-1 generate
        fifo_inst : simple_fifo
            generic map (
                DATA_WIDTH => 48,
                DEPTH => OUTPUT_FIFO_DEPTH
            )
            port map (
                clk     => clk,
                rst     => rst,
                wr_en   => fifo_wr_en(i),
                wr_data => fifo_wr_data(i),
                rd_en   => fifo_rd_en(i),
                rd_data => fifo_rd_data(i),
                empty   => fifo_empty(i),
                full    => fifo_full(i)
            );
    end generate;
    
    -- Producer output interface
    process(fifo_empty, fifo_rd_data)
    begin
        for i in 0 to NUM_PRODUCERS-1 loop
            -- Valid when FIFO has data
            prod_results(i).valid <= not fifo_empty(i);
            
            -- Extract data and TID from FIFO output
            prod_results(i).data <= fifo_rd_data(i)(31 downto 0);
            prod_results(i).tid <= fifo_rd_data(i)(47 downto 32);
            
            -- Always ready (for now - producers can control this)
            prod_results(i).ready <= '1';
        end loop;
    end process;
    
    -- FIFO read enable: read when valid and producer ready
    process(prod_results)
    begin
        for i in 0 to NUM_PRODUCERS-1 loop
            fifo_rd_en(i) <= prod_results(i).valid and prod_results(i).ready;
        end loop;
    end process;

end Behavioral;
