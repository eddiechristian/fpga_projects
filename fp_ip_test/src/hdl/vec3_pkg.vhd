library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Vec3 package: Type definitions and constants
-- This package is fully synthesizable
package vec3_pkg is
    
    -- Single precision float as std_logic_vector (32 bits, IEEE 754)
    subtype fp32 is std_logic_vector(31 downto 0);
    
    -- 3D vector of single precision floats
    type Vec3 is record
        x : fp32;
        y : fp32;
        z : fp32;
    end record;
    
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
    
end package vec3_pkg;

package body vec3_pkg is
    
    function make_vec3(x, y, z : fp32) return Vec3 is
        variable result : Vec3;
    begin
        result.x := x;
        result.y := y;
        result.z := z;
        return result;
    end function;
    
end package body vec3_pkg;
