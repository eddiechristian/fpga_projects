LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;

ENTITY crossbar_output_router IS
    PORT (
        clk            : IN STD_LOGIC;
        rst            : IN STD_LOGIC;

        -- FP unit outputs
        dot_outputs   : IN fp_dot_output_array_t;
        mult_outputs   : IN fp_mult_output_array_t;
        fma_outputs    : IN fp_fma_output_array_t;
        addsub_outputs : IN fp_addsub_output_array_t;

        -- Producer results
        prod_results   : OUT producer_result_array_t
    );
END crossbar_output_router;

ARCHITECTURE Behavioral OF crossbar_output_router IS

    -- Simple FIFO for producer outputs
    COMPONENT simple_fifo IS
        GENERIC (
            DATA_WIDTH : INTEGER := 48; -- 32 bits data + 16 bits TID
            DEPTH      : INTEGER := OUTPUT_FIFO_DEPTH
        );
        PORT (
            clk     : IN STD_LOGIC;
            rst     : IN STD_LOGIC;
            wr_en   : IN STD_LOGIC;
            wr_data : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            rd_en   : IN STD_LOGIC;
            rd_data : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            empty   : OUT STD_LOGIC;
            full    : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Aggregated results from all FP units
    CONSTANT TOTAL_FP_UNITS_CONST : INTEGER := TOTAL_FP_UNITS;
    TYPE aggregated_results_t IS ARRAY (0 TO TOTAL_FP_UNITS_CONST - 1) OF fp_unit_output_t;
    SIGNAL all_fp_outputs : aggregated_results_t;

    -- FIFO interface signals per producer
    TYPE fifo_data_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF STD_LOGIC_VECTOR(47 DOWNTO 0); -- 32 data + 16 TID
    SIGNAL fifo_wr_en   : STD_LOGIC_VECTOR(0 TO NUM_PRODUCERS - 1);
    SIGNAL fifo_wr_data : fifo_data_array_t;
    SIGNAL fifo_rd_en   : STD_LOGIC_VECTOR(0 TO NUM_PRODUCERS - 1);
    SIGNAL fifo_rd_data : fifo_data_array_t;
    SIGNAL fifo_empty   : STD_LOGIC_VECTOR(0 TO NUM_PRODUCERS - 1);
    SIGNAL fifo_full    : STD_LOGIC_VECTOR(0 TO NUM_PRODUCERS - 1);

    -- Routing signals
    TYPE producer_id_array_t IS ARRAY (0 TO TOTAL_FP_UNITS_CONST - 1) OF INTEGER RANGE 0 TO NUM_PRODUCERS - 1;
    SIGNAL decoded_producer_ids : producer_id_array_t;

BEGIN

    -- Aggregate all FP unit outputs into single array for easier processing
    PROCESS (dot_outputs, mult_outputs, fma_outputs, addsub_outputs)
        VARIABLE idx : INTEGER;
    BEGIN
        idx := 0; -- Reset at start of each evaluation

        -- Collect DOT outputs
        FOR i IN 0 TO NUM_DOT_UNITS - 1 LOOP
            all_fp_outputs(idx) <= dot_outputs(i);
            idx := idx + 1;
        END LOOP;

        -- Collect MULT outputs
        FOR i IN 0 TO NUM_MULT_UNITS - 1 LOOP
            all_fp_outputs(idx) <= mult_outputs(i);
            idx := idx + 1;
        END LOOP;

        -- Collect FMA outputs
        FOR i IN 0 TO NUM_FMA_UNITS - 1 LOOP
            all_fp_outputs(idx) <= fma_outputs(i);
            idx := idx + 1;
        END LOOP;

        -- Collect ADDSUB outputs
        FOR i IN 0 TO NUM_ADDSUB_UNITS - 1 LOOP
            all_fp_outputs(idx) <= addsub_outputs(i);
            idx := idx + 1;
        END LOOP;
    END PROCESS;

    -- Decode producer IDs from TIDs
    PROCESS (all_fp_outputs)
    BEGIN
        FOR i IN 0 TO TOTAL_FP_UNITS_CONST - 1 LOOP
            decoded_producer_ids(i) <= get_producer_id(all_fp_outputs(i).tid);
        END LOOP;
    END PROCESS;

    -- Route FP outputs to appropriate producer FIFOs
    -- Priority encoder: if multiple FP units output to same producer, lower index wins
    PROCESS (all_fp_outputs, decoded_producer_ids, fifo_full)
        VARIABLE prod_id        : INTEGER RANGE 0 TO NUM_PRODUCERS - 1;
        VARIABLE fifo_wr_en_var : STD_LOGIC_VECTOR(0 TO NUM_PRODUCERS - 1);
    BEGIN
        -- Default: no writes
        fifo_wr_en_var := (OTHERS => '0');
        fifo_wr_data <= (OTHERS => (OTHERS => '0'));

        -- For each FP unit, try to write to its target producer FIFO
        FOR fp_idx IN 0 TO TOTAL_FP_UNITS_CONST - 1 LOOP
            IF all_fp_outputs(fp_idx).valid = '1' THEN
                prod_id := decoded_producer_ids(fp_idx);

                -- Only write if FIFO not full and no earlier FP unit has claimed this producer
                IF fifo_full(prod_id) = '0' AND fifo_wr_en_var(prod_id) = '0' THEN
                    fifo_wr_en_var(prod_id) := '1';
                    fifo_wr_data(prod_id)(31 DOWNTO 0)  <= all_fp_outputs(fp_idx).data;
                    fifo_wr_data(prod_id)(47 DOWNTO 32) <= all_fp_outputs(fp_idx).tid;
                END IF;
            END IF;
        END LOOP;

        -- Assign variable to signal
        fifo_wr_en <= fifo_wr_en_var;
    END PROCESS;

    -- Generate output FIFOs for each producer
    gen_producer_fifos : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        fifo_inst : simple_fifo
        GENERIC MAP(
            DATA_WIDTH => 48,
            DEPTH      => OUTPUT_FIFO_DEPTH
        )
        PORT MAP(
            clk     => clk,
            rst     => rst,
            wr_en   => fifo_wr_en(i),
            wr_data => fifo_wr_data(i),
            rd_en   => fifo_rd_en(i),
            rd_data => fifo_rd_data(i),
            empty   => fifo_empty(i),
            full    => fifo_full(i)
        );
    END GENERATE;

    -- Producer output interface
    PROCESS (fifo_empty, fifo_rd_data)
    BEGIN
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            -- Valid when FIFO has data
            prod_results(i).valid <= NOT fifo_empty(i);

            -- Extract data and TID from FIFO output
            prod_results(i).data  <= fifo_rd_data(i)(31 DOWNTO 0);
            prod_results(i).tid   <= fifo_rd_data(i)(47 DOWNTO 32);

            -- Always ready (for now - producers can control this)
            prod_results(i).ready <= '1';
        END LOOP;
    END PROCESS;

    -- FIFO read enable: read when valid and producer ready
    PROCESS (prod_results)
    BEGIN
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            fifo_rd_en(i) <= prod_results(i).valid AND prod_results(i).ready;
        END LOOP;
    END PROCESS;

    -- Debug: Monitor routing
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            FOR i IN 0 TO TOTAL_FP_UNITS_CONST - 1 LOOP
                IF all_fp_outputs(i).valid = '1' THEN
                    REPORT "OUTPUT_ROUTER: FP unit " & INTEGER'image(i) &
                    " has valid output, TID=" & INTEGER'image(to_integer(unsigned(all_fp_outputs(i).tid))) &
                    " (0x" & to_hstring(all_fp_outputs(i).tid) & ")" &
                    ", decoded Producer ID=" & INTEGER'image(decoded_producer_ids(i)) &
                    ", fifo_full=" & STD_LOGIC'image(fifo_full(decoded_producer_ids(i))) &
                    ", fifo_wr_en=" & STD_LOGIC'image(fifo_wr_en(decoded_producer_ids(i)));
                END IF;
            END LOOP;
        END IF;
    END PROCESS;

END Behavioral;