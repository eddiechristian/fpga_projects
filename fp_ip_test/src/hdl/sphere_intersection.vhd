LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

ENTITY sphere_intersection_hw IS
    PORT (
        clk            : IN STD_LOGIC;
        reset          : IN STD_LOGIC;
        valid_in       : IN STD_LOGIC;
        ray            : IN Ray;
        obj            : IN RTObject;
        does_intersect : OUT STD_LOGIC;
        intersect_pt   : OUT Vec3;
        localNormal    : OUT Vec3;
        color          : OUT Color;
        valid_out      : OUT STD_LOGIC;
    );
END ENTITY sphere_intersection_hw;

-- // Compute the values of a, b and c.
-- 	qbVector<double> vhat = castRay.m_lab;
-- 	vhat.Normalize();

-- 	/* Note that a is equal to the squared magnitude of the
-- 		direction of the cast ray. As this will be a unit vector,
-- 		we can conclude that the value of 'a' will always be 1. */
-- 	// a = 1.0;

-- 	// Calculate b.
-- 	double b = 2.0 * qbVector<double>::dot(castRay.m_point1, vhat);

-- 	// Calculate c.
-- 	double c = qbVector<double>::dot(castRay.m_point1, castRay.m_point1) - 1.0;

-- 	// Test whether we actually have an intersection.
-- 	double intTest = (b*b) - 4.0 * c;

-- 	if (intTest > 0.0)
-- 	{
-- 		double numSQRT = sqrtf(intTest);
-- 		double t1 = (-b + numSQRT) / 2.0;
-- 		double t2 = (-b - numSQRT) / 2.0;

-- 		/* If either t1 or t2 are negative, then at least part of the object is
-- 			behind the camera and so we will ignore it. */
-- 		if ((t1 < 0.0) || (t2 < 0.0))
-- 		{
-- 			return false;
-- 		}
-- 		else
-- 		{
-- 			// Determine which point of intersection was closest to the camera.
-- 			if (t1 < t2)
-- 			{
-- 				intPoint = castRay.m_point1 + (vhat * t1);
-- 			}
-- 			else
-- 			{
-- 				intPoint = castRay.m_point1 + (vhat * t2);
-- 			}
-- 		}

-- 		return true;
-- 	}
-- 	else
-- 	{
-- 		return false;
-- 	}

