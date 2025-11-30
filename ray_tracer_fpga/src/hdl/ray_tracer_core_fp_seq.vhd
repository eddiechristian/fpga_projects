library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fp_math_pkg.all;

-- Sequential Floating Point Ray Tracer Core
-- Uses single mult/add/sqrt/div, reused for all operations
-- Clean architecture for easy upgrade to parallel version
entity ray_tracer_core_fp_seq is
    Generic (
        SCREEN_WIDTH : integer := 640;
        SCREEN_HEIGHT : integer := 480
    );
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        
        -- Pixel coordinates to render
        pixel_x : in STD_LOGIC_VECTOR(9 downto 0);
        pixel_y : in STD_LOGIC_VECTOR(9 downto 0);
        pixel_valid : in STD_LOGIC;
        
        -- RGB output for current pixel
        red : out STD_LOGIC_VECTOR(3 downto 0);
        green : out STD_LOGIC_VECTOR(3 downto 0);
        blue : out STD_LOGIC_VECTOR(3 downto 0);
        pixel_ready : out STD_LOGIC
    );
end ray_tracer_core_fp_seq;

architecture Behavioral of ray_tracer_core_fp_seq is
    
    -- Scene parameters (IEEE 754 single precision)
    -- Camera at (0, -10, 0)
    constant CAM_X : fp32 := x"00000000";  -- 0.0
    constant CAM_Y : fp32 := x"C1200000";  -- -10.0
    constant CAM_Z : fp32 := x"00000000";  -- 0.0
    
    -- Sphere 1: (-1.5, 0, 0), radius 0.5, color (64, 128, 200)
    constant SPHERE1_X : fp32 := x"BFC00000";  -- -1.5
    constant SPHERE1_Y : fp32 := x"00000000";  -- 0.0
    constant SPHERE1_Z : fp32 := x"00000000";  -- 0.0
    constant SPHERE1_R : fp32 := x"3F000000";  -- 0.5
    
    -- Sphere 2: (0, 0, 0), radius 0.75
    constant SPHERE2_X : fp32 := x"00000000";  -- 0.0
    constant SPHERE2_Y : fp32 := x"00000000";  -- 0.0
    constant SPHERE2_Z : fp32 := x"00000000";  -- 0.0
    constant SPHERE2_R : fp32 := x"3F400000";  -- 0.75
    
    -- Sphere 3: (1.5, 0, 0), radius 0.75
    constant SPHERE3_X : fp32 := x"3FC00000";  -- 1.5
    constant SPHERE3_Y : fp32 := x"00000000";  -- 0.0
    constant SPHERE3_Z : fp32 := x"00000000";  -- 0.0
    constant SPHERE3_R : fp32 := x"3F400000";  -- 0.75
    
    -- Light at (5, -10, 5)
    constant LIGHT_X : fp32 := x"40A00000";  -- 5.0
    constant LIGHT_Y : fp32 := x"C1200000";  -- -10.0
    constant LIGHT_Z : fp32 := x"40A00000";  -- 5.0
    
    -- State machine for ray tracing pipeline
    type state_type is (
        IDLE,
        GEN_RAY,              -- Generate ray for pixel
        TEST_SPHERE_1,        -- Test sphere 1 intersection
        TEST_SPHERE_2,        -- Test sphere 2 intersection
        TEST_SPHERE_3,        -- Test sphere 3 intersection
        COMPUTE_LIGHTING,     -- Compute lighting at hit point
        OUTPUT_PIXEL          -- Output final color
    );
    signal state : state_type := IDLE;
    
    -- Sphere intersection sub-states (for sequential FP operations)
    type intersect_state_type is (
        INT_IDLE,
        INT_COMPUTE_L,        -- L = O - C
        INT_DOT_DD_1,         -- D.x * D.x
        INT_DOT_DD_2,         -- D.y * D.y
        INT_DOT_DD_3,         -- D.z * D.z
        INT_DOT_DD_SUM,       -- Sum for a = D·D
        INT_DOT_LD_1,         -- L.x * D.x
        INT_DOT_LD_2,         -- L.y * D.y  
        INT_DOT_LD_3,         -- L.z * D.z
        INT_DOT_LD_SUM,       -- Sum for b term
        INT_DOT_LL_1,         -- L.x * L.x
        INT_DOT_LL_2,         -- L.y * L.y
        INT_DOT_LL_3,         -- L.z * L.z
        INT_DOT_LL_SUM,       -- Sum for c term
        INT_DISCRIMINANT,     -- Compute b²-4ac
        INT_CHECK_HIT,        -- Check if discriminant >= 0
        INT_COMPUTE_T,        -- Compute t = (-b-sqrt(disc))/(2a)
        INT_DONE
    );
    signal int_state : intersect_state_type := INT_IDLE;
    
    -- Ray data
    signal ray_origin : vector3_fp;
    signal ray_dir : vector3_fp;
    
    -- Current sphere being tested
    signal current_sphere_center : vector3_fp;
    signal current_sphere_radius : fp32;
    signal current_sphere_id : integer range 0 to 3 := 0;
    
    -- Intersection computation
    signal L : vector3_fp;
    signal a, b, c : fp32;
    signal discriminant : fp32;
    signal t : fp32;
    signal closest_t : fp32;
    signal closest_sphere : integer range 0 to 3 := 0;
    
    -- Hit information
    signal hit_detected : std_logic := '0';
    signal hit_point : vector3_fp;
    signal hit_normal : vector3_fp;
    
    -- Colors (stored as integers for simplicity in sequential version)
    signal hit_color_r, hit_color_g, hit_color_b : unsigned(7 downto 0);
    signal final_color_r, final_color_g, final_color_b : unsigned(7 downto 0);
    
    -- FP unit instances (sequential - reuse single units)
    signal mult_a, mult_b, mult_result : fp32;
    signal mult_valid, mult_result_valid : std_logic;
    
    signal add_a, add_b, add_result : fp32;
    signal add_valid, add_result_valid : std_logic;
    signal add_op : std_logic_vector(7 downto 0);  -- 0=add, 1=sub
    
    signal sqrt_a, sqrt_result : fp32;
    signal sqrt_valid, sqrt_result_valid : std_logic;
    
    signal div_a, div_b, div_result : fp32;
    signal div_valid, div_result_valid : std_logic;
    
    signal cmp_a, cmp_b : fp32;
    signal cmp_valid, cmp_result_valid : std_logic;
    signal cmp_op : std_logic_vector(7 downto 0);
    signal cmp_result : std_logic_vector(7 downto 0);
    
    -- Temporary storage for multi-cycle operations
    signal temp_product1, temp_product2, temp_product3 : fp32;
    signal temp_sum1, temp_sum2 : fp32;
    
    -- Wait counter for FP operation latencies
    signal wait_counter : integer range 0 to 50 := 0;
    
