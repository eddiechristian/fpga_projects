LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

-- Top-level module demonstrating dot product using crossbar
-- This module shows how to integrate a dot product producer with the
-- crossbar floating-point resource sharing system

ENTITY top_module IS
    PORT (
        clk           : IN STD_LOGIC;
        rst           : IN STD_LOGIC;

        -- Control
        input_valid   : IN STD_LOGIC;

        -- Inputs: two 3D vectors (flattened for FPGA I/O)
        a_x, a_y, a_z : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        b_x, b_y, b_z : IN STD_LOGIC_VECTOR(31 DOWNTO 0);

        -- Output: dot product result
        result        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        result_valid  : OUT STD_LOGIC_VECTOR(0 DOWNTO 0) -- Single bit for LED/debug
    );
END ENTITY top_module;

ARCHITECTURE structural OF top_module IS

    -- Crossbar signals (must match package size NUM_PRODUCERS=10)
    SIGNAL dot_requests    : producer_dot_request_array_t;
    SIGNAL mult_requests   : producer_mult_request_array_t;
    SIGNAL fma_requests    : producer_fma_request_array_t;
    SIGNAL addsub_requests : producer_addsub_request_array_t;
    SIGNAL prod_grants     : producer_grant_array_t;
    SIGNAL prod_results    : producer_result_array_t;

    -- Dot product producer signals
    SIGNAL dp_result       : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL dp_result_valid : STD_LOGIC;

    -- Crossbar status
    SIGNAL locked          : STD_LOGIC;

    -- Pack input scalars into Vec3 records
    SIGNAL a_vec           : Vec3;
    SIGNAL b_vec           : Vec3;
BEGIN

    -- Pack scalar inputs into Vec3 records for internal use
    a_vec.x <= a_x;
    a_vec.y <= a_y;
    a_vec.z <= a_z;
    b_vec.x <= b_x;
    b_vec.y <= b_y;
    b_vec.z <= b_z;

    -- Initialize unused producer slots (producers 1-9)
    gen_unused_dot : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        dot_requests(i) <= init_producer_dot_request;
    END GENERATE;

    gen_unused_mult : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        mult_requests(i) <= init_producer_mult_request;
    END GENERATE;

    gen_unused_fma : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        fma_requests(i) <= init_producer_fma_request;
    END GENERATE;

    gen_unused_addsub : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        addsub_requests(i) <= init_producer_addsub_request;
    END GENERATE;

    -- Simple DOT producer (producer 0)
    -- Generate DOT request when input_valid is asserted
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                dot_requests(0).valid <= '0';
                dot_requests(0).unit_index <= 0;
                dot_requests(0).tid <= (OTHERS => '0');
            ELSE
                IF input_valid = '1' THEN
                    dot_requests(0).valid <= '1';
                    dot_requests(0).unit_index <= 0;  -- Use DOT unit 0
                    dot_requests(0).a <= a_vec;
                    dot_requests(0).b <= b_vec;
                    dot_requests(0).tid <= X"0000";  -- Producer 0, operation 0
                    REPORT "TOP: DOT request issued - a_vec=" & 
                           INTEGER'image(to_integer(unsigned(a_vec.x(30 DOWNTO 23)))) & "," &
                           INTEGER'image(to_integer(unsigned(a_vec.y(30 DOWNTO 23)))) & "," &
                           INTEGER'image(to_integer(unsigned(a_vec.z(30 DOWNTO 23))));
                ELSE
                    dot_requests(0).valid <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Capture result from crossbar output router
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                dp_result <= (OTHERS => '0');
                dp_result_valid <= '0';
            ELSE
                -- Producer 0 results come from prod_results(0)
                IF prod_results(0).valid = '1' THEN
                    dp_result <= prod_results(0).data;
                    dp_result_valid <= '1';
                    REPORT "TOP: Result received! TID=" & INTEGER'image(to_integer(unsigned(prod_results(0).tid))) & 
                           " data=" & INTEGER'image(to_integer(unsigned(prod_results(0).data(30 DOWNTO 23))));
                ELSE
                    dp_result_valid <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    -- Instantiate the crossbar FP system
    crossbar_inst : ENTITY work.crossbar_fp_system
        PORT MAP(
            clk_100mhz      => clk,
            rst             => rst,
            locked          => locked,
            dot_requests    => dot_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            prod_results    => prod_results
        );
    
    -- Output assignments
    result          <= dp_result;
    result_valid(0) <= dp_result_valid;
END ARCHITECTURE structural;