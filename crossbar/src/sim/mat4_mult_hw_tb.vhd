LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.lin_alg_pkg.ALL;

-- Testbench for mat4_mult_hw (4x4 Matrix multiplication using 16 DOT4 units)
-- Tests several known matrix multiplications to verify correctness

ENTITY mat4_mult_hw_tb IS
END ENTITY mat4_mult_hw_tb;

ARCHITECTURE behavioral OF mat4_mult_hw_tb IS

    -- Clock and reset
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    
    -- DUT signals
    SIGNAL a : Mat4;
    SIGNAL b : Mat4;
    SIGNAL tid_in : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL valid_in : STD_LOGIC := '0';
    
    SIGNAL c : Mat4;
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
    CONSTANT FP_EIGHT : fp32 := X"41000000"; -- 8.0

BEGIN

    -- Clock generation
    clk <= NOT clk AFTER CLK_PERIOD / 2 WHEN NOT sim_done ELSE '0';
    
    -- DUT instantiation
    dut : ENTITY work.mat4_mult_hw
        PORT MAP (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_in,
            a         => a,
            b         => b,
            tid_in    => tid_in,
            c         => c,
            tid_out   => tid_out,
            valid_out => valid_out
        );
    
    -- Test stimulus process
    stimulus_proc : PROCESS
        VARIABLE expected_c : Mat4;
        VARIABLE result_match : BOOLEAN;
    BEGIN
        -- Hold reset
        REPORT "Starting mat4_mult_hw testbench...";
        reset <= '1';
        valid_in <= '0';
        WAIT FOR CLK_PERIOD * 10;
        WAIT UNTIL rising_edge(clk);
        reset <= '0';
        WAIT FOR CLK_PERIOD * 5;
        
        REPORT "=== MAT4_MULT TEST SUITE ===";
        
        -- TEST 1: Identity * Identity = Identity
        REPORT "Test 1: Identity matrix multiplication";
        test_num <= 1;
        a <= MAT4_IDENTITY;
        b <= MAT4_IDENTITY;
        tid_in <= X"0001";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        -- Wait for result
        WAIT UNTIL valid_out = '1';
        expected_c := MAT4_IDENTITY;
        
        result_match := (c.x1 = expected_c.x1) AND (c.x2 = expected_c.x2) AND 
                       (c.x3 = expected_c.x3) AND (c.x4 = expected_c.x4) AND
                       (c.y1 = expected_c.y1) AND (c.y2 = expected_c.y2) AND 
                       (c.y3 = expected_c.y3) AND (c.y4 = expected_c.y4) AND
                       (c.z1 = expected_c.z1) AND (c.z2 = expected_c.z2) AND 
                       (c.z3 = expected_c.z3) AND (c.z4 = expected_c.z4) AND
                       (c.w1 = expected_c.w1) AND (c.w2 = expected_c.w2) AND 
                       (c.w3 = expected_c.w3) AND (c.w4 = expected_c.w4);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 1 PASS";
        ELSE
            REPORT "Test 1 FAIL - Identity result mismatch" SEVERITY ERROR;
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- TEST 2: Matrix * Identity = Matrix
        REPORT "Test 2: Matrix * Identity";
        test_num <= 2;
        a.x1 <= FP_ONE;  a.x2 <= FP_TWO;  a.x3 <= FP_THREE; a.x4 <= FP_FOUR;
        a.y1 <= FP_TWO;  a.y2 <= FP_ONE;  a.y3 <= FP_FOUR;  a.y4 <= FP_THREE;
        a.z1 <= FP_THREE;a.z2 <= FP_FOUR; a.z3 <= FP_ONE;   a.z4 <= FP_TWO;
        a.w1 <= FP_FOUR; a.w2 <= FP_THREE;a.w3 <= FP_TWO;   a.w4 <= FP_ONE;
        b <= MAT4_IDENTITY;
        tid_in <= X"0002";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        WAIT UNTIL valid_out = '1';
        expected_c := a;
        
        result_match := (c.x1 = expected_c.x1) AND (c.x2 = expected_c.x2) AND 
                       (c.x3 = expected_c.x3) AND (c.x4 = expected_c.x4) AND
                       (c.y1 = expected_c.y1) AND (c.y2 = expected_c.y2) AND 
                       (c.y3 = expected_c.y3) AND (c.y4 = expected_c.y4) AND
                       (c.z1 = expected_c.z1) AND (c.z2 = expected_c.z2) AND 
                       (c.z3 = expected_c.z3) AND (c.z4 = expected_c.z4) AND
                       (c.w1 = expected_c.w1) AND (c.w2 = expected_c.w2) AND 
                       (c.w3 = expected_c.w3) AND (c.w4 = expected_c.w4);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 2 PASS";
        ELSE
            REPORT "Test 2 FAIL" SEVERITY ERROR;
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- TEST 3: All ones * All ones = All fours
        REPORT "Test 3: All-ones matrix multiplication";
        test_num <= 3;
        a.x1 <= FP_ONE; a.x2 <= FP_ONE; a.x3 <= FP_ONE; a.x4 <= FP_ONE;
        a.y1 <= FP_ONE; a.y2 <= FP_ONE; a.y3 <= FP_ONE; a.y4 <= FP_ONE;
        a.z1 <= FP_ONE; a.z2 <= FP_ONE; a.z3 <= FP_ONE; a.z4 <= FP_ONE;
        a.w1 <= FP_ONE; a.w2 <= FP_ONE; a.w3 <= FP_ONE; a.w4 <= FP_ONE;
        b.x1 <= FP_ONE; b.x2 <= FP_ONE; b.x3 <= FP_ONE; b.x4 <= FP_ONE;
        b.y1 <= FP_ONE; b.y2 <= FP_ONE; b.y3 <= FP_ONE; b.y4 <= FP_ONE;
        b.z1 <= FP_ONE; b.z2 <= FP_ONE; b.z3 <= FP_ONE; b.z4 <= FP_ONE;
        b.w1 <= FP_ONE; b.w2 <= FP_ONE; b.w3 <= FP_ONE; b.w4 <= FP_ONE;
        tid_in <= X"0003";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        WAIT UNTIL valid_out = '1';
        expected_c.x1 := FP_FOUR; expected_c.x2 := FP_FOUR; expected_c.x3 := FP_FOUR; expected_c.x4 := FP_FOUR;
        expected_c.y1 := FP_FOUR; expected_c.y2 := FP_FOUR; expected_c.y3 := FP_FOUR; expected_c.y4 := FP_FOUR;
        expected_c.z1 := FP_FOUR; expected_c.z2 := FP_FOUR; expected_c.z3 := FP_FOUR; expected_c.z4 := FP_FOUR;
        expected_c.w1 := FP_FOUR; expected_c.w2 := FP_FOUR; expected_c.w3 := FP_FOUR; expected_c.w4 := FP_FOUR;
        
        result_match := (c.x1 = expected_c.x1) AND (c.x2 = expected_c.x2) AND 
                       (c.x3 = expected_c.x3) AND (c.x4 = expected_c.x4) AND
                       (c.y1 = expected_c.y1) AND (c.y2 = expected_c.y2) AND 
                       (c.y3 = expected_c.y3) AND (c.y4 = expected_c.y4) AND
                       (c.z1 = expected_c.z1) AND (c.z2 = expected_c.z2) AND 
                       (c.z3 = expected_c.z3) AND (c.z4 = expected_c.z4) AND
                       (c.w1 = expected_c.w1) AND (c.w2 = expected_c.w2) AND 
                       (c.w3 = expected_c.w3) AND (c.w4 = expected_c.w4);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 3 PASS";
        ELSE
            REPORT "Test 3 FAIL" SEVERITY ERROR;
            REPORT "Result c[0,0]=" & to_hstring(c.x1) & " expected " & to_hstring(expected_c.x1);
            REPORT "Result c[0,1]=" & to_hstring(c.x2) & " expected " & to_hstring(expected_c.x2);
            REPORT "Result c[1,1]=" & to_hstring(c.y2) & " expected " & to_hstring(expected_c.y2);
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- TEST 4: Simple 2x2 pattern (upper left quadrant)
        -- [1 2] * [1 2] = [1 4]
        -- [0 0]   [0 0]   [0 0]
        REPORT "Test 4: Simple pattern multiplication";
        test_num <= 4;
        a.x1 <= FP_ONE; a.x2 <= FP_TWO; a.x3 <= FP_ZERO; a.x4 <= FP_ZERO;
        a.y1 <= FP_ZERO; a.y2 <= FP_ZERO; a.y3 <= FP_ZERO; a.y4 <= FP_ZERO;
        a.z1 <= FP_ZERO; a.z2 <= FP_ZERO; a.z3 <= FP_ZERO; a.z4 <= FP_ZERO;
        a.w1 <= FP_ZERO; a.w2 <= FP_ZERO; a.w3 <= FP_ZERO; a.w4 <= FP_ZERO;
        b.x1 <= FP_ONE; b.x2 <= FP_TWO; b.x3 <= FP_ZERO; b.x4 <= FP_ZERO;
        b.y1 <= FP_ZERO; b.y2 <= FP_ZERO; b.y3 <= FP_ZERO; b.y4 <= FP_ZERO;
        b.z1 <= FP_ZERO; b.z2 <= FP_ZERO; b.z3 <= FP_ZERO; b.z4 <= FP_ZERO;
        b.w1 <= FP_ZERO; b.w2 <= FP_ZERO; b.w3 <= FP_ZERO; b.w4 <= FP_ZERO;
        tid_in <= X"0004";
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        WAIT UNTIL valid_out = '1';
        -- [1,2,0,0] row dot [1,0,0,0] col = 1*1 = 1
        -- [1,2,0,0] row dot [2,0,0,0] col = 1*2 = 2  
        expected_c.x1 := FP_ONE; expected_c.x2 := FP_TWO; expected_c.x3 := FP_ZERO; expected_c.x4 := FP_ZERO;
        expected_c.y1 := FP_ZERO; expected_c.y2 := FP_ZERO; expected_c.y3 := FP_ZERO; expected_c.y4 := FP_ZERO;
        expected_c.z1 := FP_ZERO; expected_c.z2 := FP_ZERO; expected_c.z3 := FP_ZERO; expected_c.z4 := FP_ZERO;
        expected_c.w1 := FP_ZERO; expected_c.w2 := FP_ZERO; expected_c.w3 := FP_ZERO; expected_c.w4 := FP_ZERO;
        
        result_match := (c.x1 = expected_c.x1) AND (c.x2 = expected_c.x2) AND 
                       (c.x3 = expected_c.x3) AND (c.x4 = expected_c.x4) AND
                       (c.y1 = expected_c.y1) AND (c.y2 = expected_c.y2) AND 
                       (c.y3 = expected_c.y3) AND (c.y4 = expected_c.y4) AND
                       (c.z1 = expected_c.z1) AND (c.z2 = expected_c.z2) AND 
                       (c.z3 = expected_c.z3) AND (c.z4 = expected_c.z4) AND
                       (c.w1 = expected_c.w1) AND (c.w2 = expected_c.w2) AND 
                       (c.w3 = expected_c.w3) AND (c.w4 = expected_c.w4);
        
        IF result_match THEN
            pass_count <= pass_count + 1;
            REPORT "Test 4 PASS";
        ELSE
            REPORT "Test 4 FAIL" SEVERITY ERROR;
            REPORT "Result c[0,0]=" & to_hstring(c.x1) & " expected " & to_hstring(expected_c.x1);
            REPORT "Result c[0,1]=" & to_hstring(c.x2) & " expected " & to_hstring(expected_c.x2);
        END IF;
        WAIT FOR CLK_PERIOD * 5;
        
        -- Summary
        REPORT "=================================";
        REPORT "Tests passed: " & INTEGER'image(pass_count) & " / 4";
        IF pass_count = 4 THEN
            REPORT ">>> ALL MAT4_MULT TESTS PASSED <<<";
        ELSE
            REPORT ">>> SOME TESTS FAILED <<<" SEVERITY ERROR;
        END IF;
        REPORT "=================================";
        
        WAIT FOR CLK_PERIOD * 10;
        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
