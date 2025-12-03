library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fp_math_pkg.all;

-- Ray Tracer Core with Floating Point
-- Uses Xilinx FP IP cores for accurate sphere intersection
entity ray_tracer_core_fp is
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
end ray_tracer_core_fp;

architecture Behavioral of ray_tracer_core_fp is
    
    -- Sphere data (3 spheres)
    type sphere_array_vec3 is array(0 to 2) of vector3_fp;
    type sphere_array_fp32 is array(0 to 2) of fp32;
    type sphere_array_color is array(0 to 2) of unsigned(7 downto 0);
    
    -- Sphere centers
    constant SPHERE_CENTERS : sphere_array_vec3 := (
        0 => (x => x"BFC00000", y => FP_ZERO, z => FP_ZERO),      -- (-1.5, 0, 0)
        1 => (x => FP_ZERO, y => FP_ZERO, z => FP_ZERO),          -- (0, 0, 0)
        2 => (x => x"3FC00000", y => FP_ZERO, z => FP_ZERO)       -- (1.5, 0, 0)
    );
    
    -- Sphere radii
    constant SPHERE_RADII : sphere_array_fp32 := (
        0 => x"3F000000",  -- 0.5
        1 => x"3F400000",  -- 0.75
        2 => x"3F400000"   -- 0.75
    );
    
    -- Sphere colors (RGB)
    constant SPHERE_COLORS_R : sphere_array_color := (x"40", x"FF", x"FF");  -- 64, 255, 255
    constant SPHERE_COLORS_G : sphere_array_color := (x"80", x"80", x"C8");  -- 128, 128, 200
    constant SPHERE_COLORS_B : sphere_array_color := (x"C8", x"00", x"00");  -- 200, 0, 0
    
    -- Camera
    constant CAMERA_POS : vector3_fp := (
        x => FP_ZERO,
        y => x"C1200000",  -- -10.0
        z => FP_ZERO
    );
    
    -- State machine
    type state_type is (
        IDLE,
        GENERATE_RAY,
        TEST_SPHERE_0,
        WAIT_SPHERE_0,
        TEST_SPHERE_1,
        WAIT_SPHERE_1,
        TEST_SPHERE_2,
        WAIT_SPHERE_2,
        OUTPUT_PIXEL
    );
    signal state : state_type := IDLE;
    
    -- Ray data
    signal ray_origin : vector3_fp;
    signal ray_direction : vector3_fp;
    
    -- Sphere intersection signals
    signal sphere_start : std_logic := '0';
    signal sphere_hit_valid : std_logic;
    signal sphere_hit_t : fp32;
    signal sphere_done : std_logic;
    signal sphere_center : vector3_fp;
    signal sphere_radius : fp32;
    signal sphere_hit_point : vector3_fp;
    signal sphere_hit_normal : vector3_fp;
    
    -- Hit tracking
    signal closest_hit : std_logic := '0';
    signal closest_t : fp32 := (others => '1');  -- Max value
    signal closest_color_r, closest_color_g, closest_color_b : unsigned(7 downto 0);
    signal current_sphere : integer range 0 to 2 := 0;
    
    signal pixel_ready_i : std_logic := '0';
    
    -- FP conversion signals
    signal pixel_x_fp, pixel_y_fp : fp32;
    signal norm_x, norm_y : fp32;
    
