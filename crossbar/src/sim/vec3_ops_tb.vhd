library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

library work;
use work.lin_alg_pkg.all;
use work.crossbar_pkg.all;

entity vec3_ops_tb is
end entity vec3_ops_tb;

architecture testbench of vec3_ops_tb is
    
    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Test control
    signal test_running : boolean := true;
    
    -- Crossbar system
    signal locked : std_logic;
    
    -- Producer request/grant/result arrays (9 producers total: 3 for each op)
    signal dot_requests    : producer_dot_request_array_t := (others => init_producer_dot_request);
    signal dot4_requests   : producer_dot4_request_array_t := (others => init_producer_dot4_request);
    signal mult_requests   : producer_mult_request_array_t := (others => init_producer_mult_request);
    signal fma_requests    : producer_fma_request_array_t := (others => init_producer_fma_request);
    signal addsub_requests : producer_addsub_request_array_t := (others => init_producer_addsub_request);
    
    -- Separate request arrays for add and sub to avoid multiple drivers
    signal add_addsub_requests : producer_addsub_request_array_t := (others => init_producer_addsub_request);
    signal sub_addsub_requests : producer_addsub_request_array_t := (others => init_producer_addsub_request);
    
    signal prod_grants     : producer_grant_array_t;
    signal prod_results    : producer_result_array_t;
    
    -- Vec3 Scale signals (Producer IDs 0-2)
    signal scale_valid_in  : std_logic := '0';
    signal scale_v         : Vec3;
    signal scale_scalar    : fp32;
    signal scale_result    : Vec3;
    signal scale_valid_out : std_logic;
    
    -- Vec3 Add signals (Producer IDs 3-5)
    signal add_valid_in  : std_logic := '0';
    signal add_a         : Vec3;
    signal add_b         : Vec3;
    signal add_result    : Vec3;
    signal add_valid_out : std_logic;
    
    -- Vec3 Sub signals (Producer IDs 6-8)
    signal sub_valid_in  : std_logic := '0';
    signal sub_a         : Vec3;
    signal sub_b         : Vec3;
    signal sub_result    : Vec3;
    signal sub_valid_out : std_logic;
    
    -- Helper functions for float conversion
    function real_to_fp32(r : real) return std_logic_vector is
        variable result : std_logic_vector(31 downto 0);
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : integer;
        variable abs_r : real;
    begin
        if r = 0.0 then
            return X"00000000";
        end if;
        
        -- Simple conversion (not IEEE754 compliant, just for testing)
        abs_r := abs(r);
        if r < 0.0 then
            sign := '1';
        else
            sign := '0';
        end if;
        
        -- Scale and convert
        exponent := 127 + integer(floor(log2(abs_r)));
        mantissa := integer((abs_r / (2.0 ** real(exponent - 127)) - 1.0) * (2.0 ** 23));
        
        result(31) := sign;
        result(30 downto 23) := std_logic_vector(to_unsigned(exponent, 8));
        result(22 downto 0) := std_logic_vector(to_unsigned(mantissa mod (2**23), 23));
        
        return result;
    end function;
    
    function fp32_to_real(fp : std_logic_vector(31 downto 0)) return real is
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable result : real;
    begin
        if fp = X"00000000" then
            return 0.0;
        end if;
        
        sign := fp(31);
        exponent := to_integer(unsigned(fp(30 downto 23)));
        mantissa := 1.0 + real(to_integer(unsigned(fp(22 downto 0)))) / (2.0 ** 23);
        
        result := mantissa * (2.0 ** real(exponent - 127));
        
        if sign = '1' then
            result := -result;
        end if;
        
        return result;
    end function;
    
    procedure create_vec3(x, y, z : real; signal v : out Vec3) is
    begin
        v.x <= real_to_fp32(x);
        v.y <= real_to_fp32(y);
        v.z <= real_to_fp32(z);
    end procedure;
    
