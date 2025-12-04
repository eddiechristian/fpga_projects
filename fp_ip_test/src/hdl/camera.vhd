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
    
    -- Camera parameters (matching scene.cpp configuration)
    signal m_camera_length      : fp32 := X"3F800000";  -- 1.0
    signal m_camera_horz_size   : fp32 := X"3E800000";  -- 0.25
    signal m_camera_aspect_ratio: fp32 := X"3FE38E39";  -- 1.777... (16:9)
    
    -- Computed camera geometry (precomputed from UpdateCameraGeometry)
    -- Based on: position=(0,-10,0), lookAt=(0,0,0), up=(0,0,1)
    --           length=1.0, horzSize=0.25, aspect=16/9
    -- 
    -- alignmentVector = normalize(lookAt - position) = normalize((0,10,0)) = (0,1,0)
    -- projectionScreenU = normalize(cross(alignment, up)) = normalize(cross((0,1,0), (0,0,1))) = (1,0,0)
    -- projectionScreenV = normalize(cross(U, alignment)) = normalize(cross((1,0,0), (0,1,0))) = (0,0,1)
    -- projectionScreenCentre = position + length * alignment = (0,-10,0) + 1.0*(0,1,0) = (0,-9,0)
    -- projectionScreenU = U * horzSize = (1,0,0) * 0.25 = (0.25,0,0)
    -- projectionScreenV = V * (horzSize/aspect) = (0,0,1) * (0.25/1.777) = (0,0,0.140625)
    signal m_alignment_vector        : Vec3;
    signal m_projection_screen_u     : Vec3;
    signal m_projection_screen_v     : Vec3;
    signal m_projection_screen_centre: Vec3;
    
    -- Default camera position (constant for now)
    -- Position: (0, -10, 0) - camera 10 units back from origin
    constant DEFAULT_POSITION : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"C1200000",  -- -10.0
        z => X"00000000"   -- 0.0
    );
    
    -- Precomputed camera geometry constants
    -- Based on UpdateCameraGeometry() with scene.cpp parameters
    
    -- alignmentVector = (0, 1, 0) - normalized direction from camera to lookAt
    constant ALIGNMENT_VECTOR : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"3F800000",  -- 1.0
        z => X"00000000"   -- 0.0
    );
    
    -- projectionScreenU = (0.25, 0, 0) - horizontal screen vector scaled by horzSize
    constant SCREEN_U : Vec3 := (
        x => X"3E800000",  -- 0.25
        y => X"00000000",  -- 0.0
        z => X"00000000"   -- 0.0
    );
    
    -- projectionScreenV = (0, 0, 0.140625) - vertical screen vector scaled by horzSize/aspect
    constant SCREEN_V : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"00000000",  -- 0.0
        z => X"3E100000"   -- 0.140625 (approx, actual is 0.25/1.777)
    );
    
    -- projectionScreenCentre = (0, -9, 0) - center of projection screen
    constant SCREEN_CENTRE : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"C1100000",  -- -9.0
        z => X"00000000"   -- 0.0
    );
    
begin
    
    -- Camera state update process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reset to default camera position and geometry
                m_camera_position <= DEFAULT_POSITION;
                m_camera_lookat   <= VEC3_ZERO;  -- Look at origin
                m_camera_up       <= VEC3_UNIT_Z;  -- Up is +Z (matching C++ code)
                
                -- Set precomputed geometry (from UpdateCameraGeometry)
                m_alignment_vector         <= ALIGNMENT_VECTOR;
                m_projection_screen_centre <= SCREEN_CENTRE;
                m_projection_screen_u      <= SCREEN_U;
                m_projection_screen_v      <= SCREEN_V;
                
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
