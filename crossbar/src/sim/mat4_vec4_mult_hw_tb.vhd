LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.lin_alg_pkg.ALL;

-- Testbench for mat4_vec4_mult_hw (Matrix-Vector multiplication using DOT4 units)
-- Tests several known matrix-vector multiplications to verify correctness

ENTITY mat4_vec4_mult_hw_tb IS
END ENTITY mat4_vec4_mult_hw_tb;

ARCHITECTURE behavioral OF mat4_vec4_mult_hw_tb IS

    -- Clock and reset
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    
    -- DUT signals
    SIGNAL m_in : Mat4;
    SIGNAL v_in : Vec4;
    SIGNAL tid_in : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL valid_in : STD_LOGIC := '0';
    
    SIGNAL v_out : Vec4;
    SIGNAL tid_out : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL valid_out : STD_LOGIC;
    
    -- Testbench control
    SIGNAL sim_done : BOOLEAN := FALSE;
    SIGNAL test_num : INTEGER := 0;
    SIGNAL pass_count : INTEGER := 0;
    
    -- FP constants
    CONSTANT FP_ZERO  : fp32 := X"00000000"; -- 0.0
    CONSTANT FP_ONE   : fp32 := X"3F800000"; -- 1.0
    CONSTANT FP_TWO   : fp32 := X"40000000"; -- 2.0
    CONSTANT FP_THREE : fp32 := X"40400000"; -- 3.0
    CONSTANT FP_FOUR  : fp32 := X"40800000"; -- 4.0
    CONSTANT FP_FIVE  : fp32 := X"40A00000"; -- 5.0
    CONSTANT FP_SIX   : fp32 := X"40C00000"; -- 6.0
    CONSTANT FP_TEN   : fp32 := X"41200000"; -- 10.0
    CONSTANT FP_THIRTY: fp32 := X"41F00000"; -- 30.0