ARCHITECTURE behavioral OF sphere_intersection_hw IS

    COMPONENT vec3_normalize_hw
        PORT (
            clk       : IN STD_LOGIC;
            reset     : IN STD_LOGIC;
            valid_in  : IN STD_LOGIC;
            v         : IN Vec3;
            result    : OUT Vec3;
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT vec3_dot_hw
        PORT (
            clk       : IN STD_LOGIC;
            reset     : IN STD_LOGIC;
            valid_in  : IN STD_LOGIC;
            a         : IN Vec3;
            b         : IN Vec3;
            result    : OUT fp32;
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT floating_point_add
        PORT (
            aclk                 : IN STD_LOGIC;
            s_axis_a_tvalid      : IN STD_LOGIC;
            s_axis_a_tdata       : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_b_tvalid      : IN STD_LOGIC;
            s_axis_b_tdata       : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_result_tvalid : OUT STD_LOGIC;
            m_axis_result_tdata  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT floating_point_mult
        PORT (
            aclk                 : IN STD_LOGIC;
            s_axis_a_tvalid      : IN STD_LOGIC;
            s_axis_a_tdata       : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_b_tvalid      : IN STD_LOGIC;
            s_axis_b_tdata       : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_result_tvalid : OUT STD_LOGIC;
            m_axis_result_tdata  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT floating_point_compare
        PORT (
            aclk                    : IN STD_LOGIC;
            s_axis_a_tvalid         : IN STD_LOGIC;
            s_axis_a_tdata          : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
            s_axis_b_tvalid         : IN STD_LOGIC;
            s_axis_b_tdata          : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
            s_axis_operation_tvalid : IN STD_LOGIC;
            s_axis_operation_tdata  : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
            m_axis_result_tvalid    : OUT STD_LOGIC;
            m_axis_result_tdata     : OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT floating_point_sqrt
        PORT (
            aclk                 : IN STD_LOGIC;
            s_axis_a_tvalid      : IN STD_LOGIC;
            s_axis_a_tdata       : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_result_tvalid : OUT STD_LOGIC;
            m_axis_result_tdata  : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL v_hat_normalized                  : Vec3 := VEC3_ZERO;
    SIGNAL vhat_normalize_valid              : STD_LOGIC;
    SIGNAL calculate_bdot_valid              : STD_LOGIC;
    SIGNAL calculate_cdot_valid              : STD_LOGIC;
    SIGNAL calculate_b_valid                 : STD_LOGIC;
    SIGNAL calculate_c_valid                 : STD_LOGIC;
    SIGNAL calculate_b_squared_valid         : STD_LOGIC;
    SIGNAL calculate_4ac_valid               : STD_LOGIC;
    SIGNAL qsrt_inttest_valid                : STD_LOGIC;
    SIGNAL t1_add_b_valid                    : STD_LOGIC;
    SIGNAL t2_add_b_valid                    : STD_LOGIC;
    SIGNAL t1_compare_zero_valid             : STD_LOGIC;
    SIGNAL t2_compare_zero_valid             : STD_LOGIC;

    SIGNAL trigger_vhat_normalize            : STD_LOGIC;
    SIGNAL trigger_calculate_bdot            : STD_LOGIC;
    SIGNAL trigger_calculate_cdot            : STD_LOGIC;
    SIGNAL trigger_calculate_b               : STD_LOGIC;
    SIGNAL trigger_calculate_c               : STD_LOGIC;
    SIGNAL trigger_calculate_b_squared       : STD_LOGIC;
    SIGNAL trigger_calculate_4ac             : STD_LOGIC;
    SIGNAL trigger_calculate_compare_inttest : STD_LOGIC;
    SIGNAL trigger_sqrt_inttest              : STD_LOGIC;
    SIGNAL trigger_t1_add_b                  : STD_LOGIC;
    SIGNAL trigger_t2_add_b                  : STD_LOGIC;
    SIGNAL trigger_t1_comp_zero              : STD_LOGIC;
    SIGNAL trigger_t2_comp_zero              : STD_LOGIC;

    SIGNAL b_dot                             : fp32;
    SIGNAL calculate_b_result                : fp32;
    SIGNAL negated_b_result                  : fp32;
    SIGNAL c_dot                             : fp32;
    SIGNAL calculate_c_result                : fp32;
    SIGNAL calculate_b_squared_result        : fp32;
    SIGNAL calculate_4ac_result              : fp32;
    SIGNAL calculate_inttest_result          : fp32;
    SIGNAL qsrt_inttest_result               : fp32;
    SIGNAL negated_qsrt_inttest_result       : fp32;
    SIGNAL calculate_inttest_valid           : STD_LOGIC;
    SIGNAL inttest_compare_valid             : STD_LOGIC;
    SIGNAL inttest_compare_result            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL t1_add_b_result                   : fp32;
    SIGNAL t2_add_b_result                   : fp32;
    SIGNAL multiply_t1_valid                 : STD_LOGIC;
    SIGNAL multiply_t2_valid                 : STD_LOGIC;
    SIGNAL multiply_t1_result                : fp32;
    SIGNAL multiply_t2_result                : fp32;
    SIGNAL t1_compare_zero_result            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL t2_compare_zero_result            : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL t1_t2_compare_valid               : STD_LOGIC;
    SIGNAL t1_t2_compare_result              : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL trigger_calculate_inttest         : STD_LOGIC;
    SIGNAL trigger_t1_multiply               : STD_LOGIC;
    SIGNAL trigger_t2_multiply               : STD_LOGIC;
    SIGNAL trigger_compare_t1_t2             : STD_LOGIC;

    -- State machine
    TYPE state_type IS (
        IDLE,
        WAIT_NORMALIZE_DONE,
        CALCULATE_BDOT_CDOT,
        CALCULATE_B_AND_C,
        CALCULATE_B_SQUARED_AND_4AC,
        CALCULATE_INT_TEST,
        CALCULATE_COMPARE_INT_TEST,
        HIT_SUCCESS,
        NO_HIT,
        CALCULATE_SQRT_INTTEST,
        CALCULATE_T1_AND_T2_ADDS,
        CALCULATE_T1_AND_T2_MULTS,
        CALCULATE_COMPARE_T1_T2_ZERO,
        COMPARE_T1_T2,
        BEHIND_CAMERA,
        DONE
    );

    SIGNAL state      : state_type := IDLE;

    CONSTANT FP32_NAN : fp32       := X"0xFF800001";

BEGIN
    vhat_normalize_inst : vec3_normalize_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_vhat_normalize AND valid_in,
        v         => ray.lab,
        result    => v_hat_normalized,
        valid_out => vhat_normalize_valid
    );

    calculate_bdot_inst : vec3_dot_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_calculate_bdot,
        a         => ray.point1,
        b         => v_hat_normalized,
        result    => b_dot,
        valid_out => calculate_bdot_valid
    );

    calculate_cdot_inst : vec3_dot_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_calculate_cdot,
        a         => ray.point1,
        b         => v_hat_normalized,
        result    => c_dot,
        valid_out => calculate_cdot_valid
    );

    calculate_b_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => calculate_bdot_valid AND trigger_calculate_b,
        s_axis_a_tdata       => b_dot,
        s_axis_b_tvalid      => trigger_calculate_b,
        s_axis_b_tdata       => X"40000000", -- 2.0
        m_axis_result_tvalid => calculate_b_valid,
        m_axis_result_tdata  => calculate_b_result
    );

    calculate_c_inst : floating_point_add
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => calculate_cdot_valid AND trigger_calculate_c,
        s_axis_a_tdata       => c_dot,
        s_axis_b_tvalid      => trigger_calculate_c,
        s_axis_b_tdata       => X"BF800000", -- -1.0
        m_axis_result_tvalid => calculate_c_valid,
        m_axis_result_tdata  => calculate_c_result
    );

    calculate_b_squared_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => calculate_b_valid AND trigger_calculate_b_squared,
        s_axis_a_tdata       => calculate_b_result,
        s_axis_b_tvalid      => calculate_b_valid AND trigger_calculate_b_squared,
        s_axis_b_tdata       => calculate_b_result,
        m_axis_result_tvalid => calculate_b_squared_valid,
        m_axis_result_tdata  => calculate_b_squared_result
    );

    calculate_4ac_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => calculate_c_valid AND trigger_calculate_4ac,
        s_axis_a_tdata       => calculate_c_result,
        s_axis_b_tvalid      => trigger_calculate_4ac,
        s_axis_b_tdata       => X"c0800000", -- -4.0
        m_axis_result_tvalid => calculate_4ac_valid,
        m_axis_result_tdata  => calculate_4ac_result
    );

    calculate_inttest_inst : floating_point_add
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => calculate_b_squared_valid AND trigger_calculate_inttest,
        s_axis_a_tdata       => calculate_b_squared_result,
        s_axis_b_tvalid      => calculate_4ac_valid AND trigger_calculate_inttest,
        s_axis_b_tdata       => calculate_4ac_result,
        m_axis_result_tvalid => calculate_inttest_valid,
        m_axis_result_tdata  => calculate_inttest_result
    );

    inttest_compare_inst : floating_point_compare
    PORT MAP(
        aclk                    => clk,
        s_axis_a_tvalid         => calculate_inttest_valid AND trigger_calculate_compare_inttest,
        s_axis_a_tdata          => calculate_inttest_result,
        s_axis_b_tvalid         => trigger_calculate_compare_inttest,
        s_axis_b_tdata          => X"00000000", -- 0.0,
        s_axis_operation_tvalid => trigger_calculate_compare_inttest,
        s_axis_operation_tdata  => "00000100", --greater than
        m_axis_result_tvalid    => inttest_compare_valid,
        m_axis_result_tdata     => inttest_compare_result
    );

    qsrt_inttest_inst : floating_point_sqrt
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => calculate_inttest_valid AND trigger_sqrt_inttest,
        s_axis_a_tdata       => calculate_inttest_result,
        m_axis_result_tvalid => qsrt_inttest_valid,
        m_axis_result_tdata  => qsrt_inttest_result
    );

    t1_add_b_inst : floating_point_add
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => qsrt_inttest_valid AND trigger_t1_add_b,
        s_axis_a_tdata       => qsrt_inttest_result,
        s_axis_b_tvalid      => trigger_t1_add_b,
        s_axis_b_tdata       => negated_b_result,
        m_axis_result_tvalid => t1_add_b_valid,
        m_axis_result_tdata  => t1_add_b_result
    );

    t2_add_b_inst : floating_point_add
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => qsrt_inttest_valid AND trigger_t2_add_b,
        s_axis_a_tdata       => negated_qsrt_inttest_result,
        s_axis_b_tvalid      => trigger_t2_add_b,
        s_axis_b_tdata       => negated_b_result,
        m_axis_result_tvalid => t2_add_b_valid,
        m_axis_result_tdata  => t2_add_b_result
    );

    multiply_t1_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => t1_add_b_valid AND trigger_t1_multiply,
        s_axis_a_tdata       => t1_add_b_result,
        s_axis_b_tvalid      => trigger_t1_multiply,
        s_axis_b_tdata       => X"3f000000", -- 0.5
        m_axis_result_tvalid => multiply_t1_valid,
        m_axis_result_tdata  => multiply_t1_result
    );

    multiply_t2_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => t2_add_b_valid AND trigger_t2_multiply,
        s_axis_a_tdata       => t2_add_b_result,
        s_axis_b_tvalid      => trigger_t2_multiply,
        s_axis_b_tdata       => X"3f000000", -- 0.5
        m_axis_result_tvalid => multiply_t2_valid,
        m_axis_result_tdata  => multiply_t2_result
    );

    t1_compare_zero_inst : floating_point_compare
    PORT MAP(
        aclk                    => clk,
        s_axis_a_tvalid         => multiply_t1_valid AND trigger_t1_comp_zero,
        s_axis_a_tdata          => multiply_t1_result,
        s_axis_b_tvalid         => trigger_t1_comp_zero,
        s_axis_b_tdata          => X"00000000", -- 0.0,
        s_axis_operation_tvalid => trigger_t1_comp_zero,
        s_axis_operation_tdata  => "00000001", --less than
        m_axis_result_tvalid    => t1_compare_zero_valid,
        m_axis_result_tdata     => t1_compare_zero_result
    );

    t2_compare_zero_inst : floating_point_compare
    PORT MAP(
        aclk                    => clk,
        s_axis_a_tvalid         => multiply_t2_valid AND trigger_t2_comp_zero,
        s_axis_a_tdata          => multiply_t2_result,
        s_axis_b_tvalid         => trigger_t2_comp_zero,
        s_axis_b_tdata          => X"00000000", -- 0.0,
        s_axis_operation_tvalid => trigger_t2_comp_zero,
        s_axis_operation_tdata  => "00000001", --less than
        m_axis_result_tvalid    => t2_compare_zero_valid,
        m_axis_result_tdata     => t2_compare_zero_result
    );

    t1_t2_compare_inst : floating_point_compare
    PORT MAP(
        aclk                    => clk,
        s_axis_a_tvalid         => multiply_t1_valid AND trigger_compare_t1_t2,
        s_axis_a_tdata          => multiply_t1_result,
        s_axis_b_tvalid         => multiply_t2_valid AND trigger_compare_t1_t2,
        s_axis_b_tdata          => multiply_t2_result,
        s_axis_operation_tvalid => trigger_compare_t1_t2,
        s_axis_operation_tdata  => "00000001", --less than
        m_axis_result_tvalid    => t1_t2_compare_valid,
        m_axis_result_tdata     => t1_t2_compare_result
    );

    -- State Machine Process (Controller)
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state                             <= IDLE;
            valid_out                         <= '0';
            trigger_vhat_normalize            <= '0';
            trigger_calculate_bdot            <= '0';
            trigger_calculate_cdot            <= '0';
            trigger_calculate_b               <= '0';
            trigger_calculate_c               <= '0';
            calculate_b_result                <= FP32_NAN;
            calculate_c_result                <= FP32_NAN;
            trigger_calculate_b_squared       <= '0';
            calculate_b_squared_valid         <= '0';
            trigger_calculate_4ac             <= '0';
            calculate_4ac_valid               <= '0';
            calculate_4ac_result              <= FP32_NAN;
            trigger_calculate_compare_inttest <= '0';
            inttest_compare_valid             <= '0';
            trigger_sqrt_inttest              <= '0';
            t1_add_b_result                   <= (OTHERS => '0');
            t2_add_b_result                   <= (OTHERS => '0');
            t1_add_b_valid                    <= '0';
            t2_add_b_valid                    <= '0';
            trigger_t1_multiply               <= '0';
            trigger_t2_multiply               <= '0';
            trigger_t1_comp_zero              <= '0';
            trigger_t2_comp_zero              <= '0';
            t1_compare_zero_result            <= (OTHERS => '0');
            t2_compare_zero_result            <= (OTHERS => '0');
            trigger_compare_t1_t2             <= '0';
        ELSIF rising_edge(clk) THEN
            -- Default outputs for the current cycle
            valid_out <= '0';
            CASE state IS
                WHEN IDLE =>
                    IF valid_in = '1' THEN
                        trigger_vhat_normalize <= '1';
                        state                  <= WAIT_NORMALIZE_DONE;
                    END IF;

                WHEN WAIT_NORMALIZE_DONE =>
                    IF vhat_normalize_valid = '1' THEN
                        trigger_calculate_bdot <= '1';
                        trigger_calculate_cdot <= '1';
                        state                  <= CALCULATE_BDOT_CDOT;
                    END IF;
                WHEN CALCULATE_BDOT_CDOT =>
                    IF calculate_bdot_valid = '1' AND calculate_cdot_valid = '1' THEN
                        trigger_calculate_b <= '1';
                        trigger_calculate_c <= '1';
                        state               <= CALCULATE_B_AND_C;
                    END IF;
                WHEN CALCULATE_B_AND_C =>
                    IF calculate_b_valid = '1' AND calculate_c_valid = '1' THEN
                        trigger_calculate_b_squared <= '1';
                        trigger_calculate_4ac       <= '1';
                        negated_b_result            <= calculate_b_result XOR X"80000000";
                        state                       <= CALCULATE_B_SQUARED_AND_4AC;
                    END IF;
                WHEN CALCULATE_B_SQUARED_AND_4AC =>
                    IF calculate_b_squared_valid = '1' AND calculate_4ac_valid = '1' THEN
                        trigger_calculate_inttest <= '1';
                        state                     <= CALCULATE_INT_TEST;
                    END IF;
                WHEN CALCULATE_INT_TEST =>
                    IF calculate_inttest_valid = '1' THEN
                        trigger_calculate_compare_inttest <= '1';
                        state                             <= CALCULATE_COMPARE_INT_TEST;
                    END IF;
                WHEN CALCULATE_COMPARE_INT_TEST =>
                    IF inttest_compare_valid = '1' THEN
                        IF inttest_compare_result(0) = '1' THEN
                            state                <= HIT_SUCCESS;
                            trigger_sqrt_inttest <= '1';
                        ELSE
                            state <= NO_HIT;
                        END IF;

                    END IF;
                WHEN HIT_SUCCESS =>
                    IF qsrt_inttest_valid = '1' THEN
                        state                       <= CALCULATE_T1_AND_T2_ADDS;
                        negated_qsrt_inttest_result <= qsrt_inttest_result XOR X"80000000";
                        trigger_t1_add_b            <= '1';
                        trigger_t2_add_b            <= '1';
                    END IF;
                WHEN CALCULATE_T1_AND_T2_ADDS =>
                    IF t1_add_b_valid = '1' AND t2_add_b_valid = '1' THEN
                        trigger_t1_multiply <= '1';
                        trigger_t2_multiply <= '1';
                        state               <= CALCULATE_T1_AND_T2_MULTS;
                    END IF;
                WHEN CALCULATE_T1_AND_T2_MULTS =>
                    IF multiply_t1_valid = '1' AND multiply_t2_valid = '1' THEN
                        trigger_t1_comp_zero <= '1';
                        trigger_t2_comp_zero <= '1';
                        state                <= CALCULATE_COMPARE_T1_T2_ZERO;
                    END IF;
                WHEN CALCULATE_COMPARE_T1_T2_ZERO =>
                    IF t1_compare_zero_valid = '1' AND t2_compare_zero_valid = '1' THEN
                        IF t1_compare_zero_result(0) = '1' OR t2_compare_zero_result(0) = '1' THEN
                            state <= BEHIND_CAMERA;
                        ELSE
                            trigger_compare_t1_t2 <= '1';
                            state                 <= COMPARE_T1_T2;
                        END IF;
                    END IF;
                WHEN COMPARE_T1_T2 =>
                    IF t1_t2_compare_valid = '1' THEN
                        IF t1_t2_compare_result(0) = '1' THEN
                        
                        ELSE
                        END IF;
                    END IF;
                WHEN BEHIND_CAMERA =>
                    does_intersect <= '0';
                    valid_out      <= '1';
                    IF valid_in = '0' THEN
                        state     <= IDLE;
                        valid_out <= '0';
                    END IF;
                WHEN NO_HIT =>
                    does_intersect <= '0';
                    valid_out      <= '1';
                    IF valid_in = '0' THEN
                        state     <= IDLE;
                        valid_out <= '0';
                    END IF;
                WHEN DONE =>
                    -- Stay in DONE state until reset or valid_in drops and comes back up
                    -- If we want continuous processing, we need a mechanism to return to IDLE after one cycle of valid_out='1'
                    IF valid_in = '0' THEN
                        state <= IDLE;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;