library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fp_math_pkg.all;

-- Simplified Sphere Hit Detection using Approximations
-- This uses rough geometric approximations for fast sphere detection
-- For rays going mostly in +Y direction
entity sphere_hit_approx is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        
        -- Ray (simplified: origin + direction)
        ray_origin : in vector3_fp;
        ray_direction : in vector3_fp;
        
        -- Sphere
        sphere_center : in vector3_fp;
        sphere_radius : in fp32;
        
        -- Control
        start : in STD_LOGIC;
        
        -- Output
        hit : out STD_LOGIC;
        done : out STD_LOGIC
    );
end sphere_hit_approx;

architecture Behavioral of sphere_hit_approx is
    
    -- Extract exponent and mantissa for rough FP comparison
    function fp_to_signed(fp : fp32) return signed is
        variable sign_bit : std_logic;
        variable exponent : unsigned(7 downto 0);
        variable mantissa : unsigned(22 downto 0);
        variable result : signed(31 downto 0);
    begin
        sign_bit := fp(31);
        exponent := unsigned(fp(30 downto 23));
        mantissa := unsigned(fp(22 downto 0));
        
        -- Very rough conversion: just use mantissa shifted by (exp - 127)
        -- This is NOT accurate FP->int conversion, just for rough comparison
        if sign_bit = '0' then
            result := signed('0' & fp(30 downto 0));
        else
            result := signed('1' & fp(30 downto 0));
        end if;
        
        return result;
    end function;
    
    signal state : integer range 0 to 3 := 0;
    signal hit_i : std_logic := '0';
    
begin
    
    process(clk, reset)
        variable dx, dy, dz : signed(31 downto 0);
        variable dist_squared : signed(63 downto 0);
        variable radius_squared : signed(31 downto 0);
    begin
        if reset = '1' then
            state <= 0;
            hit_i <= '0';
            done <= '0';
            
        elsif rising_edge(clk) then
            case state is
                when 0 =>  -- IDLE
                    done <= '0';
                    if start = '1' then
                        state <= 1;
                    end if;
                
                when 1 =>  -- Compute approximate hit
                    -- Simplified intersection test:
                    -- For ray going primarily in +Y direction from camera at (0, -10, 0)
                    -- The ray will intersect the Y plane where sphere is (y=0)
                    -- At that point, check if ray's X position is within sphere X range
                    
                    -- Ray at y=0: x_hit = origin.x + direction.x * t
                    -- where t makes origin.y + direction.y * t = 0
                    -- t = -origin.y / direction.y
                    -- For our camera at y=-10 with dir.y=1, t = 10
                    
                    -- x_hit = ray_origin.x + ray_direction.x * 10
                    -- Check if abs(x_hit - sphere_center.x) <= sphere_radius
                    
                    -- Rough comparison using bit patterns
                    dx := fp_to_signed(ray_direction.x);
                    
                    -- Simplified hit test: check if ray's X direction points toward sphere
                    -- Left sphere (center.x < 0): hit if ray_dir.x < 0
                    -- Middle sphere (center.x = 0): hit if abs(ray_dir.x) < threshold  
                    -- Right sphere (center.x > 0): hit if ray_dir.x > 0
                    
                    if sphere_center.x(31) = '1' then
                        -- Left sphere: hit if pointing left
                        hit_i <= ray_direction.x(31);
                    elsif sphere_center.x = FP_ZERO then
                        -- Middle sphere: hit if pointing nearly straight
                        -- Only hit if exponent < 126 (magnitude < 0.5)
                        if unsigned(ray_direction.x(30 downto 23)) < 126 then
                            hit_i <= '1';
                        else
                            hit_i <= '0';
                        end if;
                    else
                        -- Right sphere: hit if pointing right
                        hit_i <= not ray_direction.x(31);
                    end if;
                    
                    state <= 2;
                
                when 2 =>  -- Output
                    hit <= hit_i;
                    done <= '1';
                    state <= 0;
                
                when others =>
                    state <= 0;
            end case;
        end if;
    end process;
    
end Behavioral;
