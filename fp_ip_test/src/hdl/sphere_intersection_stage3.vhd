LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

-- STAGE 3: Tests b and c calculations
-- Hardcoded b_dot (from stage 2)
-- Hardcoded c_dot (from stage 2)
-- Calculates: b = 2.0 * b_dot  and  c = c_dot - 1.0
-- Expected: b=-19.899754 c=99.000000

ENTITY sphere_intersection_stage3 IS
    PORT (
        clk            : IN STD_LOGIC;
        reset          : IN STD_LOGIC;
        valid_in       : IN STD_LOGIC;
        does_intersect : OUT STD_LOGIC;
        valid_out      : OUT STD_LOGIC;
        -- Debug outputs
        debug_b        : OUT fp32;
        debug_c        : OUT fp32
    );
END ENTITY sphere_intersection_stage3;

ARCHITECTURE behavioral OF sphere_intersection_stage3 IS

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

    -- Hardcoded from stage 2 (you'll fill these in after running stage 2)
    -- For now using expected values based on test case 1:
    -- b_dot should be approximately -9.949877 (half of b=-19.899754)
    CONSTANT B_DOT_HARDCODED : fp32 := X"c11f32b2"; -- -9.949877
    CONSTANT C_DOT_HARDCODED : fp32 := X"42C80000"; -- 100.0 (point1 is at distance 10 from origin)

    SIGNAL b_dot                 : fp32;
    SIGNAL c_dot                 : fp32;
    SIGNAL calculate_b_valid     : STD_LOGIC;
    SIGNAL calculate_c_valid     : STD_LOGIC;
    SIGNAL trigger_calculate_b   : STD_LOGIC;
    SIGNAL trigger_calculate_c   : STD_LOGIC;
    SIGNAL calculate_b_result    : fp32;
    SIGNAL calculate_c_result    : fp32;

    TYPE state_type IS (
        IDLE,
        CALCULATE_B_AND_C,
        DONE
    );

    SIGNAL state : state_type := IDLE;

    ATTRIBUTE KEEP OF calculate_b_valid : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_c_valid : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_b_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_c_result : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF state : SIGNAL IS "TRUE";

BEGIN

    -- Use hardcoded values from stage 2
    b_dot <= B_DOT_HARDCODED;
    c_dot <= C_DOT_HARDCODED;

    -- Calculate b = 2.0 * b_dot
    calculate_b_inst : floating_point_mult
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => trigger_calculate_b,
        s_axis_a_tdata       => b_dot,
        s_axis_b_tvalid      => trigger_calculate_b,
        s_axis_b_tdata       => X"40000000", -- 2.0
        m_axis_result_tvalid => calculate_b_valid,
        m_axis_result_tdata  => calculate_b_result
    );

    -- Calculate c = c_dot - 1.0
    calculate_c_inst : floating_point_add
    PORT MAP(
        aclk                 => clk,
        s_axis_a_tvalid      => trigger_calculate_c,
        s_axis_a_tdata       => c_dot,
        s_axis_b_tvalid      => trigger_calculate_c,
        s_axis_b_tdata       => X"BF800000", -- -1.0
        m_axis_result_tvalid => calculate_c_valid,
        m_axis_result_tdata  => calculate_c_result
    );

    debug_b <= calculate_b_result;
    debug_c <= calculate_c_result;

    -- State Machine
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state                  <= IDLE;
            valid_out              <= '0';
            trigger_calculate_b    <= '0';
            trigger_calculate_c    <= '0';
            does_intersect         <= '0';
        ELSIF rising_edge(clk) THEN
            valid_out <= '0';

            CASE state IS
                WHEN IDLE =>
                    trigger_calculate_b <= '0';
                    trigger_calculate_c <= '0';
                    IF valid_in = '1' THEN
                        trigger_calculate_b <= '1';
                        trigger_calculate_c <= '1';
                        state               <= CALCULATE_B_AND_C;
                    END IF;

                WHEN CALCULATE_B_AND_C =>
                    IF calculate_b_valid = '1' AND calculate_c_valid = '1' THEN
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