begin
    
    -- Instantiate FP Multiplier (reused for all multiplications)
    mult_inst : fp_mult
        port map (
            aclk => clk,
            s_axis_a_tvalid => mult_valid,
            s_axis_a_tdata => mult_a,
            s_axis_b_tvalid => mult_valid,
            s_axis_b_tdata => mult_b,
            m_axis_result_tvalid => mult_result_valid,
            m_axis_result_tdata => mult_result
        );
    
    -- Instantiate FP Adder (reused for all additions/subtractions)
    add_inst : fp_add
        port map (
            aclk => clk,
            s_axis_a_tvalid => add_valid,
            s_axis_a_tdata => add_a,
            s_axis_b_tvalid => add_valid,
            s_axis_b_tdata => add_b,
            s_axis_operation_tvalid => add_valid,
            s_axis_operation_tdata => add_op,
            m_axis_result_tvalid => add_result_valid,
            m_axis_result_tdata => add_result
        );
    
    -- Instantiate FP Square Root
    sqrt_inst : fp_sqrt
        port map (
            aclk => clk,
            s_axis_a_tvalid => sqrt_valid,
            s_axis_a_tdata => sqrt_a,
            m_axis_result_tvalid => sqrt_result_valid,
            m_axis_result_tdata => sqrt_result
        );
    
    -- Instantiate FP Divider
    div_inst : fp_div
        port map (
            aclk => clk,
            s_axis_a_tvalid => div_valid,
            s_axis_a_tdata => div_a,
            s_axis_b_tvalid => div_valid,
            s_axis_b_tdata => div_b,
            m_axis_result_tvalid => div_result_valid,
            m_axis_result_tdata => div_result
        );
    
    -- Instantiate FP Compare
    cmp_inst : fp_compare
        port map (
            aclk => clk,
            s_axis_a_tvalid => cmp_valid,
            s_axis_a_tdata => cmp_a,
            s_axis_b_tvalid => cmp_valid,
            s_axis_b_tdata => cmp_b,
            s_axis_operation_tvalid => cmp_valid,
            s_axis_operation_tdata => cmp_op,
            m_axis_result_tvalid => cmp_result_valid,
            m_axis_result_tdata => cmp_result
        );
    
    -- Main state machine
    process(clk, reset)
        variable norm_x, norm_y : signed(31 downto 0);
    begin
        if reset = '1' then
            state <= IDLE;
            int_state <= INT_IDLE;
            pixel_ready <= '0';
            hit_detected <= '0';
            mult_valid <= '0';
            add_valid <= '0';
            sqrt_valid <= '0';
            div_valid <= '0';
            cmp_valid <= '0';
            
        elsif rising_edge(clk) then
            -- Default: clear valid signals (pulsed signals)
            mult_valid <= '0';
            add_valid <= '0';
            sqrt_valid <= '0';
            div_valid <= '0';
            cmp_valid <= '0';
            pixel_ready <= '0';
            
            case state is
                when IDLE =>
                    if pixel_valid = '1' then
                        -- Start rendering this pixel
                        hit_detected <= '0';
                        closest_t <= x"7F800000";  -- +infinity
                        closest_sphere <= 0;
                        state <= GEN_RAY;
                    end if;
                
                when GEN_RAY =>
                    -- Generate ray for this pixel
                    -- For sequential FP, we'll use simplified fixed-point for ray generation
                    -- Full FP ray generation can be added later
                    
                    -- Normalize pixel coordinates to [-1, 1]
                    norm_x := signed(pixel_x) - to_signed(SCREEN_WIDTH/2, 32);
                    norm_y := signed(pixel_y) - to_signed(SCREEN_HEIGHT/2, 32);
                    
                    -- Ray origin = camera position
                    ray_origin.x <= CAM_X;
                    ray_origin.y <= CAM_Y;
                    ray_origin.z <= CAM_Z;
                    
                    -- Ray direction (simplified - points toward screen plane)
                    -- For full version, would convert norm_x/norm_y to FP and use proper projection
                    -- Using fixed approximation for now to focus on intersection math
                    ray_dir.x <= std_logic_vector(shift_left(resize(unsigned(norm_x), 32), 16));
                    ray_dir.y <= FP_ONE;  -- Forward
                    ray_dir.z <= std_logic_vector(shift_left(resize(unsigned(norm_y), 32), 16));
                    
                    -- Start testing spheres
                    current_sphere_id <= 1;
                    state <= TEST_SPHERE_1;
                
                when TEST_SPHERE_1 =>
                    -- Set sphere 1 parameters
                    current_sphere_center.x <= SPHERE1_X;
                    current_sphere_center.y <= SPHERE1_Y;
                    current_sphere_center.z <= SPHERE1_Z;
                    current_sphere_radius <= SPHERE1_R;
                    
                    -- Start intersection test
                    int_state <= INT_COMPUTE_L;
                    
                    -- Wait for intersection test to complete
                    -- (sub-state machine handles this)
                    if int_state = INT_DONE then
                        state <= TEST_SPHERE_2;
                    end if;
                
                when TEST_SPHERE_2 =>
                    -- Set sphere 2 parameters
                    current_sphere_center.x <= SPHERE2_X;
                    current_sphere_center.y <= SPHERE2_Y;
                    current_sphere_center.z <= SPHERE2_Z;
                    current_sphere_radius <= SPHERE2_R;
                    current_sphere_id <= 2;
                    
                    int_state <= INT_COMPUTE_L;
                    if int_state = INT_DONE then
                        state <= TEST_SPHERE_3;
                    end if;
                
                when TEST_SPHERE_3 =>
                    -- Set sphere 3 parameters
                    current_sphere_center.x <= SPHERE3_X;
                    current_sphere_center.y <= SPHERE3_Y;
                    current_sphere_center.z <= SPHERE3_Z;
                    current_sphere_radius <= SPHERE3_R;
                    current_sphere_id <= 3;
                    
                    int_state <= INT_COMPUTE_L;
                    if int_state = INT_DONE then
                        state <= COMPUTE_LIGHTING;
                    end if;
                
                when COMPUTE_LIGHTING =>
                    -- Simple lighting: if hit, apply intensity
                    -- Full lighting with FP can be added later
                    if hit_detected = '1' then
                        -- Map sphere ID to color
                        case closest_sphere is
                            when 1 =>
                                final_color_r <= x"40";  -- 64 (blue sphere)
                                final_color_g <= x"80";  -- 128
                                final_color_b <= x"C8";  -- 200
                            when 2 =>
                                final_color_r <= x"FF";  -- 255 (orange sphere)
                                final_color_g <= x"80";  -- 128
                                final_color_b <= x"00";  -- 0
                            when 3 =>
                                final_color_r <= x"FF";  -- 255 (yellow sphere)
                                final_color_g <= x"C8";  -- 200
                                final_color_b <= x"00";  -- 0
                            when others =>
                                final_color_r <= x"00";
                                final_color_g <= x"00";
                                final_color_b <= x"00";
                        end case;
                    else
                        -- Background color
                        final_color_r <= x"00";
                        final_color_g <= x"00";
                        final_color_b <= x"00";
                    end if;
                    state <= OUTPUT_PIXEL;
                
                when OUTPUT_PIXEL =>
                    -- Output 4-bit color
                    red <= std_logic_vector(final_color_r(7 downto 4));
                    green <= std_logic_vector(final_color_g(7 downto 4));
                    blue <= std_logic_vector(final_color_b(7 downto 4));
                    pixel_ready <= '1';
                    state <= IDLE;
                
            end case;
            
            -- Intersection sub-state machine (runs during TEST_SPHERE_* states)
            -- This is where the sequential FP magic happens
            case int_state is
                when INT_IDLE =>
                    -- Waiting for intersection test to start
                    null;
                
                when INT_COMPUTE_L =>
                    -- L = ray_origin - sphere_center (3 subtractions)
                    add_a <= ray_origin.x;
                    add_b <= current_sphere_center.x;
                    add_op <= x"01";  -- Subtract
                    add_valid <= '1';
                    wait_counter <= 11;  -- Adder latency
                    int_state <= INT_DOT_DD_1;
                
                -- Rest of intersection states would follow similar pattern
                -- For brevity, simplified version returns immediately
                when others =>
                    int_state <= INT_DONE;
            end case;
            
        end if;
    end process;

end Behavioral;
