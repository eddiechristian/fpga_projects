LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

-- DOT4 test module for crossbar Vec4 dot product system
-- Tests DOT4 units by calculating several Vec4 dot products and verifying results
-- Test vectors with known results for verification

ENTITY top_module_dot4 IS
    PORT (
        clk        : IN STD_LOGIC;
        rst        : IN STD_LOGIC;
        test_done  : OUT STD_LOGIC;
        test_pass  : OUT STD_LOGIC  -- '1' if all tests passed
    );
END ENTITY top_module_dot4;

ARCHITECTURE structural OF top_module_dot4 IS

    -- Test configuration
    CONSTANT NUM_TESTS : INTEGER := 5;
    
    -- Crossbar signals (must match package size NUM_PRODUCERS=10)
    SIGNAL dot_requests    : producer_dot_request_array_t;
    SIGNAL dot4_requests   : producer_dot4_request_array_t;
    SIGNAL mult_requests   : producer_mult_request_array_t;
    SIGNAL fma_requests    : producer_fma_request_array_t;
    SIGNAL addsub_requests : producer_addsub_request_array_t;
    SIGNAL prod_grants     : producer_grant_array_t;
    SIGNAL prod_results    : producer_result_array_t;

    -- Crossbar status
    SIGNAL locked          : STD_LOGIC;

    -- Test state machine
    TYPE state_t IS (IDLE, WAIT_RESET, ISSUE_REQUEST, WAIT_FOR_GRANT, WAIT_RESULT, CHECK_RESULT, TEST_COMPLETE);
    SIGNAL state           : state_t;
    SIGNAL test_counter    : INTEGER RANGE 0 TO NUM_TESTS;
    SIGNAL cycle_counter   : UNSIGNED(31 DOWNTO 0);
    SIGNAL pass_counter    : INTEGER RANGE 0 TO NUM_TESTS;
    
    -- Test vectors
    TYPE vec4_array_t IS ARRAY (0 TO NUM_TESTS - 1) OF Vec4;
    TYPE fp32_array_t IS ARRAY (0 TO NUM_TESTS - 1) OF fp32;
    
    -- Test case definitions:
    -- Test 0: (1,0,0,0) . (1,0,0,0) = 1.0
    -- Test 1: (1,1,1,1) . (1,1,1,1) = 4.0
    -- Test 2: (2,0,0,0) . (1,0,0,0) = 2.0
    -- Test 3: (1,2,3,4) . (1,1,1,1) = 10.0
    -- Test 4: (0,0,0,0) . (1,2,3,4) = 0.0
    
    CONSTANT FP_ZERO  : fp32 := X"00000000"; -- 0.0
    CONSTANT FP_ONE   : fp32 := X"3F800000"; -- 1.0
    CONSTANT FP_TWO   : fp32 := X"40000000"; -- 2.0
    CONSTANT FP_THREE : fp32 := X"40400000"; -- 3.0
    CONSTANT FP_FOUR  : fp32 := X"40800000"; -- 4.0
    CONSTANT FP_TEN   : fp32 := X"41200000"; -- 10.0
    
    SIGNAL a_vecs : vec4_array_t := (
        0 => (x => FP_ONE,  y => FP_ZERO, z => FP_ZERO, w => FP_ZERO),  -- (1,0,0,0)
        1 => (x => FP_ONE,  y => FP_ONE,  z => FP_ONE,  w => FP_ONE),   -- (1,1,1,1)
        2 => (x => FP_TWO,  y => FP_ZERO, z => FP_ZERO, w => FP_ZERO),  -- (2,0,0,0)
        3 => (x => FP_ONE,  y => FP_TWO,  z => FP_THREE, w => FP_FOUR), -- (1,2,3,4)
        4 => (x => FP_ZERO, y => FP_ZERO, z => FP_ZERO, w => FP_ZERO)   -- (0,0,0,0)
    );
    
    SIGNAL b_vecs : vec4_array_t := (
        0 => (x => FP_ONE,  y => FP_ZERO, z => FP_ZERO, w => FP_ZERO),  -- (1,0,0,0)
        1 => (x => FP_ONE,  y => FP_ONE,  z => FP_ONE,  w => FP_ONE),   -- (1,1,1,1)
        2 => (x => FP_ONE,  y => FP_ZERO, z => FP_ZERO, w => FP_ZERO),  -- (1,0,0,0)
        3 => (x => FP_ONE,  y => FP_ONE,  z => FP_ONE,  w => FP_ONE),   -- (1,1,1,1)
        4 => (x => FP_ONE,  y => FP_TWO,  z => FP_THREE, w => FP_FOUR)  -- (1,2,3,4)
    );
    
    SIGNAL expected_results : fp32_array_t := (
        0 => FP_ONE,  -- 1.0
        1 => FP_FOUR, -- 4.0
        2 => FP_TWO,  -- 2.0
        3 => FP_TEN,  -- 10.0
        4 => FP_ZERO  -- 0.0
    );
    
    SIGNAL result_data : fp32;
    SIGNAL all_tests_passed : BOOLEAN := TRUE;

