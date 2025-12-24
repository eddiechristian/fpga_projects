library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

library work;
use work.lin_alg_pkg.all;
use work.ray_tracing_pkg.all;
use work.crossbar_pkg.all;

entity generate_ray_tb is
end entity generate_ray_tb;

architecture testbench of generate_ray_tb is
    
    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Test control
    signal test_running : boolean := true;
    
    -- Camera signals
    signal camera : Camera;
    signal update_position : std_logic := '0';
    
    -- DUT signals
    signal proScreenX : fp32;
    signal proScreenY : fp32;
    signal valid_in : std_logic := '0';
    signal ray_out : Ray;
    signal valid_out : std_logic;
    
    -- Crossbar signals (for vec3 operations inside generate_ray)
    signal dot_requests    : producer_dot_request_array_t := (others => init_producer_dot_request);
    signal dot4_requests   : producer_dot4_request_array_t := (others => init_producer_dot4_request);
    signal mult_requests   : producer_mult_request_array_t := (others => init_producer_mult_request);
    signal fma_requests    : producer_fma_request_array_t := (others => init_producer_fma_request);
    signal addsub_requests : producer_addsub_request_array_t := (others => init_producer_addsub_request);
    signal prod_grants     : producer_grant_array_t;
    signal prod_results    : producer_result_array_t;
    
    -- Separate request arrays for generate_ray
    signal genray_mult_requests   : producer_mult_request_array_t := (others => init_producer_mult_request);
    signal genray_addsub_requests : producer_addsub_request_array_t := (others => init_producer_addsub_request);
    
    -- Expected values for comparison (must be signals for create_vec3 procedure)
    signal expected_point1 : Vec3;
    signal expected_point2 : Vec3;
    
    -- Test parameters from gen_ray.txt
    constant X_SIZE : integer := 640;
    constant Y_SIZE : integer := 480;
    constant X_FACT : real := 0.003125;
    constant Y_FACT : real := 0.004167;
    
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
        
        abs_r := abs(r);
        if r < 0.0 then
            sign := '1';
        else
            sign := '0';
        end if;
        
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
    
    function vec3_to_string(v : Vec3) return string is
    begin
        return "(" & real'image(fp32_to_real(v.x)) & ", " & 
               real'image(fp32_to_real(v.y)) & ", " & 
               real'image(fp32_to_real(v.z)) & ")";
    end function;
    
    function compare_vec3(a, b : Vec3; tolerance : real) return boolean is
    begin
        return (abs(fp32_to_real(a.x) - fp32_to_real(b.x)) < tolerance) and
               (abs(fp32_to_real(a.y) - fp32_to_real(b.y)) < tolerance) and
               (abs(fp32_to_real(a.z) - fp32_to_real(b.z)) < tolerance);
    end function;
    
