LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Linear Algebra package: Type definitions and constants for Vec3 and fp32
-- This package is fully synthesizable
PACKAGE lin_alg_pkg IS

    -- Single precision float as std_logic_vector (32 bits, IEEE 754)
    SUBTYPE fp32 IS STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- 3D vector of single precision floats
    TYPE Vec3 IS RECORD
        x : fp32;
        y : fp32;
        z : fp32;
    END RECORD;

    -- 4D homogeneous vector (w is always 1.0 for points)
    TYPE Vec4 IS RECORD
        x : fp32;
        y : fp32;
        z : fp32;
        w : fp32; -- Always 1.0 for homogeneous coordinates
    END RECORD;
    -- 4x4 Matrix (column-major layout)
    -- | x1 x2 x3 x4 |
    -- | y1 y2 y3 y4 |
    -- | z1 z2 z3 z4 |
    -- | w1 w2 w3 w4 |

    TYPE Mat4 IS RECORD
        x1 : fp32;
        y1 : fp32;
        z1 : fp32;
        w1 : fp32;

        x2 : fp32;
        y2 : fp32;
        z2 : fp32;
        w2 : fp32;

        x3 : fp32;
        y3 : fp32;
        z3 : fp32;
        w3 : fp32;

        x4 : fp32;
        y4 : fp32;
        z4 : fp32;
        w4 : fp32;
    END RECORD;
    CONSTANT MAT4_IDENTITY : Mat4 := (
        x1 => X"3F800000", -- 1.0 in IEEE 754
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
    CONSTANT VEC3_ZERO : Vec3 := (
        x => X"00000000",
        y => X"00000000",
        z => X"00000000"
    );

    CONSTANT VEC3_UNIT_X : Vec3 := (
        x => X"3F800000", -- 1.0 in IEEE 754
        y => X"00000000",
        z => X"00000000"
    );

    CONSTANT VEC3_UNIT_Y : Vec3 := (
        x => X"00000000",
        y => X"3F800000", -- 1.0 in IEEE 754
        z => X"00000000"
    );

    CONSTANT VEC3_UNIT_Z : Vec3 := (
        x => X"00000000",
        y => X"00000000",
        z => X"3F800000" -- 1.0 in IEEE 754
    );

    CONSTANT VEC4_ZERO : Vec4 := (
        x => X"00000000",
        y => X"00000000",
        z => X"00000000",
        w => X"3F800000" -- w = 1.0
    );

    -- Helper function: Create a Vec3 from three fp32 values
    FUNCTION make_vec3(x, y, z : fp32) RETURN Vec3;

    -- Helper function: Create a Vec4 from three fp32 values (w=1.0)
    FUNCTION make_vec4(x, y, z : fp32) RETURN Vec4;

    -- Helper function: Convert Vec3 to Vec4 (w=1.0)
    FUNCTION vec3_to_vec4(v : Vec3) RETURN Vec4;

    -- Helper function: Convert Vec4 to Vec3 (discard w)
    FUNCTION vec4_to_vec3(v : Vec4) RETURN Vec3;

END PACKAGE lin_alg_pkg;

PACKAGE BODY lin_alg_pkg IS

    FUNCTION make_vec3(x, y, z : fp32) RETURN Vec3 IS
        VARIABLE result : Vec3;
    BEGIN
        result.x := x;
        result.y := y;
        result.z := z;
        RETURN result;
    END FUNCTION;

    FUNCTION make_vec4(x, y, z : fp32) RETURN Vec4 IS
        VARIABLE result : Vec4;
    BEGIN
        result.x := x;
        result.y := y;
        result.z := z;
        result.w := X"3F800000"; -- 1.0
        RETURN result;
    END FUNCTION;

    FUNCTION vec3_to_vec4(v : Vec3) RETURN Vec4 IS
        VARIABLE result : Vec4;
    BEGIN
        result.x := v.x;
        result.y := v.y;
        result.z := v.z;
        result.w := X"3F800000"; -- 1.0
        RETURN result;
    END FUNCTION;

    FUNCTION vec4_to_vec3(v : Vec4) RETURN Vec3 IS
        VARIABLE result : Vec3;
    BEGIN
        result.x := v.x;
        result.y := v.y;
        result.z := v.z;
        RETURN result;
    END FUNCTION;

END PACKAGE BODY lin_alg_pkg;