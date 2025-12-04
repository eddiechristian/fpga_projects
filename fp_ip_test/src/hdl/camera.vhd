library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.vec3_pkg.all;

-- Camera entity - stores camera parameters and geometry
-- Similar to the Camera class in camera.hpp from Ep3Code
-- 
-- Stores camera state in registers (flip-flops):
--   - Position, LookAt, Up vectors
--   - Length, horizontal size, aspect ratio
--   - Computed projection screen vectors
--
-- Resource usage:
--   - ~770 flip-flops for all camera parameters
--   - 0.3% of Artix-7 xc7a200t registers
entity camera is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        
        -- Camera parameter inputs (for future updates)
        update_position : in  std_logic;  -- Enable position update
        
        -- Camera outputs (for ray generation)
        position      : out Vec3;
        lookat        : out Vec3;
        up            : out Vec3;
        screen_centre : out Vec3;
        screen_u      : out Vec3;
        screen_v      : out Vec3
    );
end entity camera;

architecture behavioral of camera is
    
    -- Camera position and orientation (like C++ member variables)
    -- These synthesize to registers (flip-flops)
    signal m_camera_position : Vec3 := VEC3_ZERO;
    signal m_camera_lookat   : Vec3 := VEC3_ZERO;
    signal m_camera_up       : Vec3 := VEC3_UNIT_Y;
    
    -- Camera parameters
    signal m_camera_length      : fp32 := X"3F800000";  -- 1.0
    signal m_camera_horz_size   : fp32 := X"3F800000";  -- 1.0
    signal m_camera_aspect_ratio: fp32 := X"3FAAAAAB";  -- 1.333 (4:3)
    
    -- Computed camera geometry
    signal m_alignment_vector        : Vec3 := VEC3_ZERO;
    signal m_projection_screen_u     : Vec3 := VEC3_UNIT_X;
    signal m_projection_screen_v     : Vec3 := VEC3_UNIT_Y;
    signal m_projection_screen_centre: Vec3 := VEC3_ZERO;
    
    -- Default camera position (constant for now)
    -- Position: (0, -10, 0) - camera 10 units back from origin
    constant DEFAULT_POSITION : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"C1200000",  -- -10.0
        z => X"00000000"   -- 0.0
    );
    
begin
    
    -- Camera state update process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset to default camera position
                m_camera_position <= DEFAULT_POSITION;
                m_camera_lookat   <= VEC3_ZERO;  -- Look at origin
                m_camera_up       <= VEC3_UNIT_Y;
                
                -- Reset computed geometry
                m_projection_screen_centre <= VEC3_ZERO;
                m_projection_screen_u      <= VEC3_UNIT_X;
                m_projection_screen_v      <= VEC3_UNIT_Y;
                m_alignment_vector         <= VEC3_ZERO;
                
            else
                -- Update camera position when requested
                if update_position = '1' then
                    -- For now, position stays at DEFAULT_POSITION
                    -- In the future, this could update based on inputs
                    m_camera_position <= DEFAULT_POSITION;
                end if;
                
                -- Camera geometry update would go here
                -- (requires Vec3 operations like normalize, cross, etc.)
                -- For now, keep simple fixed values
                
            end if;
        end if;
    end process;
    
    -- Output current camera state
    position      <= m_camera_position;
    lookat        <= m_camera_lookat;
    up            <= m_camera_up;
    screen_centre <= m_projection_screen_centre;
    screen_u      <= m_projection_screen_u;
    screen_v      <= m_projection_screen_v;
    
end architecture behavioral;
