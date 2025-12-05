library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use work.lin_alg_pkg.all;

-- Vec3 simulation package: Helper functions for testbenches
-- WARNING: These functions are SIMULATION ONLY and will NOT synthesize
-- Use the hardware entities (vec3_*_hw) for actual FPGA implementation
package vec3_sim_pkg is
    
    -- Convert real to IEEE 754 single precision
    function real_to_fp32(r : real) return fp32;
    
    -- Convert IEEE 754 single precision to real
    function fp32_to_real(fp : fp32) return real;
    
    -- Create Vec3 from three real values
    function make_vec3_real(x, y, z : real) return Vec3;
    
    -- Vector operations (simulation only)
    function vec3_add(a, b : Vec3) return Vec3;
    function vec3_sub(a, b : Vec3) return Vec3;
    function vec3_scale(v : Vec3; scalar : real) return Vec3;
    function vec3_dot(a, b : Vec3) return real;
    function vec3_length_squared(v : Vec3) return real;
    function vec3_length(v : Vec3) return real;
    function vec3_normalize(v : Vec3) return Vec3;
    function vec3_cross(a, b : Vec3) return Vec3;
    
end package vec3_sim_pkg;

package body vec3_sim_pkg is
    
    function real_to_fp32(r : real) return fp32 is
        variable result : fp32;
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable exp_bits : unsigned(7 downto 0);
        variable mant_bits : unsigned(22 downto 0);
        variable temp : real;
    begin
        if r = 0.0 then
            return X"00000000";
        end if;
        
        if r < 0.0 then
            sign := '1';
            temp := -r;
        else
            sign := '0';
            temp := r;
        end if;
        
        exponent := integer(floor(log2(temp)));
        mantissa := temp / (2.0 ** real(exponent));
        exp_bits := to_unsigned(exponent + 127, 8);
        mantissa := mantissa - 1.0;
        mant_bits := to_unsigned(integer(mantissa * (2.0 ** 23)), 23);
        result := sign & std_logic_vector(exp_bits) & std_logic_vector(mant_bits);
        
        return result;
    end function;
    
    function fp32_to_real(fp : fp32) return real is
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable result : real;
    begin
        sign := fp(31);
        exponent := to_integer(unsigned(fp(30 downto 23)));
        
        if exponent = 0 then
            return 0.0;
        elsif exponent = 255 then
            return 0.0;
        end if;
        
        mantissa := 1.0 + real(to_integer(unsigned(fp(22 downto 0)))) / (2.0 ** 23);
        result := mantissa * (2.0 ** real(exponent - 127));
        
        if sign = '1' then
            result := -result;
        end if;
        
        return result;
    end function;
    
    function make_vec3_real(x, y, z : real) return Vec3 is
        variable result : Vec3;
    begin
        result.x := real_to_fp32(x);
        result.y := real_to_fp32(y);
        result.z := real_to_fp32(z);
        return result;
    end function;
    
    function vec3_add(a, b : Vec3) return Vec3 is
        variable ax, ay, az, bx, by, bz : real;
    begin
        ax := fp32_to_real(a.x);
        ay := fp32_to_real(a.y);
        az := fp32_to_real(a.z);
        bx := fp32_to_real(b.x);
        by := fp32_to_real(b.y);
        bz := fp32_to_real(b.z);
        
        return make_vec3_real(ax + bx, ay + by, az + bz);
    end function;
    
    function vec3_sub(a, b : Vec3) return Vec3 is
        variable ax, ay, az, bx, by, bz : real;
    begin
        ax := fp32_to_real(a.x);
        ay := fp32_to_real(a.y);
        az := fp32_to_real(a.z);
        bx := fp32_to_real(b.x);
        by := fp32_to_real(b.y);
        bz := fp32_to_real(b.z);
        
        return make_vec3_real(ax - bx, ay - by, az - bz);
    end function;
    
    function vec3_scale(v : Vec3; scalar : real) return Vec3 is
        variable vx, vy, vz : real;
    begin
        vx := fp32_to_real(v.x);
        vy := fp32_to_real(v.y);
        vz := fp32_to_real(v.z);
        
        return make_vec3_real(vx * scalar, vy * scalar, vz * scalar);
    end function;
    
    function vec3_dot(a, b : Vec3) return real is
        variable ax, ay, az, bx, by, bz : real;
    begin
        ax := fp32_to_real(a.x);
        ay := fp32_to_real(a.y);
        az := fp32_to_real(a.z);
        bx := fp32_to_real(b.x);
        by := fp32_to_real(b.y);
        bz := fp32_to_real(b.z);
        
        return ax * bx + ay * by + az * bz;
    end function;
    
    function vec3_length_squared(v : Vec3) return real is
    begin
        return vec3_dot(v, v);
    end function;
    
    function vec3_length(v : Vec3) return real is
    begin
        return sqrt(vec3_length_squared(v));
    end function;
    
    function vec3_normalize(v : Vec3) return Vec3 is
        variable len : real;
    begin
        len := vec3_length(v);
        if len > 0.0 then
            return vec3_scale(v, 1.0 / len);
        else
            return VEC3_ZERO;
        end if;
    end function;
    
    function vec3_cross(a, b : Vec3) return Vec3 is
        variable ax, ay, az, bx, by, bz : real;
        variable cx, cy, cz : real;
    begin
        ax := fp32_to_real(a.x);
        ay := fp32_to_real(a.y);
        az := fp32_to_real(a.z);
        bx := fp32_to_real(b.x);
        by := fp32_to_real(b.y);
        bz := fp32_to_real(b.z);
        
        cx := ay * bz - az * by;
        cy := az * bx - ax * bz;
        cz := ax * by - ay * bx;
        
        return make_vec3_real(cx, cy, cz);
    end function;
    
end package body vec3_sim_pkg;
