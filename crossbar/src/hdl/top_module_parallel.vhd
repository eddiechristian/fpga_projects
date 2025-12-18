LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

-- Parallel throughput test module for crossbar dot product system
-- Tests all 10 dot product units in parallel by calculating 100 dot products
-- (10 operations per batch, 10 batches total)
-- Hardcoded test vectors measure peak parallel throughput

ENTITY top_module_parallel IS
    PORT (
        clk        : IN STD_LOGIC;
        rst        : IN STD_LOGIC;
        test_done  : OUT STD_LOGIC  -- LED indicator when test completes
    );
END ENTITY top_module_parallel;

ARCHITECTURE structural OF top_module_parallel IS

    -- Test configuration
    CONSTANT NUM_TESTS : INTEGER := 100;
    
    -- Crossbar signals (must match package size NUM_PRODUCERS=10)
    SIGNAL dot_requests    : producer_dot_request_array_t;
    SIGNAL mult_requests   : producer_mult_request_array_t;
    SIGNAL fma_requests    : producer_fma_request_array_t;
    SIGNAL addsub_requests : producer_addsub_request_array_t;
    SIGNAL prod_grants     : producer_grant_array_t;
    SIGNAL prod_results    : producer_result_array_t;

    -- Crossbar status
    SIGNAL locked          : STD_LOGIC;

    -- Test state machine
    TYPE state_t IS (IDLE, WAIT_RESET, ISSUE_REQUESTS, WAIT_FOR_GRANTS, WAIT_RESULTS, TEST_COMPLETE);
    SIGNAL state           : state_t;
    SIGNAL batch_counter   : INTEGER RANGE 0 TO NUM_TESTS / NUM_PRODUCERS;
    SIGNAL cycle_counter   : UNSIGNED(31 DOWNTO 0);
    SIGNAL start_cycle     : UNSIGNED(31 DOWNTO 0);
    SIGNAL end_cycle       : UNSIGNED(31 DOWNTO 0);
    SIGNAL total_cycles    : UNSIGNED(31 DOWNTO 0);
    
    -- Track grants and results for all 10 producers
    SIGNAL grants_received : STD_LOGIC_VECTOR(NUM_PRODUCERS - 1 DOWNTO 0);
    SIGNAL results_received : STD_LOGIC_VECTOR(NUM_PRODUCERS - 1 DOWNTO 0);
    
    -- Test vectors (simple pattern for verification)
    -- Using floating point value 1.0 = 0x3F800000
    -- Vector A = (1, 2, 3) scaled
    -- Vector B = (1, 1, 1)
    CONSTANT FP_ONE   : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"3F800000"; -- 1.0
    CONSTANT FP_TWO   : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"40000000"; -- 2.0
    CONSTANT FP_THREE : STD_LOGIC_VECTOR(31 DOWNTO 0) := X"40400000"; -- 3.0
    
    SIGNAL a_vec : Vec3;
    SIGNAL b_vec : Vec3;

