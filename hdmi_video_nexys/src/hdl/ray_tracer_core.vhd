library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Ray Tracer Core
-- Implements a simple ray tracer with sphere intersection and lighting
-- Uses fixed-point arithmetic (16.16 format) for hardware efficiency
entity ray_tracer_core is
    Generic (
        SCREEN_WIDTH : integer := 640;  -- Full VGA resolution
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
end ray_tracer_core;

architecture Behavioral of ray_tracer_core is
    -- Fixed point format: 16.16 (16 integer bits, 16 fractional bits)
    constant FIXED_POINT_SHIFT : integer := 16;
    constant ONE_FP : signed(31 downto 0) := x"00010000";  -- 1.0 in fixed point
    
    -- Camera parameters (fixed point)
    constant CAMERA_POS_X : signed(31 downto 0) := x"00000000";  -- 0.0
    constant CAMERA_POS_Y : signed(31 downto 0) := x"FFF60000";  -- -10.0
    constant CAMERA_POS_Z : signed(31 downto 0) := x"00000000";  -- 0.0
    
    -- Sphere parameters (3 spheres like C++ version)
    type sphere_array is array(0 to 2) of signed(31 downto 0);
    
    -- Sphere 1: position (-1.5, 0, 0), radius 0.5, color (64, 128, 200)
    constant SPHERE1_X : signed(31 downto 0) := x"FFFE8000";  -- -1.5
    constant SPHERE1_Y : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE1_Z : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE1_R : signed(31 downto 0) := x"00008000";  -- 0.5
    constant SPHERE1_COLOR_R : unsigned(7 downto 0) := x"40"; -- 64
    constant SPHERE1_COLOR_G : unsigned(7 downto 0) := x"80"; -- 128
    constant SPHERE1_COLOR_B : unsigned(7 downto 0) := x"C8"; -- 200
    
    -- Sphere 2: position (0, 0, 0), radius 0.75, color (255, 128, 0)
    constant SPHERE2_X : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE2_Y : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE2_Z : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE2_R : signed(31 downto 0) := x"0000C000";  -- 0.75
    constant SPHERE2_COLOR_R : unsigned(7 downto 0) := x"FF"; -- 255
    constant SPHERE2_COLOR_G : unsigned(7 downto 0) := x"80"; -- 128
    constant SPHERE2_COLOR_B : unsigned(7 downto 0) := x"00"; -- 0
    
    -- Sphere 3: position (1.5, 0, 0), radius 0.75, color (255, 200, 0)
    constant SPHERE3_X : signed(31 downto 0) := x"00018000";  -- 1.5
    constant SPHERE3_Y : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE3_Z : signed(31 downto 0) := x"00000000";  -- 0.0
    constant SPHERE3_R : signed(31 downto 0) := x"0000C000";  -- 0.75
    constant SPHERE3_COLOR_R : unsigned(7 downto 0) := x"FF"; -- 255
    constant SPHERE3_COLOR_G : unsigned(7 downto 0) := x"C8"; -- 200
    constant SPHERE3_COLOR_B : unsigned(7 downto 0) := x"00"; -- 0
    
    -- Light position (5, -10, 5)
    constant LIGHT_X : signed(31 downto 0) := x"00050000";  -- 5.0
    constant LIGHT_Y : signed(31 downto 0) := x"FFF60000";  -- -10.0
    constant LIGHT_Z : signed(31 downto 0) := x"00050000";  -- 5.0
    
    -- State machine
    type state_type is (IDLE, GENERATE_RAY, TEST_SPHERE1, TEST_SPHERE2, TEST_SPHERE3, 
                       COMPUTE_LIGHTING, OUTPUT_PIXEL);
    signal state : state_type := IDLE;
    
    -- Ray data
    signal ray_origin_x, ray_origin_y, ray_origin_z : signed(31 downto 0);
    signal ray_dir_x, ray_dir_y, ray_dir_z : signed(31 downto 0);
    
    -- Intersection results
    signal hit_detected : std_logic := '0';
    signal hit_distance : signed(31 downto 0);
    signal hit_point_x, hit_point_y, hit_point_z : signed(31 downto 0);
    signal hit_normal_x, hit_normal_y, hit_normal_z : signed(31 downto 0);
    signal hit_color_r, hit_color_g, hit_color_b : unsigned(7 downto 0);
    
    -- Lighting
    signal light_intensity : unsigned(7 downto 0);
    
    -- Output registers
    signal pixel_ready_i : std_logic := '0';
    
begin
    
    process(clk, reset)
        variable norm_x, norm_y : signed(31 downto 0);
        variable screen_x, screen_y : signed(31 downto 0);
        variable temp_mul : signed(63 downto 0);
        variable temp_div : signed(63 downto 0);
        variable sphere_hit : std_logic;
        variable t_hit : signed(31 downto 0);
        -- Sphere intersection variables
        variable oc_x, oc_y, oc_z : signed(31 downto 0);
        variable a, b, c : signed(63 downto 0);
        variable discriminant : signed(63 downto 0);
        variable t : signed(31 downto 0);
        variable temp_prod : signed(63 downto 0);
        variable temp_prod_128 : signed(127 downto 0);
    begin
        if reset = '1' then
            state <= IDLE;
            pixel_ready_i <= '0';
            hit_detected <= '0';
            red <= (others => '0');
            green <= (others => '0');
            blue <= (others => '0');
            
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    pixel_ready_i <= '0';
                    if pixel_valid = '1' then
                        state <= GENERATE_RAY;
                    end if;
                
                when GENERATE_RAY =>
                    -- Convert pixel coordinates to normalized screen space [-1, 1]
                    temp_mul := resize(signed(pixel_x), 32) * ONE_FP;
                    temp_div := temp_mul / to_signed(SCREEN_WIDTH, 32);
                    norm_x := temp_div(31 downto 0);
                    norm_x := resize((norm_x * 2), 32) - ONE_FP;
                    
                    temp_mul := resize(signed(pixel_y), 32) * ONE_FP;
                    temp_div := temp_mul / to_signed(SCREEN_HEIGHT, 32);
                    norm_y := temp_div(31 downto 0);
                    norm_y := resize((norm_y * 2), 32) - ONE_FP;
                    
                    -- Simple camera: rays emanate from camera position
                    ray_origin_x <= CAMERA_POS_X;
                    ray_origin_y <= CAMERA_POS_Y;
                    ray_origin_z <= CAMERA_POS_Z;
                    
                    -- Ray direction: toward screen position
                    ray_dir_x <= norm_x(31 downto 2) & "00";  -- * 0.25
                    ray_dir_y <= ONE_FP;  -- Forward direction
                    ray_dir_z <= norm_y(31 downto 2) & "00";  -- * 0.25
                    
                    hit_detected <= '0';
                    hit_distance <= x"7FFFFFFF";  -- Max distance
                    state <= TEST_SPHERE1;
                
                when TEST_SPHERE1 =>
                    -- Sphere intersection: solve |origin + t*dir - center|^2 = radius^2
                    -- Vector from ray origin to sphere center
                    oc_x := ray_origin_x - SPHERE1_X;
                    oc_y := ray_origin_y - SPHERE1_Y;
                    oc_z := ray_origin_z - SPHERE1_Z;
                    
                    -- Quadratic coefficients (simplified)
                    -- a = dot(dir, dir) ≈ 1 for normalized rays
                    -- b = 2 * dot(oc, dir)
                    -- c = dot(oc, oc) - radius^2
                    
                    -- b = 2 * dot(oc, dir) (fixed point multiply and shift)
                    b := (oc_x * ray_dir_x) + (oc_y * ray_dir_y) + (oc_z * ray_dir_z);
                    b := shift_right(b, 14);  -- Divide by 2^15 then multiply by 2
                    
                    -- c = dot(oc, oc) - radius^2
                    c := (oc_x * oc_x) + (oc_y * oc_y) + (oc_z * oc_z);
                    c := shift_right(c, 16);  -- Fixed point adjustment
                    temp_prod := SPHERE1_R * SPHERE1_R;
                    c := c - shift_right(temp_prod, 16);
                    
                    -- discriminant = b^2 - 4ac (a ≈ 1)
                    temp_prod_128 := b * b;
                    discriminant := shift_right(temp_prod_128, 16)(63 downto 0) - shift_left(c, 2);
                    
                    -- Check if we hit (discriminant >= 0 and t > 0)
                    if discriminant >= 0 and b < 0 then
                        -- Approximate t = -b (simplified, no sqrt yet)
                        t := -b(31 downto 0);
                        
                        if t > 0 and t < hit_distance then
                            hit_detected <= '1';
                            hit_distance <= t;
                            hit_color_r <= SPHERE1_COLOR_R;
                            hit_color_g <= SPHERE1_COLOR_G;
                            hit_color_b <= SPHERE1_COLOR_B;
                        end if;
                    end if;
                    
                    state <= TEST_SPHERE2;
                
                when TEST_SPHERE2 =>
                    -- Sphere 2 intersection test
                    oc_x := ray_origin_x - SPHERE2_X;
                    oc_y := ray_origin_y - SPHERE2_Y;
                    oc_z := ray_origin_z - SPHERE2_Z;
                    
                    b := (oc_x * ray_dir_x) + (oc_y * ray_dir_y) + (oc_z * ray_dir_z);
                    b := shift_right(b, 14);
                    
                    c := (oc_x * oc_x) + (oc_y * oc_y) + (oc_z * oc_z);
                    c := shift_right(c, 16);
                    temp_prod := SPHERE2_R * SPHERE2_R;
                    c := c - shift_right(temp_prod, 16);
                    
                    temp_prod_128 := b * b;
                    discriminant := shift_right(temp_prod_128, 16)(63 downto 0) - shift_left(c, 2);
                    
                    if discriminant >= 0 and b < 0 then
                        t := -b(31 downto 0);
                        
                        if t > 0 and t < hit_distance then
                            hit_detected <= '1';
                            hit_distance <= t;
                            hit_color_r <= SPHERE2_COLOR_R;
                            hit_color_g <= SPHERE2_COLOR_G;
                            hit_color_b <= SPHERE2_COLOR_B;
                        end if;
                    end if;
                    state <= TEST_SPHERE3;
                
                when TEST_SPHERE3 =>
                    -- Sphere 3 intersection test
                    oc_x := ray_origin_x - SPHERE3_X;
                    oc_y := ray_origin_y - SPHERE3_Y;
                    oc_z := ray_origin_z - SPHERE3_Z;
                    
                    b := (oc_x * ray_dir_x) + (oc_y * ray_dir_y) + (oc_z * ray_dir_z);
                    b := shift_right(b, 14);
                    
                    c := (oc_x * oc_x) + (oc_y * oc_y) + (oc_z * oc_z);
                    c := shift_right(c, 16);
                    temp_prod := SPHERE3_R * SPHERE3_R;
                    c := c - shift_right(temp_prod, 16);
                    
                    temp_prod_128 := b * b;
                    discriminant := shift_right(temp_prod_128, 16)(63 downto 0) - shift_left(c, 2);
                    
                    if discriminant >= 0 and b < 0 then
                        t := -b(31 downto 0);
                        
                        if t > 0 and t < hit_distance then
                            hit_detected <= '1';
                            hit_distance <= t;
                            hit_color_r <= SPHERE3_COLOR_R;
                            hit_color_g <= SPHERE3_COLOR_G;
                            hit_color_b <= SPHERE3_COLOR_B;
                        end if;
                    end if;
                    state <= COMPUTE_LIGHTING;
                
                when COMPUTE_LIGHTING =>
                    if hit_detected = '1' then
                        -- Simple diffuse lighting
                        -- In full version: compute light vector, dot with normal
                        light_intensity <= x"80";  -- 50% intensity for now
                    else
                        light_intensity <= x"00";
                    end if;
                    state <= OUTPUT_PIXEL;
                
                when OUTPUT_PIXEL =>
                    -- Debug: Simple white/black to verify hit detection
                    if hit_detected = '1' then
                        -- Show sphere colors
                        red <= std_logic_vector(hit_color_r(7 downto 4));
                        green <= std_logic_vector(hit_color_g(7 downto 4));
                        blue <= std_logic_vector(hit_color_b(7 downto 4));
                    else
                        -- Black background
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
