library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Linear Algebra package: Type definitions and constants for Vec3 and fp32
-- This package is fully synthesizable
package lin_alg_pkg is
    
    -- Single precision float as std_logic_vector (32 bits, IEEE 754)
    subtype fp32 is std_logic_vector(31 downto 0);
    
    -- 3D vector of single precision floats
    type Vec3 is record
        x : fp32;
        y : fp32;
        z : fp32;
    end record;
    
    -- 4x4 Matrix (column-major layout)
    -- | x1 x2 x3 x4 |
    -- | y1 y2 y3 y4 |
    -- | z1 z2 z3 z4 |
    -- | w1 w2 w3 w4 |

    type Mat4 is record
        x1: fp32;
        y1: fp32;
        z1: fp32;
        w1: fp32;
        
        x2: fp32;
        y2: fp32;
        z2: fp32;
        w2: fp32;
        
        x3: fp32;
        y3: fp32;
        z3: fp32;
        w3: fp32;
        
        x4: fp32;
        y4: fp32;
        z4: fp32;
        w4: fp32;
    end record;

    constant MAT4_IDENTITY: Mat4 := (
        x1 => X"3F800000",   -- 1.0 in IEEE 754
        y1 => X"00000000",
        z1 => X"00000000",
        w1 => X"00000000",
        x2 => X"00000000",
        y2 => X"3F800000",
        z2 => X"00000000",
        w2 => X"00000000",
        x3 => X"00000000",
        y3 => X"00000000",
        z3 => X"3F800000",
        w3 => X"00000000",
        x4 => X"00000000",
        y4 => X"00000000",
        z4 => X"00000000",
        w4 => X"3F800000"
    );

    -- Useful constants
    constant VEC3_ZERO : Vec3 := (
        x => X"00000000",
        y => X"00000000",
        z => X"00000000"
    );
    
    constant VEC3_UNIT_X : Vec3 := (
        x => X"3F800000",  -- 1.0 in IEEE 754
        y => X"00000000",
        z => X"00000000"
    );
    
    constant VEC3_UNIT_Y : Vec3 := (
        x => X"00000000",
        y => X"3F800000",  -- 1.0 in IEEE 754
        z => X"00000000"
    );
    
    constant VEC3_UNIT_Z : Vec3 := (
        x => X"00000000",
        y => X"00000000",
        z => X"3F800000"   -- 1.0 in IEEE 754
    );
    
    -- Helper function: Create a Vec3 from three fp32 values
    function make_vec3(x, y, z : fp32) return Vec3;
    
end package lin_alg_pkg;

package body lin_alg_pkg is
    
    function make_vec3(x, y, z : fp32) return Vec3 is
        variable result : Vec3;
    begin
        result.x := x;
        result.y := y;
        result.z := z;
        return result;
    end function;
    
end package body lin_alg_pkg;
