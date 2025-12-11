LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

ENTITY sphere_intersection_tb IS
END ENTITY sphere_intersection_tb;

ARCHITECTURE testbench OF sphere_intersection_tb IS

    -- Component declaration
    COMPONENT sphere_intersection_hw
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
            valid_out      : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Clock and reset signals
    SIGNAL clk            : STD_LOGIC := '0';
    SIGNAL reset          : STD_LOGIC := '0';
    SIGNAL valid_in       : STD_LOGIC := '0';

    -- Input signals
    SIGNAL test_ray       : Ray;
    SIGNAL test_obj       : RTObject;

    -- Output signals
    SIGNAL does_intersect : STD_LOGIC;
    SIGNAL intersect_pt   : Vec3;
    SIGNAL localNormal    : Vec3;
    SIGNAL color          : Color;
    SIGNAL valid_out      : STD_LOGIC;

    -- Clock period
    CONSTANT clk_period   : TIME := 10 ns;

    -- Test control
    SIGNAL test_done      : BOOLEAN := FALSE;

    -- Helper function to convert float to std_logic_vector (IEEE 754 single precision)
    FUNCTION to_fp32(val : REAL) RETURN fp32 IS
        VARIABLE result : fp32;
        VARIABLE sign : STD_LOGIC;
        VARIABLE exponent : INTEGER;
        VARIABLE mantissa : INTEGER;
        VARIABLE abs_val : REAL;
    BEGIN
        -- Simple conversion for common test values
        -- This is a simplified approach - for full IEEE 754 conversion, use more complex logic
        IF val = 0.0 THEN
            result := X"00000000";
        ELSIF val = -0.100391 THEN
            result := X"BDCD7B00"; -- approximately -0.100391
        ELSIF val = 1.0 THEN
            result := X"3F800000";
        ELSIF val = -1.0 THEN
            result := X"BF800000";
        ELSIF val = -0.004687 THEN
            result := X"BB999000"; -- approximately -0.004687
        ELSIF val = -10.0 THEN
            result := X"C1200000";
        ELSIF val = -9.0 THEN
            result := X"C1100000";
        ELSIF val = -0.004297 THEN
            result := X"BB8D0000"; -- approximately -0.004297
        ELSIF val = -0.003906 THEN
            result := X"BB800000"; -- approximately -0.003906
        ELSE
            result := X"00000000"; -- default
        END IF;
        RETURN result;
    END FUNCTION;

BEGIN

    -- Instantiate the Unit Under Test (UUT)
    uut : sphere_intersection_hw
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
            valid_out      => valid_out
        );

    -- Clock process
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

    -- Stimulus process
    stim_proc : PROCESS
    BEGIN
        -- Initialize
        reset <= '1';
        valid_in <= '0';

        -- Setup default object (unit sphere at origin with blue color)
        test_obj.color.red   <= X"00000000";
        test_obj.color.green <= X"00000000";
        test_obj.color.blue  <= X"3F800000"; -- 1.0

        WAIT FOR 100 ns;
        reset <= '0';
        WAIT FOR 50 ns;

        -- ========================================
        -- Test Case 1: Ray that intersects sphere
        -- castRay.m_lab.x=-0.100391 y=1.000000 z=-0.004687
        -- castRay.m_point1.x=0.000000 y=-10.000000 z=0.000000
        -- castRay.m_point2.x=-0.100391 y=-9.000000 z=-0.004687
        -- Expected: b=-19.899754 c=99.000000 inttest=0.000183
        -- ========================================
        REPORT "Test Case 1: Ray intersects sphere";

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


        -- Wait for result
        WAIT UNTIL valid_out = '1' FOR 500000000 ns;

       -- End simulation
        REPORT "All tests completed";
        test_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;