begin
    
    -- Combine addsub requests from multiple sources (OR together valid signals)
    -- Only one module should be active at a time per producer ID, but we need to combine them
    process(add_addsub_requests, sub_addsub_requests)
    begin
        for i in 0 to NUM_PRODUCERS-1 loop
            if add_addsub_requests(i).valid = '1' then
                addsub_requests(i) <= add_addsub_requests(i);
            elsif sub_addsub_requests(i).valid = '1' then
                addsub_requests(i) <= sub_addsub_requests(i);
            else
                addsub_requests(i) <= init_producer_addsub_request;
            end if;
        end loop;
    end process;
    
    -- Clock generation
    clk_process: process
    begin
        while test_running loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Crossbar system instantiation
    crossbar_inst : entity work.crossbar_fp_system
        port map (
            clk_100mhz      => clk,
            rst             => rst,
            locked          => locked,
            dot_requests    => dot_requests,
            dot4_requests   => dot4_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            prod_results    => prod_results
        );
    
    -- Vec3 Scale instantiation (uses producer IDs 0, 1, 2)
    scale_inst : entity work.vec3_scale_hw
        generic map (
            PRODUCER_ID_BASE => 0
        )
        port map (
            clk             => clk,
            reset           => rst,
            valid_in        => scale_valid_in,
            v               => scale_v,
            scalar          => scale_scalar,
            result          => scale_result,
            valid_out       => scale_valid_out,
            mult_requests   => mult_requests,
            mult_grants     => prod_grants,
            mult_results    => prod_results
        );
    
    -- Vec3 Add instantiation (uses producer IDs 3, 4, 5)
    add_inst : entity work.vec3_add_hw
        generic map (
            PRODUCER_ID_BASE => 3
        )
        port map (
            clk             => clk,
            reset           => rst,
            valid_in        => add_valid_in,
            a               => add_a,
            b               => add_b,
            result          => add_result,
            valid_out       => add_valid_out,
            addsub_requests => add_addsub_requests,
            addsub_grants   => prod_grants,
            addsub_results  => prod_results
        );
    
    -- Vec3 Sub instantiation (uses producer IDs 6, 7, 8)
    sub_inst : entity work.vec3_sub_hw
        generic map (
            PRODUCER_ID_BASE => 6
        )
        port map (
            clk             => clk,
            reset           => rst,
            valid_in        => sub_valid_in,
            a               => sub_a,
            b               => sub_b,
            result          => sub_result,
            valid_out       => sub_valid_out,
            addsub_requests => sub_addsub_requests,
            addsub_grants   => prod_grants,
            addsub_results  => prod_results
        );
    
    -- Debug process
    debug_add: process(clk)
    begin
        if rising_edge(clk) then
            if add_valid_in = '1' then
                report "DEBUG: add_valid_in asserted";
            end if;
            if add_valid_out = '1' then
                report "DEBUG: add_valid_out asserted";
            end if;
        end if;
    end process;
    
    -- Test stimulus
    stimulus: process
        variable result_x, result_y, result_z : real;
    begin
        -- Initial reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 50 ns;
        
        report "========================================";
        report "Starting Vec3 Operations Testbench";
        report "========================================";
        
        -- Test 1: Vec3 Scale
        report "Test 1: Vec3 Scale - v * scalar";
        create_vec3(1.0, 2.0, 3.0, scale_v);
        scale_scalar <= real_to_fp32(2.0);
        scale_valid_in <= '1';
        wait for CLK_PERIOD;
        scale_valid_in <= '0';
        
        -- Wait for result
        wait until scale_valid_out = '1';
        wait for CLK_PERIOD;
        
        result_x := fp32_to_real(scale_result.x);
        result_y := fp32_to_real(scale_result.y);
        result_z := fp32_to_real(scale_result.z);
        
        report "Scale result: (" & real'image(result_x) & ", " & 
               real'image(result_y) & ", " & real'image(result_z) & ")";
        report "Expected: (2.0, 4.0, 6.0)";
        
        assert abs(result_x - 2.0) < 0.01 report "Scale X mismatch!" severity error;
        assert abs(result_y - 4.0) < 0.01 report "Scale Y mismatch!" severity error;
        assert abs(result_z - 6.0) < 0.01 report "Scale Z mismatch!" severity error;
        
        wait for 100 ns;
        
        -- Test 2: Vec3 Add
        report "Test 2: Vec3 Add - a + b";
        create_vec3(1.0, 2.0, 3.0, add_a);
        create_vec3(4.0, 5.0, 6.0, add_b);
        add_valid_in <= '1';
        wait for CLK_PERIOD;
        add_valid_in <= '0';
        
        -- Wait for result
        wait until add_valid_out = '1';
        wait for CLK_PERIOD;
        
        result_x := fp32_to_real(add_result.x);
        result_y := fp32_to_real(add_result.y);
        result_z := fp32_to_real(add_result.z);
        
        report "Add result: (" & real'image(result_x) & ", " & 
               real'image(result_y) & ", " & real'image(result_z) & ")";
        report "Expected: (5.0, 7.0, 9.0)";
        
        assert abs(result_x - 5.0) < 0.01 report "Add X mismatch!" severity error;
        assert abs(result_y - 7.0) < 0.01 report "Add Y mismatch!" severity error;
        assert abs(result_z - 9.0) < 0.01 report "Add Z mismatch!" severity error;
        
        wait for 100 ns;
        
        -- Test 3: Vec3 Subtract
        report "Test 3: Vec3 Sub - a - b";
        create_vec3(10.0, 8.0, 6.0, sub_a);
        create_vec3(2.0, 3.0, 4.0, sub_b);
        sub_valid_in <= '1';
        wait for CLK_PERIOD;
        sub_valid_in <= '0';
        
        -- Wait for result
        wait until sub_valid_out = '1';
        wait for CLK_PERIOD;
        
        result_x := fp32_to_real(sub_result.x);
        result_y := fp32_to_real(sub_result.y);
        result_z := fp32_to_real(sub_result.z);
        
        report "Sub result: (" & real'image(result_x) & ", " & 
               real'image(result_y) & ", " & real'image(result_z) & ")";
        report "Expected: (8.0, 5.0, 2.0)";
        
        assert abs(result_x - 8.0) < 0.01 report "Sub X mismatch!" severity error;
        assert abs(result_y - 5.0) < 0.01 report "Sub Y mismatch!" severity error;
        assert abs(result_z - 2.0) < 0.01 report "Sub Z mismatch!" severity error;
        
        wait for 100 ns;
        
        report "========================================";
        report "All tests completed successfully!";
        report "========================================";
        
        test_running <= false;
        wait;
    end process;
    
end architecture testbench;
