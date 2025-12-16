library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;
use work.lin_alg_pkg.all;

-- Top-level module demonstrating dot product using crossbar
-- This module shows how to integrate a dot product producer with the
-- crossbar floating-point resource sharing system

entity top_module is
    port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- Control
        start : in std_logic;
        done  : out std_logic;
        
        -- Inputs: two 3D vectors (flattened for FPGA I/O)
        a_x, a_y, a_z : in std_logic_vector(31 downto 0);
        b_x, b_y, b_z : in std_logic_vector(31 downto 0);
        
        -- Output: dot product result
        result       : out std_logic_vector(31 downto 0);
        result_valid : out std_logic_vector(0 downto 0)  -- Single bit for LED/debug
    );
end entity top_module;

architecture structural of top_module is

    -- Crossbar signals (must match package size NUM_PRODUCERS=10)
    signal prod_requests : producer_request_array_t;
    signal prod_grants   : producer_grant_array_t;
    signal prod_results  : producer_result_array_t;
    
    -- Dot product producer signals
    signal dp_result       : std_logic_vector(31 downto 0);
    signal dp_result_valid : std_logic;
    signal dp_done         : std_logic;
    
    -- Crossbar status
    signal locked : std_logic;
    
    -- Pack input scalars into Vec3 records
    signal a_vec : Vec3;
    signal b_vec : Vec3;

begin

    -- Pack scalar inputs into Vec3 records for internal use
    a_vec.x <= a_x;
    a_vec.y <= a_y;
    a_vec.z <= a_z;
    b_vec.x <= b_x;
    b_vec.y <= b_y;
    b_vec.z <= b_z;

    -- Initialize unused producer slots (producers 1-9)
    gen_unused_producers: for i in 1 to NUM_PRODUCERS-1 generate
        prod_requests(i) <= init_producer_request;
    end generate;

    -- Instantiate the crossbar FP system
    crossbar_inst : entity work.crossbar_fp_system
        port map (
            clk_100mhz   => clk,
            rst          => rst,
            locked       => locked,
            prod_requests => prod_requests,
            prod_grants   => prod_grants,
            prod_results  => prod_results
        );
    
    -- Instantiate dot product producer
    dot_product_inst : entity work.dot_product
        generic map (
            PRODUCER_ID => 0
        )
        port map (
            clk          => clk,
            rst          => rst,
            start        => start,
            done         => dp_done,
            a            => a_vec,
            b            => b_vec,
            result       => dp_result,
            result_valid => dp_result_valid,
            request      => prod_requests(0),
            grant        => prod_grants(0),
            prod_result  => prod_results(0)
        );
    
    -- Output assignments
    done <= dp_done;
    result <= dp_result;
    result_valid(0) <= dp_result_valid;

end architecture structural;
