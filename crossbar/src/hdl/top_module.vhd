LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

-- Throughput test module for crossbar dot product system
-- Tests a single dot product unit by calculating 100 sequential dot products
-- Hardcoded test vectors measure peak throughput when operations must wait

ENTITY top_module IS
    PORT (
        clk        : IN STD_LOGIC;
        rst        : IN STD_LOGIC;
        test_done  : OUT STD_LOGIC  -- LED indicator when test completes
    );
END ENTITY top_module;

ARCHITECTURE structural OF top_module IS

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
    TYPE state_t IS (IDLE, WAIT_RESET, ISSUE_REQUEST, WAIT_FOR_GRANT, WAIT_RESULT, TEST_COMPLETE);
    SIGNAL state           : state_t;
    SIGNAL test_counter    : INTEGER RANGE 0 TO NUM_TESTS;
    SIGNAL cycle_counter   : UNSIGNED(31 DOWNTO 0);
    SIGNAL start_cycle     : UNSIGNED(31 DOWNTO 0);
    SIGNAL end_cycle       : UNSIGNED(31 DOWNTO 0);
    SIGNAL total_cycles    : UNSIGNED(31 DOWNTO 0);
    
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

    -- Initialize unused producer slots (producers 1-9)
    gen_unused_dot : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        dot_requests(i) <= init_producer_dot_request;
    END GENERATE;

    gen_unused_mult : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        mult_requests(i) <= init_producer_mult_request;
    END GENERATE;

    gen_unused_fma : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        fma_requests(i) <= init_producer_fma_request;
    END GENERATE;

    gen_unused_addsub : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        addsub_requests(i) <= init_producer_addsub_request;
    END GENERATE;

    -- Test state machine and dot product producer (producer 0)
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state <= WAIT_RESET;
                test_counter <= 0;
                cycle_counter <= (OTHERS => '0');
                start_cycle <= (OTHERS => '0');
                end_cycle <= (OTHERS => '0');
                total_cycles <= (OTHERS => '0');
                dot_requests(0).valid <= '0';
                dot_requests(0).unit_index <= 0;
                dot_requests(0).tid <= (OTHERS => '0');
            ELSE
                -- Cycle counter always increments
                cycle_counter <= cycle_counter + 1;
                
                CASE state IS
                    WHEN WAIT_RESET =>
                        -- Wait a few cycles after reset
                        IF cycle_counter > 10 THEN
                            state <= ISSUE_REQUEST;
                            test_counter <= 0;
                            start_cycle <= cycle_counter;
                            REPORT "=== STARTING THROUGHPUT TEST: " & INTEGER'image(NUM_TESTS) & " DOT PRODUCTS ===";
                        END IF;
                        dot_requests(0).valid <= '0';
                    
                    WHEN ISSUE_REQUEST =>
                        -- Issue dot product request
                        dot_requests(0).valid <= '1';
                        dot_requests(0).unit_index <= 0;  -- Always use DOT unit 0
                        dot_requests(0).a <= a_vec;
                        dot_requests(0).b <= b_vec;
                        dot_requests(0).tid <= STD_LOGIC_VECTOR(to_unsigned(test_counter, 16));
                        state <= WAIT_FOR_GRANT;
                        REPORT "Test " & INTEGER'image(test_counter) & ": Issuing DOT request at cycle " & 
                               INTEGER'image(to_integer(cycle_counter));
                    
                    WHEN WAIT_FOR_GRANT =>
                        -- Keep request valid until granted
                        dot_requests(0).valid <= '1';
                        
                        -- Wait for grant from arbiter
                        IF prod_grants(0).granted = '1' THEN
                            REPORT "Test " & INTEGER'image(test_counter) & ": Grant received at cycle " & 
                                   INTEGER'image(to_integer(cycle_counter));
                            -- Clear request and wait for result
                            dot_requests(0).valid <= '0';
                            state <= WAIT_RESULT;
                        END IF;
                    
                    WHEN WAIT_RESULT =>
                        -- Request already cleared in previous state
                        dot_requests(0).valid <= '0';
                        
                        -- Wait for result
                        IF prod_results(0).valid = '1' THEN
                            REPORT "Test " & INTEGER'image(test_counter) & ": Result received at cycle " & 
                                   INTEGER'image(to_integer(cycle_counter)) & 
                                   " TID=" & INTEGER'image(to_integer(unsigned(prod_results(0).tid)));
                            
                            -- Move to next test
                            test_counter <= test_counter + 1;
                            
                            IF test_counter >= NUM_TESTS - 1 THEN
                                state <= TEST_COMPLETE;
                                end_cycle <= cycle_counter;
                                total_cycles <= cycle_counter - start_cycle;
                            ELSE
                                state <= ISSUE_REQUEST;
                            END IF;
                        END IF;
                    
                    WHEN TEST_COMPLETE =>
                        REPORT "=== TEST COMPLETE ===";
                        REPORT "Total tests: " & INTEGER'image(NUM_TESTS);
                        REPORT "Total cycles: " & INTEGER'image(to_integer(total_cycles));
                        REPORT "Cycles per operation: " & INTEGER'image(to_integer(total_cycles) / NUM_TESTS);
                        REPORT "Throughput: " & INTEGER'image(NUM_TESTS * 100 / to_integer(total_cycles)) & 
                               "." & INTEGER'image((NUM_TESTS * 1000 / to_integer(total_cycles)) MOD 10) & 
                               " ops per 100 cycles";
                        state <= IDLE;
                    
                    WHEN OTHERS => -- IDLE
                        dot_requests(0).valid <= '0';
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
