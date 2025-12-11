LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

-- STAGE 4: Tests discriminant calculation (inttest = b^2 - 4*c)
-- Hardcoded b and c from stage 3
-- Expected: b^2=396.00018311  4*c=396.00000000  inttest=0.000183

ENTITY sphere_intersection_stage4 IS
    PORT (
        clk            : IN STD_LOGIC;
        reset          : IN STD_LOGIC;
        valid_in       : IN STD_LOGIC;
        does_intersect : OUT STD_LOGIC;
        valid_out      : OUT STD_LOGIC;
        -- Debug outputs
        debug_b_squared : OUT fp32;
        debug_4c        : OUT fp32;
        debug_inttest   : OUT fp32
    );
END ENTITY sphere_intersection_stage4;

ARCHITECTURE behavioral OF sphere_intersection_stage4 IS

    ATTRIBUTE KEEP : STRING;

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

    -- Hardcoded from stage 3
    CONSTANT B_HARDCODED : fp32 := X"c19f32b2"; -- -19.899754
    CONSTANT C_HARDCODED : fp32 := X"42C60000"; -- 99.0

    SIGNAL calculate_b_result            : fp32;
    SIGNAL calculate_c_result            : fp32;
    SIGNAL calculate_b_squared_valid     : STD_LOGIC;
    SIGNAL calculate_4ac_valid           : STD_LOGIC;
    SIGNAL trigger_calculate_b_squared   : STD_LOGIC;
    SIGNAL trigger_calculate_4ac         : STD_LOGIC;
    SIGNAL calculate_b_squared_result    : fp32;
    SIGNAL calculate_4ac_result          : fp32;
    SIGNAL calculate_inttest_valid       : STD_LOGIC;
    SIGNAL trigger_calculate_inttest     : STD_LOGIC;
    SIGNAL calculate_inttest_result      : fp32;

    TYPE state_type IS (
        IDLE,
        CALCULATE_B_SQUARED_AND_4AC,
        CALCULATE_INT_TEST,
        DONE
    );

    SIGNAL state : state_type := IDLE;

    ATTRIBUTE KEEP OF calculate_b_squared_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_4ac_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_inttest_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF state : SIGNAL IS "TRUE";

BEGIN

    -- Use hardcoded values
    calculate_b_result <= B_HARDCODED;
    calculate_c_result <= C_HARDCODED;

    -- Calculate b^2
    calculate_b_squared_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => trigger_calculate_b_squared,
        s_axis_a_tdata       => calculate_b_result,
        s_axis_b_tvalid      => trigger_calculate_b_squared,
        s_axis_b_tdata       => calculate_b_result,
        m_axis_result_tvalid => calculate_b_squared_valid,
        m_axis_result_tdata  => calculate_b_squared_result
    );

    -- Calculate 4*c (actually -4*c since we'll add it)
    calculate_4ac_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => trigger_calculate_4ac,
        s_axis_a_tdata       => calculate_c_result,
        s_axis_b_tvalid      => trigger_calculate_4ac,
        s_axis_b_tdata       => X"C0800000", -- -4.0
        m_axis_result_tvalid => calculate_4ac_valid,
        m_axis_result_tdata  => calculate_4ac_result
    );

    -- Calculate inttest = b^2 - 4*c (which is b^2 + (-4*c))
    calculate_inttest_inst : floating_point_add
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => trigger_calculate_inttest,
        s_axis_a_tdata       => calculate_b_squared_result,
        s_axis_b_tvalid      => trigger_calculate_inttest,
        s_axis_b_tdata       => calculate_4ac_result,
        m_axis_result_tvalid => calculate_inttest_valid,
        m_axis_result_tdata  => calculate_inttest_result
    );

    debug_b_squared <= calculate_b_squared_result;
    debug_4c <= calculate_4ac_result;
    debug_inttest <= calculate_inttest_result;

    -- State Machine
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state                          <= IDLE;
            valid_out                      <= '0';
            trigger_calculate_b_squared    <= '0';
            trigger_calculate_4ac          <= '0';
            trigger_calculate_inttest      <= '0';
            does_intersect                 <= '0';
        ELSIF rising_edge(clk) THEN
            valid_out <= '0';

            CASE state IS
                WHEN IDLE =>
                    trigger_calculate_b_squared <= '0';
                    trigger_calculate_4ac       <= '0';
                    trigger_calculate_inttest   <= '0';
                    IF valid_in = '1' THEN
                        trigger_calculate_b_squared <= '1';
                        trigger_calculate_4ac       <= '1';
                        state                       <= CALCULATE_B_SQUARED_AND_4AC;
                    END IF;

                WHEN CALCULATE_B_SQUARED_AND_4AC =>
                    IF calculate_b_squared_valid = '1' AND calculate_4ac_valid = '1' THEN
                        trigger_calculate_inttest <= '1';
                        state                     <= CALCULATE_INT_TEST;
                    END IF;

                WHEN CALCULATE_INT_TEST =>
                    trigger_calculate_inttest <= '0';
                    IF calculate_inttest_valid = '1' THEN
                        does_intersect <= '1';
                        valid_out      <= '1';
                        state          <= DONE;
                    END IF;

                WHEN DONE =>
                    IF valid_in = '0' THEN
                        state <= IDLE;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
