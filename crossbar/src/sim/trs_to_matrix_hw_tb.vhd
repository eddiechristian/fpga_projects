LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL;

LIBRARY work;
USE work.lin_alg_pkg.ALL;

-- Testbench for TRS (Translate-Rotate-Scale) transformation module
-- Test case: Unit vector on X-axis [1,0,0,1]
--   - Scale by 5
--   - Translate by 5 in X direction only
--   - Rotate 45° around Y-axis
--   - Rotate 45° around Z-axis
--
-- Order of operations: Scale -> Rotate -> Translate
-- Expected result can be computed analytically

ENTITY trs_to_matrix_hw_tb IS
END ENTITY trs_to_matrix_hw_tb;

ARCHITECTURE behavioral OF trs_to_matrix_hw_tb IS

    -- Clock and reset
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '1';
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    
    -- DUT signals
    SIGNAL scale_x, scale_y, scale_z : fp32;
    SIGNAL rotation_x, rotation_y, rotation_z : fp32;
    SIGNAL translate_x, translate_y, translate_z : fp32;
    SIGNAL valid_in : STD_LOGIC := '0';
    SIGNAL transform_matrix : Mat4;
    SIGNAL inverse_matrix : Mat4;
    SIGNAL valid_out : STD_LOGIC;
    SIGNAL error : STD_LOGIC;
    
    -- Test vector signals
    SIGNAL test_vector : Vec4;
    SIGNAL transformed_vector : Vec4;
    SIGNAL mat_mult_valid_in : STD_LOGIC := '0';
    SIGNAL mat_mult_valid_out : STD_LOGIC;
    
    -- Testbench control
    SIGNAL sim_done : BOOLEAN := FALSE;
    
    -- FP constants
    CONSTANT FP_ZERO  : fp32 := X"00000000"; -- 0.0
    CONSTANT FP_ONE   : fp32 := X"3F800000"; -- 1.0
    CONSTANT FP_FIVE  : fp32 := X"40A00000"; -- 5.0
    CONSTANT FP_PI_4  : fp32 := X"3F490FDB"; -- π/4 ≈ 0.785398 (45 degrees in radians)
    
    -- mat4_vec4 multiply component
    COMPONENT mat4_vec4_mult_hw IS
        PORT (
            clk       : IN STD_LOGIC;
            reset     : IN STD_LOGIC;
            m_in      : IN Mat4;
            v_in      : IN Vec4;
            tid_in    : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            valid_in  : IN STD_LOGIC;
            v_out     : OUT Vec4;
            tid_out   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT;
    
    SIGNAL tid_dummy : STD_LOGIC_VECTOR(15 DOWNTO 0) := X"0000";

BEGIN

    -- Clock generation
    clk <= NOT clk AFTER CLK_PERIOD / 2 WHEN NOT sim_done ELSE '0';
    
    -- DUT instantiation
    dut : ENTITY work.trs_to_matrix_hw
        PORT MAP (
            clk              => clk,
            reset            => reset,
            scale_x          => scale_x,
            scale_y          => scale_y,
            scale_z          => scale_z,
            rotation_x       => rotation_x,
            rotation_y       => rotation_y,
            rotation_z       => rotation_z,
            translate_x      => translate_x,
            translate_y      => translate_y,
            translate_z      => translate_z,
            valid_in         => valid_in,
            transform_matrix => transform_matrix,
            inverse_matrix   => inverse_matrix,
            valid_out        => valid_out,
            error            => error
        );
    
    -- Matrix-vector multiplier for applying transformation
    mat_vec_mult : mat4_vec4_mult_hw
        PORT MAP (
            clk       => clk,
            reset     => reset,
            m_in      => transform_matrix,
            v_in      => test_vector,
            tid_in    => tid_dummy,
            valid_in  => mat_mult_valid_in,
            v_out     => transformed_vector,
            tid_out   => open,
            valid_out => mat_mult_valid_out
        );
    
    -- Test stimulus process
    stimulus_proc : PROCESS
    BEGIN
        -- Hold reset
        REPORT "Starting TRS transformation testbench...";
        reset <= '1';
        valid_in <= '0';
        mat_mult_valid_in <= '0';
        WAIT FOR CLK_PERIOD * 10;
        WAIT UNTIL rising_edge(clk);
        reset <= '0';
        WAIT FOR CLK_PERIOD * 5;
        
        REPORT "=== TRS TRANSFORMATION TEST ===";
        REPORT "Input: Unit vector on X-axis [1, 0, 0, 1]";
        REPORT "Scale: 5 on X-axis only";
        REPORT "No translation";
        REPORT "Rotate: 45 deg around Y-axis, then 45 deg around Z-axis";
        
        -- Set up transformation parameters
        -- Scale by 5 on X-axis only
        scale_x <= FP_FIVE;
        scale_y <= FP_ONE;
        scale_z <= FP_ONE;
        
        -- No rotation around X
        rotation_x <= FP_ZERO;
        
        -- Rotate 45° around Y-axis
        rotation_y <= FP_PI_4;
        
        -- Rotate 45° around Z-axis
        rotation_z <= FP_PI_4;
        
        -- No translation
        translate_x <= FP_ZERO;
        translate_y <= FP_ZERO;
        translate_z <= FP_ZERO;
        
        -- Set up test vector: unit vector on X-axis
        test_vector.x <= FP_ONE;   -- [1, 0, 0, 1]
        test_vector.y <= FP_ZERO;
        test_vector.z <= FP_ZERO;
        test_vector.w <= FP_ONE;
        
        -- Start TRS computation
        valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        valid_in <= '0';
        
        REPORT "Waiting for TRS matrix computation...";
        WAIT UNTIL valid_out = '1';
        
        IF error = '1' THEN
            REPORT "ERROR: TRS computation failed!" SEVERITY failure;
            sim_done <= TRUE;
            WAIT;
        END IF;
        
        REPORT "TRS matrix computed successfully!";
        REPORT "Transform matrix [0,0] = " & to_hstring(transform_matrix.x1);
        REPORT "Transform matrix [0,1] = " & to_hstring(transform_matrix.x2);
        REPORT "Transform matrix [0,2] = " & to_hstring(transform_matrix.x3);
        REPORT "Transform matrix [0,3] = " & to_hstring(transform_matrix.x4);
        
        WAIT FOR CLK_PERIOD * 5;
        
        -- Apply transformation to test vector
        REPORT "Applying transformation matrix to test vector...";
        mat_mult_valid_in <= '1';
        WAIT UNTIL rising_edge(clk);
        mat_mult_valid_in <= '0';
        
        WAIT UNTIL mat_mult_valid_out = '1';
        
        REPORT "=== TRANSFORMATION RESULT ===";
        REPORT "Input vector:  [1.0, 0.0, 0.0, 1.0]";
        REPORT "Output X: " & to_hstring(transformed_vector.x);
        REPORT "Output Y: " & to_hstring(transformed_vector.y);
        REPORT "Output Z: " & to_hstring(transformed_vector.z);
        REPORT "Output W: " & to_hstring(transformed_vector.w);
        
        -- Expected result (analytical):
        -- 1. Scale: [1,0,0] with scale_x=5 = [5,0,0]
        -- 2. Rotate Y by 45 deg: 
        --    x' = x*cos(45) + z*sin(45) = 5*0.707 + 0*0.707 = 3.536
        --    y' = y = 0
        --    z' = -x*sin(45) + z*cos(45) = -5*0.707 + 0*0.707 = -3.536
        --    Result: [3.536, 0, -3.536]
        -- 3. Rotate Z by 45 deg:
        --    x' = x*cos(45) - y*sin(45) = 3.536*0.707 - 0*0.707 = 2.5
        --    y' = x*sin(45) + y*cos(45) = 3.536*0.707 + 0*0.707 = 2.5
        --    z' = z = -3.536
        --    Result: [2.5, 2.5, -3.536]
        --
        -- Expected: approximately [2.5, 2.5, -3.536, 1.0]
        
        REPORT "Expected (analytical): X = 2.5, Y = 2.5, Z = -3.536, W = 1.0";
        
        -- Check if W component is correct (should be 1.0 for homogeneous coordinates)
        IF transformed_vector.w = FP_ONE THEN
            REPORT "W component correct: 1.0";
        ELSE
            REPORT "W component incorrect! Expected 1.0, got " & to_hstring(transformed_vector.w) SEVERITY failure;
        END IF;
        
        REPORT "=== TEST COMPLETE ===";
        REPORT "Note: Verify output values match expected analytical result";
        REPORT "Small differences (<1%) are acceptable due to FP precision";
        
        WAIT FOR CLK_PERIOD * 10;
        sim_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE behavioral;
