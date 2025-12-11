LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

ENTITY sphere_intersection_stage1_tb IS
END ENTITY sphere_intersection_stage1_tb;

ARCHITECTURE testbench OF sphere_intersection_stage1_tb IS

    COMPONENT sphere_intersection_stage1
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
            debug_vhat     : OUT Vec3
        );
    END COMPONENT;

    -- Clock and control
    SIGNAL clk            : STD_LOGIC := '0';
    SIGNAL reset          : STD_LOGIC := '0';
    SIGNAL valid_in       : STD_LOGIC := '0';
    SIGNAL test_done      : BOOLEAN := FALSE;

    -- Test inputs
    SIGNAL test_ray       : Ray;
    SIGNAL test_obj       : RTObject;

    -- Test outputs
    SIGNAL does_intersect : STD_LOGIC;
    SIGNAL intersect_pt   : Vec3;
    SIGNAL localNormal    : Vec3;
    SIGNAL color          : Color;
    SIGNAL valid_out      : STD_LOGIC;
    SIGNAL debug_vhat     : Vec3;

    CONSTANT clk_period   : TIME := 10 ns;

BEGIN

    uut : sphere_intersection_stage1
        PORT MAP (
            clk            => clk,
            reset          => reset,
            valid_in       => valid_in,
            ray            => test_ray,
            obj            => test_obj,
            does_intersect => does_intersect,
            intersect_pt   => intersect_pt,
            localNormal    => localNormal,
            color          => color,
            valid_out      => valid_out,
            debug_vhat     => debug_vhat
        );

    -- Clock generation
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

    -- Test stimulus
    stim_proc : PROCESS
    BEGIN
        -- Initialize
        reset <= '1';
        valid_in <= '0';

        -- Setup test object (blue sphere)
        test_obj.color.red   <= X"00000000";
        test_obj.color.green <= X"00000000";
        test_obj.color.blue  <= X"3F800000"; -- 1.0

        WAIT FOR 100 ns;
        reset <= '0';
        WAIT FOR 50 ns;

        -- Test Case 1: From Ep3Code test data
        -- ray.lab = (-0.100391, 1.000000, -0.004687)
        -- Expected vhat = (-0.099887, 0.994988, -0.004664)
        REPORT "Stage 1 Test: Normalizing ray direction vector";

        test_ray.lab.x    <= X"BDCD7B00"; -- -0.100391
        test_ray.lab.y    <= X"3F800000"; -- 1.0
        test_ray.lab.z    <= X"BB999000"; -- -0.004687

        test_ray.point1.x <= X"00000000"; -- 0.0
        test_ray.point1.y <= X"C1200000"; -- -10.0
        test_ray.point1.z <= X"00000000"; -- 0.0

        test_ray.point2.x <= X"BDCD7B00"; -- -0.100391
        test_ray.point2.y <= X"C1100000"; -- -9.0
        test_ray.point2.z <= X"BB999000"; -- -0.004687

        valid_in <= '1';
        WAIT FOR clk_period;
        --valid_in <= '0';

        -- Wait for result
        WAIT UNTIL valid_out = '1' FOR 20000 ns;

        IF valid_out = '1' THEN
            REPORT "Stage 1 COMPLETE";
            REPORT "Expected vhat: x=-0.099887 y=0.994988 z=-0.004664";
            REPORT "Check waveform for actual values";
        ELSE
            REPORT "Stage 1 TIMEOUT" SEVERITY ERROR;
        END IF;

        WAIT FOR 200 ns;

        -- End simulation
        REPORT "Stage 1 Test Complete";
        test_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;
