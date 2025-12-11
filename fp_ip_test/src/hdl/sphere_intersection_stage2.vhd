LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

-- STAGE 2: Tests dot product calculations (b_dot and c_dot)
-- Hardcoded vhat from stage 1: vhat.x=-0.099887 vhat.y=0.994988 vhat.z=-0.004664
-- Expected: b_dot and c_dot values

ENTITY sphere_intersection_stage2 IS
    PORT (
        clk            : IN STD_LOGIC;
        reset          : IN STD_LOGIC;
        valid_in       : IN STD_LOGIC;
        ray            : IN Ray;
        obj            : IN RTObject;
        does_intersect : OUT STD_LOGIC;
        valid_out      : OUT STD_LOGIC;
        -- Debug outputs
        debug_vhat     : OUT Vec3;
        debug_b_dot    : OUT fp32;
        debug_c_dot    : OUT fp32
    );
END ENTITY sphere_intersection_stage2;

ARCHITECTURE behavioral OF sphere_intersection_stage2 IS

    ATTRIBUTE KEEP : STRING;
    ATTRIBUTE MARK_DEBUG : STRING;

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

    -- Hardcoded vhat from stage 1 (from test case 1)
    -- vhat.x=-0.099887 vhat.y=0.994988 vhat.z=-0.004664
    CONSTANT VHAT_HARDCODED : Vec3 := (
        x => X"bdcc918e", -- -0.099887
        y => X"3f7eb789", -- 0.994988
        z => X"bb98d478"  -- -0.004664
    );

    SIGNAL v_hat_normalized      : Vec3;
    SIGNAL calculate_bdot_valid  : STD_LOGIC;
    SIGNAL calculate_cdot_valid  : STD_LOGIC;
    SIGNAL trigger_calculate_bdot : STD_LOGIC;
    SIGNAL trigger_calculate_cdot : STD_LOGIC;
    SIGNAL b_dot                 : fp32;
    SIGNAL c_dot                 : fp32;

    TYPE state_type IS (
        IDLE,
        CALCULATE_BDOT_CDOT,
        DONE
    );

    SIGNAL state : state_type := IDLE;

    ATTRIBUTE KEEP OF v_hat_normalized : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_bdot_valid : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF calculate_cdot_valid : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF trigger_calculate_bdot : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF trigger_calculate_cdot : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF b_dot : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF c_dot : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF state : SIGNAL IS "TRUE";

BEGIN

    -- Use hardcoded vhat instead of normalize component
    v_hat_normalized <= VHAT_HARDCODED;
    debug_vhat <= v_hat_normalized;

    -- Dot product for b calculation: dot(ray.point1, vhat)
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

    -- Dot product for c calculation: dot(ray.point1, ray.point1)
    calculate_cdot_inst : vec3_dot_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_calculate_cdot,
        a         => ray.point1,
        b         => ray.point1,
        result    => c_dot,
        valid_out => calculate_cdot_valid
    );

    debug_b_dot <= b_dot;
    debug_c_dot <= c_dot;

    -- State Machine
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state                  <= IDLE;
            valid_out              <= '0';
            trigger_calculate_bdot <= '0';
            trigger_calculate_cdot <= '0';
            does_intersect         <= '0';
        ELSIF rising_edge(clk) THEN
            valid_out <= '0';

            CASE state IS
                WHEN IDLE =>
                    trigger_calculate_bdot <= '0';
                    trigger_calculate_cdot <= '0';
                    IF valid_in = '1' THEN
                        trigger_calculate_bdot <= '1';
                        trigger_calculate_cdot <= '1';
                        state                  <= CALCULATE_BDOT_CDOT;
                    END IF;

                WHEN CALCULATE_BDOT_CDOT =>
                    IF calculate_bdot_valid = '1' AND calculate_cdot_valid = '1' THEN
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
