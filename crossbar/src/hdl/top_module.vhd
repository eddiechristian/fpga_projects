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
    SIGNAL prod_requests   : producer_request_array_t;
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
    SIGNAL mult_x_index    : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL mult_y_index    : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL mult_z_index    : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL add_index       : STD_LOGIC_VECTOR(5 DOWNTO 0);
BEGIN

    -- Pack scalar inputs into Vec3 records for internal use
    a_vec.x <= a_x;
    a_vec.y <= a_y;
    a_vec.z <= a_z;
    b_vec.x <= b_x;
    b_vec.y <= b_y;
    b_vec.z <= b_z;

    -- Initialize unused producer slots (producers 1-9)
    gen_unused_producers : FOR i IN 1 TO NUM_PRODUCERS - 1 GENERATE
        prod_requests(i) <= init_producer_request;
    END GENERATE;

    -- Instantiate the crossbar FP system
    crossbar_inst : ENTITY work.crossbar_fp_system
        PORT MAP(
            clk_100mhz    => clk,
            rst           => rst,
            locked        => locked,
            prod_requests => prod_requests,
            prod_grants   => prod_grants,
            prod_results  => prod_results
        );

    -- Instantiate dot product producer
    dot_product_inst : ENTITY work.dot_product
        GENERIC MAP(
            PRODUCER_ID => 0
        )
        PORT MAP(
            clk          => clk,
            rst          => rst,
            input_valid  => input_valid,
            a            => a_vec,
            b            => b_vec,
            mult_x_index => mult_x_index,
            mult_y_index => mult_y_index,
            mult_z_index => mult_z_index,
            add_index    => add_index,
            result       => dp_result,
            result_valid => dp_result_valid,
            request      => prod_requests(0),
            grant        => prod_grants(0),
            prod_result  => prod_results(0)
        );

    -- Output assignments
    result          <= dp_result;
    result_valid(0) <= dp_result_valid;
    mult_x_index    <= "000000";
    mult_y_index    <= "000001";
    mult_z_index    <= "000010";
    add_index       <= "000000";
END ARCHITECTURE structural;