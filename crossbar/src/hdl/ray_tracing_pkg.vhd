LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE work.lin_alg_pkg.ALL;

-- Linear Algebra package: Type definitions and constants for Vec3 and fp32
-- This package is fully synthesizable
PACKAGE ray_tracing_pkg IS

    -- Single precision float as std_logic_vector (32 bits, IEEE 754)
    --SUBTYPE fp32 IS STD_LOGIC_VECTOR(31 DOWNTO 0);

    TYPE ObjectType IS (
        SPHERE,
        BOX
    );

    TYPE Ray IS RECORD
        point1 : Vec3;
        point2 : Vec3;
        lab    : Vec3;
    END RECORD;

    TYPE Camera IS RECORD
        position      : Vec3;
        lookat        : Vec3;
        up            : Vec3;
        screen_centre : Vec3;
        screen_u      : Vec3;
        screen_v      : Vec3;
    END RECORD;

    TYPE BBox IS RECORD
        min_bound : Vec3;
        max_bound : Vec3;
    END RECORD;

    TYPE Color IS RECORD
        red   : fp32;
        green : fp32;
        blue  : fp32;
    END RECORD;

    -- I am thinking we could store these in bram??
    TYPE RTObject IS RECORD
        -- bbox     : BBox;
        trans    : Mat4;
        obj_type : ObjectType;
        color    : Color;
    END RECORD;
END PACKAGE ray_tracing_pkg;