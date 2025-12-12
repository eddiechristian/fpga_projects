LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

ENTITY camera_tb IS
END ENTITY camera_tb;

ARCHITECTURE testbench OF camera_tb IS

    COMPONENT camera_hw
        PORT (
            clk             : IN STD_LOGIC;
            reset           : IN STD_LOGIC;

            -- Camera parameter inputs (for future updates)
            update_position : IN STD_LOGIC; -- Enable position update
            camera_val      : OUT Camera

        );
    END COMPONENT;

    -- Clock and control
    SIGNAL clk          : STD_LOGIC := '0';
    SIGNAL reset        : STD_LOGIC := '0';
    CONSTANT clk_period : TIME      := 10 ns;
    SIGNAL upd_pos      : STD_LOGIC := '0';
    SIGNAL test_done    : BOOLEAN   := FALSE;
    SIGNAL camera_value : Camera;
BEGIN

    uut : camera_hw
    PORT MAP(
        clk             => clk,
        reset           => reset,

        -- Camera parameter inputs (for future updates)
        update_position => upd_pos,
        camera_val      => camera_value

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
        reset    <= '1';
        upd_pos <= '1';
        WAIT FOR 100 ns;
        reset <= '0';
        WAIT FOR 50 ns;

        upd_pos <= '1';
        WAIT FOR clk_period;

        WAIT FOR 200 ns;

        test_done <= TRUE;
        WAIT;
    END PROCESS;

END ARCHITECTURE testbench;