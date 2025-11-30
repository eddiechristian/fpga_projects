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
                    -- norm_x = (pixel_x / SCREEN_WIDTH) * 2 - 1
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
                    
                    -- Ray direction: toward screen position with aspect ratio correction
                    -- Simplified: ray points toward (norm_x * 0.25, 0, norm_y * 0.25 / aspect)
                    ray_dir_x <= norm_x(31 downto 2) & "00";  -- * 0.25
                    ray_dir_y <= ONE_FP;  -- Forward direction
                    ray_dir_z <= norm_y(31 downto 2) & "00";  -- * 0.25
                    
                    hit_detected <= '0';
                    hit_distance <= x"7FFFFFFF";  -- Max distance
                    state <= TEST_SPHERE1;
                
                when TEST_SPHERE1 =>
                    -- Simplified sphere intersection test
                    -- This is a placeholder - full implementation would use proper
                    -- ray-sphere intersection algorithm with Xilinx FP IP
                    
                    -- For now, simple distance check from sphere center
                    sphere_hit := '0';
                    
                    -- Check if ray is near sphere (simplified)
                    -- In full implementation, solve: |origin + t*direction - sphere_center|^2 = radius^2
                    
                    if sphere_hit = '1' then
                        hit_detected <= '1';
                        hit_color_r <= SPHERE1_COLOR_R;
                        hit_color_g <= SPHERE1_COLOR_G;
                        hit_color_b <= SPHERE1_COLOR_B;
                    end if;
                    
                    state <= TEST_SPHERE2;
                
                when TEST_SPHERE2 =>
                    -- Similar sphere 2 test
                    state <= TEST_SPHERE3;
                
                when TEST_SPHERE3 =>
                    -- Similar sphere 3 test
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
                    if hit_detected = '1' then
                        -- Apply lighting to color
                        red <= std_logic_vector(hit_color_r(7 downto 4));
                        green <= std_logic_vector(hit_color_g(7 downto 4));
                        blue <= std_logic_vector(hit_color_b(7 downto 4));
                    else
                        -- Background color (black)
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
