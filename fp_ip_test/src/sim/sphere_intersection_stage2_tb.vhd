LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

ENTITY sphere_intersection_stage2_tb IS
END ENTITY sphere_intersection_stage2_tb;

ARCHITECTURE testbench OF sphere_intersection_stage2_tb IS

    COMPONENT sphere_intersection_stage2
        PORT (
            clk            : IN STD_LOGIC;
            reset          : IN STD_LOGIC;
            valid_in       : IN STD_LOGIC;
            ray            : IN Ray;
            obj            : IN RTObject;
            does_intersect : OUT STD_LOGIC;
            valid_out      : OUT STD_LOGIC;
            debug_vhat     : OUT Vec3;
            debug_b_dot    : OUT fp32;
            debug_c_dot    : OUT fp32
        );
    END COMPONENT;

    SIGNAL clk            : STD_LOGIC := '0';
    SIGNAL reset          : STD_LOGIC := '0';
    SIGNAL valid_in       : STD_LOGIC := '0';
    SIGNAL test_done      : BOOLEAN := FALSE;
    SIGNAL test_ray       : Ray;
    SIGNAL test_obj       : RTObject;
    SIGNAL does_intersect : STD_LOGIC;
    SIGNAL valid_out      : STD_LOGIC;
    SIGNAL debug_vhat     : Vec3;
    SIGNAL debug_b_dot    : fp32;
    SIGNAL debug_c_dot    : fp32;
    CONSTANT clk_period   : TIME := 10 ns;

BEGIN

    uut : sphere_intersection_stage2
        PORT MAP (
            clk            => clk,
            reset          => reset,
            valid_in       => valid_in,
            ray            => test_ray,
            obj            => test_obj,
            does_intersect => does_intersect,
            valid_out      => valid_out,
            debug_vhat     => debug_vhat,
            debug_b_dot    => debug_b_dot,
            debug_c_dot    => debug_c_dot
        );

    clk_process : PROCESS
    BEGIN
        WHILE NOT test_done LOOP
            clk <= '0';
            WAIT FOR clk_period / 2;
            clk <= '1';
            WAIT FOR clk_period / 2;
        END LOOP;
        WAIT;
    END PROCESS;

    stim_proc : PROCESS
    BEGIN
        reset <= '1';
        valid_in <= '0';
        test_obj.color.red   <= X"00000000";
        test_obj.color.green <= X"00000000";
        test_obj.color.blue  <= X"3F800000";

        WAIT FOR 100 ns;
        reset <= '0';
        WAIT FOR 50 ns;

        REPORT "Stage 2 Test: Dot products for b and c calculations";
        REPORT "Expected: b_dot (for calculating b=-19.899754)";
        REPORT "Expected: c_dot (for calculating c=99.0)";

        -- Input ray with point1 at (0, -10, 0)
        test_ray.lab.x    <= X"BDCD7B00";
        test_ray.lab.y    <= X"3F800000";
        test_ray.lab.z    <= X"BB999000";
        test_ray.point1.x <= X"00000000"; -- 0.0
        test_ray.point1.y <= X"C1200000"; -- -10.0
        test_ray.point1.z <= X"00000000"; -- 0.0
        test_ray.point2.x <= X"BDCD7B00";
        test_ray.point2.y <= X"C1100000";
        test_ray.point2.z <= X"BB999000";

        valid_in <= '1';
        WAIT FOR clk_period;

        WAIT UNTIL valid_out = '1' FOR 100000 ns;

        IF valid_out = '1' THEN
            REPORT "Stage 2 COMPLETE - Check waveform for b_dot and c_dot values";
        ELSE
            REPORT "Stage 2 TIMEOUT" SEVERITY ERROR;
        END IF;

        WAIT FOR 200 ns;
        test_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;