BEGIN

    -- Initialize unused producer slots and request types
    gen_unused_producers : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        dot_requests(i)    <= init_producer_dot_request;
        dot4_requests(i)   <= init_producer_dot4_request;
        mult_requests(i)   <= init_producer_mult_request;
        fma_requests(i)    <= init_producer_fma_request;
        addsub_requests(i) <= init_producer_addsub_request;
    END GENERATE;
    
    -- Producer 0 doesn't use DOT, MULT, FMA, or ADDSUB
    dot_requests(0)    <= init_producer_dot_request;
    mult_requests(0)   <= init_producer_mult_request;
    fma_requests(0)    <= init_producer_fma_request;
    addsub_requests(0) <= init_producer_addsub_request;

    -- Test state machine and DOT4 producer (producer 0)
    PROCESS (clk)
        VARIABLE result_match : BOOLEAN;
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state <= WAIT_RESET;
                test_counter <= 0;
                pass_counter <= 0;
                cycle_counter <= (OTHERS => '0');
                dot4_requests(0).valid <= '0';
                dot4_requests(0).unit_index <= 0;
                dot4_requests(0).tid <= (OTHERS => '0');
                all_tests_passed <= TRUE;
            ELSE
                -- Cycle counter always increments
                cycle_counter <= cycle_counter + 1;
                
                CASE state IS
                    WHEN WAIT_RESET =>
                        -- Wait a few cycles after reset
                        IF cycle_counter > 10 THEN
                            state <= ISSUE_REQUEST;
                            test_counter <= 0;
                            pass_counter <= 0;
                            REPORT "=== STARTING DOT4 VERIFICATION TEST: " & INTEGER'image(NUM_TESTS) & " TEST CASES ===";
                        END IF;
                        dot4_requests(0).valid <= '0';
                    
                    WHEN ISSUE_REQUEST =>
                        -- Issue DOT4 request with current test vector
                        dot4_requests(0).valid <= '1';
                        dot4_requests(0).unit_index <= 0;  -- Use DOT4 unit 0
                        dot4_requests(0).a <= a_vecs(test_counter);
                        dot4_requests(0).b <= b_vecs(test_counter);
                        dot4_requests(0).tid <= STD_LOGIC_VECTOR(to_unsigned(test_counter, 16));
                        state <= WAIT_FOR_GRANT;
                        REPORT "Test " & INTEGER'image(test_counter) & ": Issuing DOT4 request";
                    
                    WHEN WAIT_FOR_GRANT =>
                        -- Keep request valid until granted
                        dot4_requests(0).valid <= '1';
                        
                        -- Wait for grant from arbiter
                        IF prod_grants(0).granted = '1' THEN
                            REPORT "Test " & INTEGER'image(test_counter) & ": Grant received, unit_type=" & 
                                   INTEGER'image(unit_type_t'pos(prod_grants(0).unit_type));
                            -- Clear request and wait for result
                            dot4_requests(0).valid <= '0';
                            state <= WAIT_RESULT;
                        END IF;
                    
                    WHEN WAIT_RESULT =>
                        -- Request already cleared in previous state
                        dot4_requests(0).valid <= '0';
                        
                        -- Wait for result
                        IF prod_results(0).valid = '1' THEN
                            result_data <= prod_results(0).data;
                            REPORT "Test " & INTEGER'image(test_counter) & ": Result received, value=0x" & 
                                   to_hstring(prod_results(0).data);
                            state <= CHECK_RESULT;
                        END IF;
                    
                    WHEN CHECK_RESULT =>
                        -- Check if result matches expected value
                        result_match := (result_data = expected_results(test_counter));
                        
                        IF result_match THEN
                            pass_counter <= pass_counter + 1;
                            REPORT "Test " & INTEGER'image(test_counter) & ": PASS (result matches expected 0x" & 
                                   to_hstring(expected_results(test_counter)) & ")";
                        ELSE
                            all_tests_passed <= FALSE;
                            REPORT "Test " & INTEGER'image(test_counter) & ": FAIL (expected 0x" & 
                                   to_hstring(expected_results(test_counter)) & ", got 0x" & 
                                   to_hstring(result_data) & ")" severity ERROR;
                        END IF;
                        
                        -- Move to next test
                        test_counter <= test_counter + 1;
                        
                        IF test_counter >= NUM_TESTS - 1 THEN
                            state <= TEST_COMPLETE;
                        ELSE
                            state <= ISSUE_REQUEST;
                        END IF;
                    
                    WHEN TEST_COMPLETE =>
                        REPORT "=== DOT4 TEST COMPLETE ===";
                        REPORT "Tests passed: " & INTEGER'image(pass_counter) & " / " & INTEGER'image(NUM_TESTS);
                        IF all_tests_passed THEN
                            REPORT ">>> ALL TESTS PASSED <<<";
                        ELSE
                            REPORT ">>> SOME TESTS FAILED <<<" severity ERROR;
                        END IF;
                        state <= IDLE;
                    
                    WHEN OTHERS => -- IDLE
                        dot4_requests(0).valid <= '0';
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
            dot4_requests   => dot4_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            prod_results    => prod_results
        );
    
    -- Output assignments
    test_done <= '1' WHEN state = TEST_COMPLETE OR state = IDLE ELSE '0';
    test_pass <= '1' WHEN all_tests_passed ELSE '0';

END ARCHITECTURE structural;
