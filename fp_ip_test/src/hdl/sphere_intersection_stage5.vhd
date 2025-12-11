LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

-- STAGE 5: Tests discriminant comparison and sqrt
-- Hardcoded inttest from stage 4
-- Tests: inttest > 0 comparison, then sqrt(inttest)
-- Expected: inttest=0.000183 > 0 is TRUE, sqrt(0.000183) ≈ 0.0135

ENTITY sphere_intersection_stage5 IS
    PORT (
        clk               : IN STD_LOGIC;
        reset             : IN STD_LOGIC;
        valid_in          : IN STD_LOGIC;
        does_intersect    : OUT STD_LOGIC;
        valid_out         : OUT STD_LOGIC;
        -- Debug outputs
        debug_inttest     : OUT fp32;
        debug_compare_res : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        debug_sqrt        : OUT fp32
    );
END ENTITY sphere_intersection_stage5;

ARCHITECTURE behavioral OF sphere_intersection_stage5 IS

    ATTRIBUTE KEEP : STRING;

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

    -- Hardcoded from stage 4
    CONSTANT INTTEST_HARDCODED : fp32 := X"393fe3b0"; -- 0.000183 (approximate)

    SIGNAL calculate_inttest_result      : fp32;
    SIGNAL inttest_compare_valid         : STD_LOGIC;
    SIGNAL trigger_calculate_compare_inttest : STD_LOGIC;
    SIGNAL inttest_compare_result        : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL qsrt_inttest_valid            : STD_LOGIC;
    SIGNAL trigger_sqrt_inttest          : STD_LOGIC;
    SIGNAL qsrt_inttest_result           : fp32;

    TYPE state_type IS (
        IDLE,
        CALCULATE_COMPARE_INT_TEST,
        HIT_SUCCESS,
        NO_HIT,
        DONE
    );

    SIGNAL state : state_type := IDLE;

    ATTRIBUTE KEEP OF inttest_compare_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF qsrt_inttest_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF state : SIGNAL IS "TRUE";

BEGIN

    -- Use hardcoded inttest value
    calculate_inttest_result <= INTTEST_HARDCODED;
    debug_inttest <= calculate_inttest_result;

    -- Compare inttest > 0
    inttest_compare_inst : floating_point_compare
    PORT MAP(
        aclk                    => clk,
        s_axis_a_tvalid         => trigger_calculate_compare_inttest,
        s_axis_a_tdata          => calculate_inttest_result,
        s_axis_b_tvalid         => trigger_calculate_compare_inttest,
        s_axis_b_tdata          => X"00000000", -- 0.0
        s_axis_operation_tvalid => trigger_calculate_compare_inttest,
        s_axis_operation_tdata  => "00100100", -- greater than
        m_axis_result_tvalid    => inttest_compare_valid,
        m_axis_result_tdata     => inttest_compare_result
    );

    debug_compare_res <= inttest_compare_result;

    -- Calculate sqrt(inttest)
    qsrt_inttest_inst : floating_point_sqrt
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => trigger_sqrt_inttest,
        s_axis_a_tdata       => calculate_inttest_result,
        m_axis_result_tvalid => qsrt_inttest_valid,
        m_axis_result_tdata  => qsrt_inttest_result
    );

    debug_sqrt <= qsrt_inttest_result;

    -- State Machine
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state                             <= IDLE;
            valid_out                         <= '0';
            trigger_calculate_compare_inttest <= '0';
            trigger_sqrt_inttest              <= '0';
            does_intersect                    <= '0';
        ELSIF rising_edge(clk) THEN
            valid_out <= '0';

            CASE state IS
                WHEN IDLE =>
                    trigger_calculate_compare_inttest <= '0';
                    trigger_sqrt_inttest              <= '0';
                    IF valid_in = '1' THEN
                        trigger_calculate_compare_inttest <= '1';
                        state                             <= CALCULATE_COMPARE_INT_TEST;
                    END IF;

                WHEN CALCULATE_COMPARE_INT_TEST =>
                    IF inttest_compare_valid = '1' THEN
                        IF inttest_compare_result(0) = '1' THEN
                            -- inttest > 0, we have a hit
                            trigger_sqrt_inttest <= '1';
                            state                <= HIT_SUCCESS;
                        ELSE
                            -- No intersection
                            state <= NO_HIT;
                        END IF;
                    END IF;

                WHEN HIT_SUCCESS =>
                    IF qsrt_inttest_valid = '1' THEN
                        does_intersect <= '1';
                        valid_out      <= '1';
                        state          <= DONE;
                    END IF;

                WHEN NO_HIT =>
                    does_intersect <= '0';
                    valid_out      <= '1';
                    state          <= DONE;

                WHEN DONE =>
                    IF valid_in = '0' THEN
                        state <= IDLE;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