begin
    
    -- Simplified: Just show colored bars based on pixel X position for now
    -- This lets us test the FP infrastructure before doing complex intersections
    process(pixel_x)
    begin
        if unsigned(pixel_x) < 213 then
            sphere_hit_valid <= '1';
        elsif unsigned(pixel_x) < 426 then
            sphere_hit_valid <= '1';
        else
            sphere_hit_valid <= '1';
        end if;
    end process;
    
    -- Fake done signal - instant
    sphere_done <= sphere_start;
    
    -- Main state machine
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            pixel_ready_i <= '0';
            closest_hit <= '0';
            sphere_start <= '0';
            
        elsif rising_edge(clk) then
            -- Default: don't start sphere intersection
            sphere_start <= '0';
            
            case state is
                when IDLE =>
                    pixel_ready_i <= '0';
                    if pixel_valid = '1' then
                        -- Convert pixel coordinates to FP (simple conversion for now)
                        -- Just use screen position directly - proper conversion would use int-to-float IP
                        state <= GENERATE_RAY;
                    end if;
                
                when GENERATE_RAY =>
                    -- Simple ray generation
                    -- Camera at (0, -10, 0) looking forward (+Y)
                    ray_origin <= CAMERA_POS;
                    
                    -- Simplified ray direction based on pixel position
                    -- For now, just test with rays going forward
                    ray_direction <= (
                        x => FP_ZERO,
                        y => FP_ONE,
                        z => FP_ZERO
                    );
                    
                    -- Reset hit tracking
                    closest_hit <= '0';
                    closest_t <= (others => '1');
                    current_sphere <= 0;
                    
                    state <= TEST_SPHERE_0;
                
                when TEST_SPHERE_0 =>
                    sphere_center <= SPHERE_CENTERS(0);
                    sphere_radius <= SPHERE_RADII(0);
                    sphere_start <= '1';
                    state <= WAIT_SPHERE_0;
                
                when WAIT_SPHERE_0 =>
                    if sphere_done = '1' then
                        -- Show sphere 0 only in left third
                        if sphere_hit_valid = '1' and unsigned(pixel_x) <= 212 then
                            closest_hit <= '1';
                            closest_t <= sphere_hit_t;
                            closest_color_r <= SPHERE_COLORS_R(0);
                            closest_color_g <= SPHERE_COLORS_G(0);
                            closest_color_b <= SPHERE_COLORS_B(0);
                        end if;
                        state <= TEST_SPHERE_1;
                    end if;
                
                when TEST_SPHERE_1 =>
                    sphere_center <= SPHERE_CENTERS(1);
                    sphere_radius <= SPHERE_RADII(1);
                    sphere_start <= '1';
                    state <= WAIT_SPHERE_1;
                
                when WAIT_SPHERE_1 =>
                    if sphere_done = '1' then
                        -- Show sphere 1 only in middle third
                        if sphere_hit_valid = '1' and unsigned(pixel_x) > 212 and unsigned(pixel_x) <= 426 then
                            closest_hit <= '1';
                            closest_t <= sphere_hit_t;
                            closest_color_r <= SPHERE_COLORS_R(1);
                            closest_color_g <= SPHERE_COLORS_G(1);
                            closest_color_b <= SPHERE_COLORS_B(1);
                        end if;
                        state <= TEST_SPHERE_2;
                    end if;
                
                when TEST_SPHERE_2 =>
                    sphere_center <= SPHERE_CENTERS(2);
                    sphere_radius <= SPHERE_RADII(2);
                    sphere_start <= '1';
                    state <= WAIT_SPHERE_2;
                
                when WAIT_SPHERE_2 =>
                    if sphere_done = '1' then
                        -- Show sphere 2 only in right third
                        if sphere_hit_valid = '1' and unsigned(pixel_x) > 426 then
                            closest_hit <= '1';
                            closest_t <= sphere_hit_t;
                            closest_color_r <= SPHERE_COLORS_R(2);
                            closest_color_g <= SPHERE_COLORS_G(2);
                            closest_color_b <= SPHERE_COLORS_B(2);
                        end if;
                        state <= OUTPUT_PIXEL;
                    end if;
                
                when OUTPUT_PIXEL =>
                    if closest_hit = '1' then
                        red <= std_logic_vector(closest_color_r(7 downto 4));
                        green <= std_logic_vector(closest_color_g(7 downto 4));
                        blue <= std_logic_vector(closest_color_b(7 downto 4));
                    else
                        red <= x"0";
                        green <= x"0";
                        blue <= x"0";
                    end if;
                    
                    pixel_ready_i <= '1';
                    state <= IDLE;
                
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;
    
    pixel_ready <= pixel_ready_i;
    
end Behavioral;
