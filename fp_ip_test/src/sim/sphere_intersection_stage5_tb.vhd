LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;

ENTITY sphere_intersection_stage5_tb IS
END ENTITY;

ARCHITECTURE testbench OF sphere_intersection_stage5_tb IS
    COMPONENT sphere_intersection_stage5
        PORT (
            clk               : IN STD_LOGIC;
            reset             : IN STD_LOGIC;
            valid_in          : IN STD_LOGIC;
            does_intersect    : OUT STD_LOGIC;
            valid_out         : OUT STD_LOGIC;
            debug_inttest     : OUT fp32;
            debug_compare_res : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            debug_sqrt        : OUT fp32
        );
    END COMPONENT;

    SIGNAL clk, reset, valid_in, does_intersect, valid_out : STD_LOGIC := '0';
    SIGNAL debug_inttest, debug_sqrt : fp32;
    SIGNAL debug_compare_res : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL test_done : BOOLEAN := FALSE;
    CONSTANT clk_period : TIME := 10 ns;

BEGIN
    uut : sphere_intersection_stage5
        PORT MAP (clk => clk, reset => reset, valid_in => valid_in,
                  does_intersect => does_intersect, valid_out => valid_out,
                  debug_inttest => debug_inttest,
                  debug_compare_res => debug_compare_res,
                  debug_sqrt => debug_sqrt);

    PROCESS BEGIN
        WHILE NOT test_done LOOP clk <= NOT clk; WAIT FOR clk_period / 2; END LOOP; WAIT;
    END PROCESS;

    PROCESS BEGIN
        reset <= '1'; WAIT FOR 100 ns; reset <= '0'; WAIT FOR 50 ns;
        valid_in <= '1';
        WAIT UNTIL valid_out = '1' FOR 1000000 ns;
        IF valid_out = '1' THEN
            IF does_intersect = '1' THEN
                REPORT "Stage 5 COMPLETE - Intersection detected";
            ELSE
                REPORT "Stage 5 FAILED - No intersection" SEVERITY ERROR;
            END IF;
        ELSE
            REPORT "Stage 5 TIMEOUT" SEVERITY ERROR;
        END IF;
        WAIT FOR 200 ns; test_done <= TRUE; WAIT;
    END PROCESS;
END ARCHITECTURE;