BEGIN

    -- Clock generation
    clk <= NOT clk AFTER CLK_PERIOD / 2 WHEN NOT sim_done ELSE '0';
    
    -- DUT instantiation
    dut : ENTITY work.mat4_vec4_mult_hw
        PORT MAP (
            clk       => clk,
            reset     => reset,
            m_in      => m_in,
            v_in      => v_in,
            tid_in    => tid_in,
            valid_in  => valid_in,
            v_out     => v_out,
            tid_out   => tid_out,
            valid_out => valid_out
        );
    
    -- Test stimulus process
    stimulus_proc : PROCESS
        VARIABLE expected_x, expected_y, expected_z, expected_w : fp32;
        VARIABLE result_match : BOOLEAN;
    BEGIN
        -- Hold reset
        REPORT "Starting mat4_vec4_mult_hw testbench...";
        reset <= '1';
        valid_in <= '0';
        WAIT FOR CLK_PERIOD * 10;
        WAIT UNTIL rising_edge(clk);
        reset <= '0';
        WAIT FOR CLK_PERIOD * 5;
        
        REPORT "=== MAT4_VEC4_MULT TEST SUITE ===";
        
        -- TEST 1: Identity matrix * (1,2,3,4) = (1,2,3,4)
        REPORT "Test 1: Identity matrix multiplication";
        test_num <= 1;
        m_in <= MAT4_IDENTITY;
        v_in.x <= FP_ONE;
        v_in.y <= FP_TWO;
        v_in.z <= FP_THREE;
        v_in.w <= FP_FOUR;
        tid_in <= X"0001";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        -- Wait for result
        WAIT UNTIL valid_out = '1';
        expected_x := FP_ONE;
        expected_y := FP_TWO;
        expected_z := FP_THREE;
        expected_w := FP_FOUR;
        
        result_match := (v_out.x = expected_x) AND (v_out.y = expected_y) AND 
                       (v_out.z = expected_z) AND (v_out.w = expected_w);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 1 PASS";
        ELSE
            REPORT "Test 1 FAIL - Expected (" & to_hstring(expected_x) & "," & 
                   to_hstring(expected_y) & "," & to_hstring(expected_z) & "," & 
                   to_hstring(expected_w) & "), Got (" & to_hstring(v_out.x) & "," & 
                   to_hstring(v_out.y) & "," & to_hstring(v_out.z) & "," & 
                   to_hstring(v_out.w) & ")" SEVERITY ERROR;
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- TEST 2: All-ones matrix * (1,1,1,1) = (4,4,4,4)
        REPORT "Test 2: All-ones matrix";
        test_num <= 2;
        m_in.x1 <= FP_ONE; m_in.x2 <= FP_ONE; m_in.x3 <= FP_ONE; m_in.x4 <= FP_ONE;
        m_in.y1 <= FP_ONE; m_in.y2 <= FP_ONE; m_in.y3 <= FP_ONE; m_in.y4 <= FP_ONE;
        m_in.z1 <= FP_ONE; m_in.z2 <= FP_ONE; m_in.z3 <= FP_ONE; m_in.z4 <= FP_ONE;
        m_in.w1 <= FP_ONE; m_in.w2 <= FP_ONE; m_in.w3 <= FP_ONE; m_in.w4 <= FP_ONE;
        v_in.x <= FP_ONE;
        v_in.y <= FP_ONE;
        v_in.z <= FP_ONE;
        v_in.w <= FP_ONE;
        tid_in <= X"0002";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        WAIT UNTIL valid_out = '1';
        expected_x := FP_FOUR;
        expected_y := FP_FOUR;
        expected_z := FP_FOUR;
        expected_w := FP_FOUR;
        
        result_match := (v_out.x = expected_x) AND (v_out.y = expected_y) AND 
                       (v_out.z = expected_z) AND (v_out.w = expected_w);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 2 PASS";
        ELSE
            REPORT "Test 2 FAIL" SEVERITY ERROR;
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- TEST 3: Zero vector result
        REPORT "Test 3: Zero vector multiplication";
        test_num <= 3;
        m_in <= MAT4_IDENTITY;
        v_in.x <= FP_ZERO;
        v_in.y <= FP_ZERO;
        v_in.z <= FP_ZERO;
        v_in.w <= FP_ZERO;
        tid_in <= X"0003";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        WAIT UNTIL valid_out = '1';
        expected_x := FP_ZERO;
        expected_y := FP_ZERO;
        expected_z := FP_ZERO;
        expected_w := FP_ZERO;
        
        result_match := (v_out.x = expected_x) AND (v_out.y = expected_y) AND 
                       (v_out.z = expected_z) AND (v_out.w = expected_w);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 3 PASS";
        ELSE
            REPORT "Test 3 FAIL" SEVERITY ERROR;
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- TEST 4: First column only
        REPORT "Test 4: First column extraction";
        test_num <= 4;
        m_in.x1 <= FP_TWO; m_in.x2 <= FP_ZERO; m_in.x3 <= FP_ZERO; m_in.x4 <= FP_ZERO;
        m_in.y1 <= FP_THREE; m_in.y2 <= FP_ZERO; m_in.y3 <= FP_ZERO; m_in.y4 <= FP_ZERO;
        m_in.z1 <= FP_FOUR; m_in.z2 <= FP_ZERO; m_in.z3 <= FP_ZERO; m_in.z4 <= FP_ZERO;
        m_in.w1 <= FP_FIVE; m_in.w2 <= FP_ZERO; m_in.w3 <= FP_ZERO; m_in.w4 <= FP_ZERO;
        v_in.x <= FP_ONE;
        v_in.y <= FP_ZERO;
        v_in.z <= FP_ZERO;
        v_in.w <= FP_ZERO;
        tid_in <= X"0004";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        WAIT UNTIL valid_out = '1';
        expected_x := FP_TWO;
        expected_y := FP_THREE;
        expected_z := FP_FOUR;
        expected_w := FP_FIVE;
        
        result_match := (v_out.x = expected_x) AND (v_out.y = expected_y) AND 
                       (v_out.z = expected_z) AND (v_out.w = expected_w);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 4 PASS";
        ELSE
            REPORT "Test 4 FAIL" SEVERITY ERROR;
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- Summary
        REPORT "=================================";
        REPORT "Tests passed: " & INTEGER'image(pass_count) & " / 4";
        IF pass_count = 4 THEN
            REPORT ">>> ALL MAT4_VEC4_MULT TESTS PASSED <<<";
        ELSE
            REPORT ">>> SOME TESTS FAILED <<<" SEVERITY ERROR;
        END IF;
        REPORT "=================================";
        
        WAIT FOR CLK_PERIOD * 10;
        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
