LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;

ENTITY sphere_intersection_stage3_tb IS
END ENTITY;

ARCHITECTURE testbench OF sphere_intersection_stage3_tb IS
    COMPONENT sphere_intersection_stage3
        PORT (
            clk            : IN STD_LOGIC;
            reset          : IN STD_LOGIC;
            valid_in       : IN STD_LOGIC;
            does_intersect : OUT STD_LOGIC;
            valid_out      : OUT STD_LOGIC;
            debug_b        : OUT fp32;
            debug_c        : OUT fp32
        );
    END COMPONENT;

    SIGNAL clk, reset, valid_in, does_intersect, valid_out : STD_LOGIC := '0';
    SIGNAL debug_b, debug_c : fp32;
    SIGNAL test_done : BOOLEAN := FALSE;
    CONSTANT clk_period : TIME := 10 ns;

BEGIN
    uut : sphere_intersection_stage3
        PORT MAP (clk => clk, reset => reset, valid_in => valid_in,
                  does_intersect => does_intersect, valid_out => valid_out,
                  debug_b => debug_b, debug_c => debug_c);

    PROCESS BEGIN
        WHILE NOT test_done LOOP clk <= NOT clk; WAIT FOR clk_period / 2; END LOOP; WAIT;
    END PROCESS;

    PROCESS BEGIN
        reset <= '1'; WAIT FOR 100 ns; reset <= '0'; WAIT FOR 50 ns;
        REPORT "Stage 3 Test: Calculating b=2.0*b_dot and c=c_dot-1.0";
        REPORT "Expected: b=-19.899754, c=99.0";
        valid_in <= '1';
        WAIT UNTIL valid_out = '1' FOR 50000000 ns;
        IF valid_out = '1' THEN
            REPORT "Stage 3 COMPLETE - Check waveform for b and c";
        ELSE
            REPORT "Stage 3 TIMEOUT" SEVERITY ERROR;
        END IF;
        WAIT FOR 200 ns; test_done <= TRUE; WAIT;
    END PROCESS;
END ARCHITECTURE;