BEGIN

    -- Initialize test vectors
    a_vec.x <= FP_ONE;
    a_vec.y <= FP_TWO;
    a_vec.z <= FP_THREE;
    b_vec.x <= FP_ONE;
    b_vec.y <= FP_ONE;
    b_vec.z <= FP_ONE;

    -- Initialize unused operation types (only using dot product)
    gen_unused_mult : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        mult_requests(i) <= init_producer_mult_request;
    END GENERATE;

    gen_unused_fma : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        fma_requests(i) <= init_producer_fma_request;
    END GENERATE;

    gen_unused_addsub : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        addsub_requests(i) <= init_producer_addsub_request;
    END GENERATE;

    -- Test state machine: issues requests to all 10 producers in parallel
    PROCESS (clk)
        VARIABLE all_grants_received : BOOLEAN;
        VARIABLE all_results_received : BOOLEAN;
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state <= WAIT_RESET;
                batch_counter <= 0;
                cycle_counter <= (OTHERS => '0');
                start_cycle <= (OTHERS => '0');
                end_cycle <= (OTHERS => '0');
                total_cycles <= (OTHERS => '0');
                grants_received <= (OTHERS => '0');
                results_received <= (OTHERS => '0');
                FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                    dot_requests(i).valid <= '0';
                    dot_requests(i).unit_index <= i;  -- Each producer uses its corresponding unit
                    dot_requests(i).tid <= (OTHERS => '0');
                END LOOP;
            ELSE
                -- Cycle counter always increments
                cycle_counter <= cycle_counter + 1;
                
                CASE state IS
                    WHEN WAIT_RESET =>
                        -- Wait a few cycles after reset
                        IF cycle_counter > 10 THEN
                            state <= ISSUE_REQUESTS;
                            batch_counter <= 0;
                            start_cycle <= cycle_counter;
                            REPORT "=== STARTING PARALLEL THROUGHPUT TEST: " & INTEGER'image(NUM_TESTS) & 
                                   " DOT PRODUCTS (" & INTEGER'image(NUM_PRODUCERS) & " parallel) ===";
                        END IF;
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            dot_requests(i).valid <= '0';
                        END LOOP;
                    
                    WHEN ISSUE_REQUESTS =>
                        -- Issue requests to all 10 producers in parallel
                        grants_received <= (OTHERS => '0');
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            dot_requests(i).valid <= '1';
                            dot_requests(i).unit_index <= i;  -- Each uses dedicated unit
                            dot_requests(i).a <= a_vec;
                            dot_requests(i).b <= b_vec;
                            dot_requests(i).tid <= make_tid(i, batch_counter * NUM_PRODUCERS + i);
                        END LOOP;
                        state <= WAIT_FOR_GRANTS;
                        REPORT "Batch " & INTEGER'image(batch_counter) & ": Issuing 10 DOT requests at cycle " & 
                               INTEGER'image(to_integer(cycle_counter));
                    
                    WHEN WAIT_FOR_GRANTS =>
                        -- Track which producers received grants
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            IF prod_grants(i).granted = '1' THEN
                                grants_received(i) <= '1';
                                dot_requests(i).valid <= '0';  -- Clear request once granted
                            ELSE
                                -- Keep request valid until granted
                                IF grants_received(i) = '0' THEN
                                    dot_requests(i).valid <= '1';
                                ELSE
                                    dot_requests(i).valid <= '0';
                                END IF;
                            END IF;
                        END LOOP;
                        
                        -- Check if all grants received
                        all_grants_received := TRUE;
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            IF grants_received(i) = '0' THEN
                                all_grants_received := FALSE;
                            END IF;
                        END LOOP;
                        
                        IF all_grants_received THEN
                            REPORT "Batch " & INTEGER'image(batch_counter) & ": All grants received at cycle " & 
                                   INTEGER'image(to_integer(cycle_counter));
                            results_received <= (OTHERS => '0');
                            state <= WAIT_RESULTS;
                        END IF;
                    
                    WHEN WAIT_RESULTS =>
                        -- Ensure all requests are cleared
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            dot_requests(i).valid <= '0';
                        END LOOP;
                        
                        -- Track which producers returned results
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            IF prod_results(i).valid = '1' THEN
                                results_received(i) <= '1';
                            END IF;
                        END LOOP;
                        
                        -- Check if all results received
                        all_results_received := TRUE;
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            IF results_received(i) = '0' THEN
                                all_results_received := FALSE;
                            END IF;
                        END LOOP;
                        
                        IF all_results_received THEN
                            REPORT "Batch " & INTEGER'image(batch_counter) & ": All results received at cycle " & 
                                   INTEGER'image(to_integer(cycle_counter));
                            
                            -- Move to next batch
                            batch_counter <= batch_counter + 1;
                            
                            IF batch_counter >= (NUM_TESTS / NUM_PRODUCERS) - 1 THEN
                                state <= TEST_COMPLETE;
                                end_cycle <= cycle_counter;
                                total_cycles <= cycle_counter - start_cycle;
                            ELSE
                                state <= ISSUE_REQUESTS;
                            END IF;
                        END IF;
                    
                    WHEN TEST_COMPLETE =>
                        REPORT "=== TEST COMPLETE ===";
                        REPORT "Total operations: " & INTEGER'image(NUM_TESTS);
                        REPORT "Total cycles: " & INTEGER'image(to_integer(total_cycles));
                        REPORT "Cycles per operation: " & INTEGER'image(to_integer(total_cycles) / NUM_TESTS);
                        REPORT "Throughput: " & INTEGER'image(NUM_TESTS * 100 / to_integer(total_cycles)) & 
                               "." & INTEGER'image((NUM_TESTS * 1000 / to_integer(total_cycles)) MOD 10) & 
                               " ops per 100 cycles";
                        REPORT "Parallel speedup vs sequential: " & INTEGER'image(900 / to_integer(total_cycles)) & 
                               "." & INTEGER'image((9000 / to_integer(total_cycles)) MOD 10) & "x";
                        state <= IDLE;
                    
                    WHEN OTHERS => -- IDLE
                        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                            dot_requests(i).valid <= '0';
                        END LOOP;
                        -- Stay idle
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -- Instantiate the crossbar FP system
    crossbar_inst : ENTITY work.crossbar_fp_system
        PORT MAP(
            clk_100mhz      => clk,
            rst             => rst,
            locked          => locked,
            dot_requests    => dot_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            prod_results    => prod_results
        );
    
    -- Output assignment: indicate test complete
    test_done <= '1' WHEN state = TEST_COMPLETE OR state = IDLE ELSE '0';

END ARCHITECTURE structural;
