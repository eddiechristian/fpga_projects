LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;

ENTITY sphere_intersection_stage4_tb IS
END ENTITY;

ARCHITECTURE testbench OF sphere_intersection_stage4_tb IS
    COMPONENT sphere_intersection_stage4
        PORT (
            clk             : IN STD_LOGIC;
            reset           : IN STD_LOGIC;
            valid_in        : IN STD_LOGIC;
            does_intersect  : OUT STD_LOGIC;
            valid_out       : OUT STD_LOGIC;
            debug_b_squared : OUT fp32;
            debug_4c        : OUT fp32;
            debug_inttest   : OUT fp32
        );
    END COMPONENT;

    SIGNAL clk, reset, valid_in, does_intersect, valid_out : STD_LOGIC := '0';
    SIGNAL debug_b_squared, debug_4c, debug_inttest : fp32;
    SIGNAL test_done : BOOLEAN := FALSE;
    CONSTANT clk_period : TIME := 10 ns;

BEGIN
    uut : sphere_intersection_stage4
        PORT MAP (clk => clk, reset => reset, valid_in => valid_in,
                  does_intersect => does_intersect, valid_out => valid_out,
                  debug_b_squared => debug_b_squared, debug_4c => debug_4c,
                  debug_inttest => debug_inttest);

    PROCESS BEGIN
        WHILE NOT test_done LOOP clk <= NOT clk; WAIT FOR clk_period / 2; END LOOP; WAIT;
    END PROCESS;

    PROCESS BEGIN
        reset <= '1'; WAIT FOR 100 ns; reset <= '0'; WAIT FOR 50 ns;
        REPORT "Stage 4 Test: Discriminant calculation b^2-4*c";
        REPORT "Expected: b^2=396.00018, 4c=396.0, inttest=0.000183";
        valid_in <= '1';
        WAIT UNTIL valid_out = '1' FOR 1000000 ns;
        IF valid_out = '1' THEN
            REPORT "Stage 4 COMPLETE - Check waveform for discriminant";
        ELSE
            REPORT "Stage 4 TIMEOUT" SEVERITY ERROR;
        END IF;
        WAIT FOR 200 ns; test_done <= TRUE; WAIT;
    END PROCESS;
END ARCHITECTURE;