begin
    
    -- Combine mult requests (generate_ray uses IDs 0-1 for scale ops)
    process(genray_mult_requests)
    begin
        for i in 0 to NUM_PRODUCERS-1 loop
            if genray_mult_requests(i).valid = '1' then
                mult_requests(i) <= genray_mult_requests(i);
            else
                mult_requests(i) <= init_producer_mult_request;
            end if;
        end loop;
    end process;
    
    -- Combine addsub requests (generate_ray uses IDs 2-4 for add/sub ops)
    process(genray_addsub_requests)
    begin
        for i in 0 to NUM_PRODUCERS-1 loop
            if genray_addsub_requests(i).valid = '1' then
                addsub_requests(i) <= genray_addsub_requests(i);
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
    
    -- Camera instantiation
    camera_inst : entity work.camera_hw
        port map (
            clk             => clk,
            reset           => rst,
            update_position => update_position,
            camera_val      => camera
        );
    
    -- Crossbar system instantiation
    crossbar_inst : entity work.crossbar_fp_system
        port map (
            clk_100mhz      => clk,
            rst             => rst,
            locked          => open,
            dot_requests    => dot_requests,
            dot4_requests   => dot4_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            prod_results    => prod_results
        );
    
    -- DUT instantiation
    dut : entity work.generate_ray
        generic map (
            PRODUCER_ID_BASE => 0
        )
        port map (
            clk             => clk,
            reset           => rst,
            proScreenX      => proScreenX,
            proScreenY      => proScreenY,
            valid_in        => valid_in,
            camera_in       => camera,
            ray             => ray_out,
            valid_out       => valid_out,
            mult_requests   => genray_mult_requests,
            mult_grants     => prod_grants,
            mult_results    => prod_results,
            addsub_requests => genray_addsub_requests,
            addsub_grants   => prod_grants,
            addsub_results  => prod_results
        );
    
    -- Test stimulus
    stimulus: process
        variable pixel_x : integer;
        variable pixel_y : integer;
        variable proScreenX_val : real;
        variable proScreenY_val : real;
    begin
        -- Initial reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 50 ns;
        
        report "========================================";
        report "Starting Generate Ray Testbench";
        report "========================================";
        report "Test parameters:";
        report "  Screen size: " & integer'image(X_SIZE) & "x" & integer'image(Y_SIZE);
        report "  xFact: " & real'image(X_FACT);
        report "  yFact: " & real'image(Y_FACT);
        
        -- Wait for camera to initialize
        wait for 100 ns;
        
        report "Camera parameters:";
        report "  Position: " & vec3_to_string(camera.position);
        report "  LookAt: " & vec3_to_string(camera.lookat);
        report "  Up: " & vec3_to_string(camera.up);
        report "  Screen Centre: " & vec3_to_string(camera.screen_centre);
        report "  Screen U: " & vec3_to_string(camera.screen_u);
        report "  Screen V: " & vec3_to_string(camera.screen_v);
        
        -- Test cases from gen_ray.txt
        -- Test 1: x=0, y=0
        report "========================================";
        report "Test 1: Pixel (0, 0)";
        pixel_x := 0;
        pixel_y := 0;
        proScreenX_val := (real(pixel_x) * X_FACT) - 1.0;
        proScreenY_val := (real(pixel_y) * Y_FACT) - 1.0;
        
        proScreenX <= real_to_fp32(proScreenX_val);
        proScreenY <= real_to_fp32(proScreenY_val);
        
        -- Expected values from gen_ray.txt
        create_vec3(0.0, -10.0, 0.0, expected_point1);
        create_vec3(-0.2500, -9.0000, -0.1406, expected_point2);
        
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        
        -- Wait for result
        wait until valid_out = '1' for 10 us;
        
        if valid_out = '1' then
            report "  Result point1: " & vec3_to_string(ray_out.point1);
            report "  Expected:      " & vec3_to_string(expected_point1);
            report "  Result point2: " & vec3_to_string(ray_out.point2);
            report "  Expected:      " & vec3_to_string(expected_point2);
            report "  Result lab:    " & vec3_to_string(ray_out.lab);
            
            assert compare_vec3(ray_out.point1, expected_point1, 0.01)
                report "Test 1 FAILED: point1 mismatch!" severity error;
            assert compare_vec3(ray_out.point2, expected_point2, 0.01)
                report "Test 1 FAILED: point2 mismatch!" severity error;
            
            if compare_vec3(ray_out.point1, expected_point1, 0.01) and 
               compare_vec3(ray_out.point2, expected_point2, 0.01) then
                report "Test 1 PASSED";
            end if;
        else
            report "Test 1 FAILED: Timeout waiting for valid_out" severity error;
        end if;
        
        wait for 200 ns;
        
        -- Test 2: x=100, y=180
        report "========================================";
        report "Test 2: Pixel (100, 180)";
        pixel_x := 100;
        pixel_y := 180;
        proScreenX_val := (real(pixel_x) * X_FACT) - 1.0;
        proScreenY_val := (real(pixel_y) * Y_FACT) - 1.0;
        
        proScreenX <= real_to_fp32(proScreenX_val);
        proScreenY <= real_to_fp32(proScreenY_val);
        
        create_vec3(0.0, -10.0, 0.0, expected_point1);
        create_vec3(-0.1719, -9.0000, -0.0352, expected_point2);
        
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        
        wait until valid_out = '1' for 10 us;
        
        if valid_out = '1' then
            report "  Result point2: " & vec3_to_string(ray_out.point2);
            report "  Expected:      " & vec3_to_string(expected_point2);
            
            assert compare_vec3(ray_out.point2, expected_point2, 0.01)
                report "Test 2 FAILED: point2 mismatch!" severity error;
                
            if compare_vec3(ray_out.point2, expected_point2, 0.01) then
                report "Test 2 PASSED";
            end if;
        else
            report "Test 2 FAILED: Timeout" severity error;
        end if;
        
        wait for 200 ns;
        
        -- Test 3: x=300, y=360
        report "========================================";
        report "Test 3: Pixel (300, 360)";
        pixel_x := 300;
        pixel_y := 360;
        proScreenX_val := (real(pixel_x) * X_FACT) - 1.0;
        proScreenY_val := (real(pixel_y) * Y_FACT) - 1.0;
        
        proScreenX <= real_to_fp32(proScreenX_val);
        proScreenY <= real_to_fp32(proScreenY_val);
        
        create_vec3(0.0, -10.0, 0.0, expected_point1);
        create_vec3(-0.0156, -9.0000, 0.0703, expected_point2);
        
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        
        wait until valid_out = '1' for 10 us;
        
        if valid_out = '1' then
            report "  Result point2: " & vec3_to_string(ray_out.point2);
            report "  Expected:      " & vec3_to_string(expected_point2);
            
            if compare_vec3(ray_out.point2, expected_point2, 0.01) then
                report "Test 3 PASSED";
            else
                report "Test 3 FAILED: point2 mismatch!" severity error;
            end if;
        else
            report "Test 3 FAILED: Timeout" severity error;
        end if;
        
        wait for 200 ns;
        
        -- Test 4: x=500, y=0
        report "========================================";
        report "Test 4: Pixel (500, 0)";
        pixel_x := 500;
        pixel_y := 0;
        proScreenX_val := (real(pixel_x) * X_FACT) - 1.0;
        proScreenY_val := (real(pixel_y) * Y_FACT) - 1.0;
        
        proScreenX <= real_to_fp32(proScreenX_val);
        proScreenY <= real_to_fp32(proScreenY_val);
        
        create_vec3(0.0, -10.0, 0.0, expected_point1);
        create_vec3(0.1406, -9.0000, -0.1406, expected_point2);
        
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        
        wait until valid_out = '1' for 10 us;
        
        if valid_out = '1' then
            report "  Result point2: " & vec3_to_string(ray_out.point2);
            report "  Expected:      " & vec3_to_string(expected_point2);
            
            if compare_vec3(ray_out.point2, expected_point2, 0.01) then
                report "Test 4 PASSED";
            else
                report "Test 4 FAILED: point2 mismatch!" severity error;
            end if;
        else
            report "Test 4 FAILED: Timeout" severity error;
        end if;
        
        wait for 200 ns;
        
        -- Test 5: x=600, y=360
        report "========================================";
        report "Test 5: Pixel (600, 360)";
        pixel_x := 600;
        pixel_y := 360;
        proScreenX_val := (real(pixel_x) * X_FACT) - 1.0;
        proScreenY_val := (real(pixel_y) * Y_FACT) - 1.0;
        
        proScreenX <= real_to_fp32(proScreenX_val);
        proScreenY <= real_to_fp32(proScreenY_val);
        
        create_vec3(0.0, -10.0, 0.0, expected_point1);
        create_vec3(0.2188, -9.0000, 0.0703, expected_point2);
        
        valid_in <= '1';
        wait for CLK_PERIOD;
        valid_in <= '0';
        
        wait until valid_out = '1' for 10 us;
        
        if valid_out = '1' then
            report "  Result point2: " & vec3_to_string(ray_out.point2);
            report "  Expected:      " & vec3_to_string(expected_point2);
            
            if compare_vec3(ray_out.point2, expected_point2, 0.01) then
                report "Test 5 PASSED";
            else
                report "Test 5 FAILED: point2 mismatch!" severity error;
            end if;
        else
            report "Test 5 FAILED: Timeout" severity error;
        end if;
        
        wait for 200 ns;
        
        report "========================================";
        report "Generate Ray Testbench Complete";
        report "========================================";
        
        test_running <= false;
        wait;
    end process;
    
end architecture testbench;
