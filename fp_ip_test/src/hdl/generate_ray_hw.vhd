LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

ENTITY generate_ray IS
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        proScreenX             : IN fp32;
        proScreenY             : IN fp32;
        valid_in               : IN STD_LOGIC;
        projectionScreenCentre : IN Vec3;
        projectionScreenU      : IN Vec3;
        projectionScreenV      : IN Vec3;
        cameraPosition         : IN Vec3;
        ray                    : OUT Ray;
        valid_out              : OUT STD_LOGIC -- Added OUT direction
    );
END ENTITY generate_ray;

ARCHITECTURE behavioral OF generate_ray IS

    -- Define component types for the required operations
    COMPONENT vec3_scale_hw
        PORT (
            clk       : IN STD_LOGIC;
            reset     : IN STD_LOGIC;
            valid_in  : IN STD_LOGIC;
            v         : IN Vec3;
            scalar    : IN fp32;
            result    : OUT Vec3;
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT vec3_add_hw
        PORT (
            clk       : IN STD_LOGIC;
            reset     : IN STD_LOGIC;
            valid_in  : IN STD_LOGIC;
            a         : IN Vec3;
            b         : IN Vec3;
            result    : OUT Vec3;
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT vec3_sub_hw
        PORT (
            clk       : IN STD_LOGIC;
            reset     : IN STD_LOGIC;
            valid_in  : IN STD_LOGIC;
            a         : IN Vec3;
            b         : IN Vec3;
            result    : OUT Vec3;
            valid_out : OUT STD_LOGIC
        );
    END COMPONENT;
    -- Internal Signals
    SIGNAL screenWorldPart1 : Vec3 := VEC3_ZERO;
    SIGNAL screenWorldCoordinate : Vec3 := VEC3_ZERO;
    SIGNAL point1 : Vec3 := VEC3_ZERO;
    SIGNAL lab : Vec3 := VEC3_ZERO;

    SIGNAL vec3_scale_U_proScreenX_result : Vec3 := VEC3_ZERO;
    SIGNAL vec3_scale_V_proScreenY_result : Vec3 := VEC3_ZERO;
    SIGNAL sub_result_lab : Vec3 := VEC3_ZERO;

    -- Valid signals from components
    SIGNAL vec3_scale_U_proScreenX_valid : STD_LOGIC;
    SIGNAL vec3_scale_V_proScreenY_valid : STD_LOGIC;
    SIGNAL vec3_add1_valid : STD_LOGIC;
    SIGNAL vec3_add2_valid : STD_LOGIC;
    SIGNAL vec3_sub_valid : STD_LOGIC;

    -- Control signals for triggering components at the right time
    SIGNAL trigger_scales, trigger_add1, trigger_add2, trigger_sub : STD_LOGIC := '0';

    -- State machine
    TYPE state_type IS (
        IDLE,
        WAIT_SCALES_DONE,
        WAIT_ADD1_DONE,
        WAIT_ADD2_DONE,
        WAIT_SUB_DONE,
        DONE
    );

    SIGNAL state : state_type := IDLE;

BEGIN
    -- Instance Declarations
    vec3_scale_U_proScreenX_inst : vec3_scale_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_scales AND valid_in, -- Trigger scales when input is valid
        v         => projectionScreenU,
        scalar    => proScreenX,
        result    => vec3_scale_U_proScreenX_result,
        valid_out => vec3_scale_U_proScreenX_valid
    );

    vec3_scale_V_proScreenY_inst : vec3_scale_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_scales AND valid_in,
        v         => projectionScreenV,
        scalar    => proScreenY,
        result    => vec3_scale_V_proScreenY_result,
        valid_out => vec3_scale_V_proScreenY_valid
    );

    vec3_add1_inst : vec3_add_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_add1,
        a         => projectionScreenCentre,
        b         => vec3_scale_U_proScreenX_result,
        result    => screenWorldPart1,
        valid_out => vec3_add1_valid
    );

    vec3_add2_inst : vec3_add_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_add2,
        a         => screenWorldPart1,
        b         => vec3_scale_V_proScreenY_result,
        result    => screenWorldCoordinate,
        valid_out => vec3_add2_valid
    );

    -- Instance for Subtraction
    vec3_sub_inst : vec3_sub_hw
    PORT MAP(
        clk       => clk,
        reset     => reset,
        valid_in  => trigger_sub,
        a         => screenWorldCoordinate,
        b         => cameraPosition,
        result    => sub_result_lab,
        valid_out => vec3_sub_valid
    );

    -- State Machine Process (Controller)
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state <= IDLE;
            valid_out <= '0';
            trigger_scales <= '0';
            trigger_add1 <= '0';
            trigger_add2 <= '0';
            trigger_sub <= '0';
            ray <= (VEC3_ZERO, VEC3_ZERO, VEC3_ZERO); -- Reset the entire ray record
        ELSIF rising_edge(clk) THEN
            -- Default outputs for the current cycle
            valid_out <= '0';
            trigger_scales <= '0';
            trigger_add1 <= '0';
            trigger_add2 <= '0';
            trigger_sub <= '0';

            CASE state IS
                WHEN IDLE =>
                    IF valid_in = '1' THEN
                        trigger_scales <= '1';
                        state <= WAIT_SCALES_DONE;
                    END IF;

                WHEN WAIT_SCALES_DONE =>
                    -- Wait for both scales to complete (assumes they take the same time)
                    IF vec3_scale_U_proScreenX_valid = '1' AND vec3_scale_V_proScreenY_valid = '1' THEN
                        trigger_add1 <= '1';
                        state <= WAIT_ADD1_DONE;
                    END IF;

                WHEN WAIT_ADD1_DONE =>
                    IF vec3_add1_valid = '1' THEN
                        trigger_add2 <= '1';
                        state <= WAIT_ADD2_DONE;
                    END IF;

                WHEN WAIT_ADD2_DONE =>
                    IF vec3_add2_valid = '1' THEN
                        -- screenWorldCoordinate is ready, now calculate 'lab'
                        trigger_sub <= '1';
                        -- Point 1 (m_cameraPosition) is fixed when valid_in starts, but assigned here for timing clarity
                        point1 <= cameraPosition;
                        state <= WAIT_SUB_DONE;
                    END IF;

                WHEN WAIT_SUB_DONE =>
                    IF vec3_sub_valid = '1' THEN
                        -- All calculations are done. Assign final outputs.
                        ray.m_point1 <= point1;
                        ray.m_point2 <= screenWorldCoordinate;
                        ray.lab <= sub_result_lab;
                        valid_out <= '1'; -- Signal valid data is available
                        state <= DONE;
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
