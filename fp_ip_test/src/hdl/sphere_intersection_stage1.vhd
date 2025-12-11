LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

-- STAGE 1 ONLY: Tests only the vector normalization step
-- This version only instantiates vec3_normalize_hw and tests IDLE -> WAIT_NORMALIZE_DONE -> DONE
-- All other floating point components are commented out to speed up synthesis

ENTITY sphere_intersection_stage1 IS
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
        -- Debug outputs for stage 1
        debug_vhat     : OUT Vec3
    );
END ENTITY sphere_intersection_stage1;

ARCHITECTURE behavioral OF sphere_intersection_stage1 IS

    -- Attributes to prevent optimization
    ATTRIBUTE KEEP : STRING;
    ATTRIBUTE MARK_DEBUG : STRING;

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

    -- Only signals needed for stage 1
    SIGNAL v_hat_normalized    : Vec3 := VEC3_ZERO;
    SIGNAL vhat_normalize_valid : STD_LOGIC;
    SIGNAL trigger_vhat_normalize : STD_LOGIC;

    -- State machine (simplified)
    TYPE state_type IS (
        IDLE,
        WAIT_NORMALIZE_DONE,
        DONE
        -- All other states commented out for stage 1
        -- CALCULATE_BDOT_CDOT,
        -- CALCULATE_B_AND_C,
        -- CALCULATE_B_SQUARED_AND_4AC,
        -- CALCULATE_INT_TEST,
        -- CALCULATE_COMPARE_INT_TEST,
        -- HIT_SUCCESS,
        -- NO_HIT,
        -- CALCULATE_SQRT_INTTEST,
        -- CALCULATE_T1_AND_T2_ADDS,
        -- CALCULATE_T1_AND_T2_MULTS,
        -- CALCULATE_COMPARE_T1_T2_ZERO,
        -- COMPARE_T1_T2,
        -- CALCULATE_SCALE_VHAT,
        -- CALCULATE_INTERSECTION_POINT,
        -- BEHIND_CAMERA
    );

    SIGNAL state : state_type := IDLE;

    -- Apply KEEP attribute to signals
    ATTRIBUTE KEEP OF v_hat_normalized : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF vhat_normalize_valid : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF trigger_vhat_normalize : SIGNAL IS "TRUE";
    ATTRIBUTE KEEP OF state : SIGNAL IS "TRUE";

BEGIN

    -- Stage 1: Only normalize component
    vhat_normalize_inst : vec3_normalize_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_vhat_normalize,
        v         => ray.lab,
        result    => v_hat_normalized,
        valid_out => vhat_normalize_valid
    );

    -- Debug output
    debug_vhat <= v_hat_normalized;

    -- All other component instantiations commented out for stage 1
    -- calculate_bdot_inst : vec3_dot_hw ...
    -- calculate_cdot_inst : vec3_dot_hw ...
    -- calculate_b_inst : floating_point_mult ...
    -- calculate_c_inst : floating_point_add ...
    -- calculate_b_squared_inst : floating_point_mult ...
    -- calculate_4ac_inst : floating_point_mult ...
    -- calculate_inttest_inst : floating_point_add ...
    -- inttest_compare_inst : floating_point_compare ...
    -- qsrt_inttest_inst : floating_point_sqrt ...
    -- t1_add_b_inst : floating_point_add ...
    -- t2_add_b_inst : floating_point_add ...
    -- multiply_t1_inst : floating_point_mult ...
    -- multiply_t2_inst : floating_point_mult ...
    -- t1_compare_zero_inst : floating_point_compare ...
    -- t2_compare_zero_inst : floating_point_compare ...
    -- t1_t2_compare_inst : floating_point_compare ...
    -- scale_vhat_inst : vec3_scale_hw ...
    -- add_intersection_inst : vec3_add_hw ...

    -- State Machine Process (Simplified for Stage 1)
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state                  <= IDLE;
            valid_out              <= '0';
            trigger_vhat_normalize <= '0';
            does_intersect         <= '0';
            intersect_pt           <= VEC3_ZERO;
            localNormal            <= VEC3_ZERO;
            color                  <= (red => X"00000000", green => X"00000000", blue => X"00000000");
        ELSIF rising_edge(clk) THEN
            -- Default outputs for the current cycle
            valid_out <= '0';
            
            CASE state IS
                WHEN IDLE =>
                    trigger_vhat_normalize <= '0';
                    IF valid_in = '1' THEN
                        trigger_vhat_normalize <= '1';
                        state                  <= WAIT_NORMALIZE_DONE;
                    END IF;

                WHEN WAIT_NORMALIZE_DONE =>
                    IF vhat_normalize_valid = '1' THEN
                        -- Stage 1 complete - output the normalized vector
                        does_intersect <= '1'; -- Just for testing, mark as success
                        color          <= obj.color;
                        localNormal    <= v_hat_normalized; -- Output normalized vector as normal
                        intersect_pt   <= v_hat_normalized; -- Output normalized vector as intersection point
                        valid_out      <= '1';
                        state          <= DONE;
                    END IF;

                WHEN DONE =>
                    -- Stay in DONE state until valid_in drops
                    IF valid_in = '0' THEN
                        state <= IDLE;
                    END IF;

                -- All other states commented out for stage 1
                -- WHEN CALCULATE_BDOT_CDOT =>
                --     IF calculate_bdot_valid = '1' AND calculate_cdot_valid = '1' THEN
                --         trigger_calculate_b <= '1';
                --         trigger_calculate_c <= '1';
                --         state               <= CALCULATE_B_AND_C;
                --     END IF;
                
                -- WHEN CALCULATE_B_AND_C =>
                --     IF calculate_b_valid = '1' AND calculate_c_valid = '1' THEN
                --         trigger_calculate_b_squared <= '1';
                --         trigger_calculate_4ac       <= '1';
                --         negated_b_result            <= calculate_b_result XOR X"80000000";
                --         state                       <= CALCULATE_B_SQUARED_AND_4AC;
                --     END IF;
                
                -- ... (rest of states commented out)

            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
