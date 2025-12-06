library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package conversion_pkg is
    -- Convert IEEE-754 single to signed Q1.31 fixed-point (expects 32-bit vectors)
    function float_to_q31(f : std_logic_vector) return std_logic_vector;
    -- Convert signed Q1.31 fixed-point to IEEE-754 single (expects 32-bit vectors)
    function q31_to_float(q : std_logic_vector) return std_logic_vector;
    -- Convert IEEE-754 radians to Q1.31 phase for CORDIC (range [-pi,pi) -> [-1,1))
    function radians_to_q31(angle_rad : std_logic_vector) return std_logic_vector;
end package conversion_pkg;

package body conversion_pkg is
    -- IEEE-754 fields
    function float_to_q31(f : std_logic_vector) return std_logic_vector is
        variable s      : std_logic := f(31);
        variable exp    : unsigned(7 downto 0) := unsigned(f(30 downto 23));
        variable frac   : unsigned(22 downto 0) := unsigned(f(22 downto 0));
        -- Build 1.frac as 24-bit unsigned (implicit 1)
        variable mant   : unsigned(23 downto 0);
        variable shift  : integer;
        -- 64-bit work vector to accommodate shifts
        variable work   : signed(63 downto 0) := (others => '0');
        variable res32  : signed(31 downto 0);
    begin
        -- NaN/Inf -> saturate
        if exp = "11111111" then
            if s = '1' then
                return std_logic_vector(to_signed(-2147483648, 32)); -- 0x80000000
            else
                return std_logic_vector(to_signed(2147483647, 32));  -- 0x7FFFFFFF
            end if;
        end if;
        -- Zero or denormals
        if exp = "00000000" then
            return std_logic_vector(to_signed(0, 32));
        end if;
        -- mantissa with hidden 1
        mant := ("1" & frac);
        -- Compute shift = (exp-127) + 31 - 23 = exp - 119
        shift := to_integer(exp) - 119;
        -- Place mant at bit position so that mant represents mantissa * 2^(shift)
        work := (others => '0');
        if shift >= 0 then
            if shift + 23 <= 63 then
                work(shift+23 downto shift) := signed(resize(mant, 24));
            else
                -- overflow, saturate
                if s = '1' then
                    return std_logic_vector(to_signed(-2147483648, 32));
                else
                    return std_logic_vector(to_signed(2147483647, 32));
                end if;
            end if;
        else
            -- right shift |shift| of mant
            if (-shift) >= 24 then
                work := (others => '0');
            else
                work(23 downto 0) := signed(resize(shift_right(mant, -shift), 24));
            end if;
        end if;
        -- Take lower 32 bits as Q1.31
        res32 := work(31 downto 0);
        if s = '1' then
            res32 := -res32;
        end if;
        return std_logic_vector(res32);
    end function;

    function q31_to_float(q : std_logic_vector) return std_logic_vector is
        variable x      : signed(31 downto 0) := signed(q);
        variable s      : std_logic := '0';
        variable ux     : unsigned(31 downto 0);
        variable lz     : integer;
        variable exp    : integer;
        variable mant   : unsigned(22 downto 0);
        variable res    : std_logic_vector(31 downto 0);
        variable absx   : unsigned(31 downto 0);
        variable tmpu   : unsigned(31 downto 0);
        variable tmpd   : unsigned(31 downto 0);
        -- K-factor compensation for CORDIC: K = 1.646760258
        -- K in Q2.30 format = 1768874734 = 0x696B6D8E
        constant K_FACTOR : signed(31 downto 0) := to_signed(1768874734, 32);
        variable x_compensated : signed(63 downto 0);
    begin
        if x = 0 then
            return std_logic_vector(to_unsigned(0, 32));
        end if;
        
        -- Apply K-factor compensation: multiply Q1.31 by Q2.30 = Q3.61
        -- Then extract upper 32 bits (shift right by 30) to get Q1.31 result
        x_compensated := x * K_FACTOR;
        x := x_compensated(61 downto 30);  -- Extract Q1.31 result from Q3.61
        if x(31) = '1' then
            s := '1';
            ux := unsigned(-x);
        else
            s := '0';
            ux := unsigned(x);
        end if;
        absx := ux;
        -- find leading 1 position (msb index)
        lz := 0;
        for i in 31 downto 0 loop
            if absx(i) = '1' then
                lz := i;
                exit;
            end if;
        end loop;
        -- value = absx * 2^(-31); normalized to 1.x * 2^(lz-31)
        exp  := 127 + (lz - 31);
        if lz = 31 then
            mant := (others => '0');
        else
            -- shift left to put bit lz at position 23 (hidden 1), then drop it
            -- target: 1.xxx where mantissa is next 23 bits
            -- we need to align so that (absx << (23 - (lz))) has top '1' at bit 23
            if (23 - lz) >= 0 then
                tmpu := unsigned(shift_left(absx, 23 - lz));
                mant := tmpu(22 downto 0);
            else
                tmpd := unsigned(shift_right(absx, lz - 23));
                mant := tmpd(22 downto 0);
            end if;
        end if;
        -- assemble float
        res(31) := s;
        res(30 downto 23) := std_logic_vector(to_unsigned(exp, 8));
        res(22 downto 0)  := std_logic_vector(mant);
        return res;
    end function;

    -- Convert radians to Q1.31 phase for CORDIC
    -- CORDIC phase format: Q1.31 with SignedFraction, Radians mode
    -- Range: Q1.31 integer value [-2^31, 2^31) represents phase [-pi, pi)
    -- So: Q1.31_int_value = (angle_radians / pi) * 2^31
    -- Since Q1.31 represents values in [-1, 1), we need: angle/pi
    -- This is a combinational approximation - for real use, instantiate FP multiplier
    function radians_to_q31(angle_rad : std_logic_vector) return std_logic_vector is
        variable s      : std_logic;
        variable exp    : unsigned(7 downto 0);
        variable frac   : unsigned(22 downto 0);
        variable angle_over_pi : std_logic_vector(31 downto 0);
        -- We need to compute angle_rad / pi
        -- pi ≈ 3.14159265 = 0x40490FDB in IEEE-754
        -- 1/pi ≈ 0.31831 = 0x3EA2F983
        -- Simplified: multiply by 1/pi approximation
        -- For now, crude division: extract exponent and adjust
        variable new_exp : integer;
    begin
        s := angle_rad(31);
        exp := unsigned(angle_rad(30 downto 23));
        frac := unsigned(angle_rad(22 downto 0));
        
        -- angle/pi ≈ angle * 0.31831 ≈ angle * (1/3.14159)
        -- Approximate by reducing exponent by ~1.65 (since pi ≈ 2^1.65)
        -- This is very rough; for accurate results need actual FP divide
        if exp = "00000000" or exp = "11111111" then
            -- Zero, denormal, or inf/nan
            return std_logic_vector(to_signed(0, 32));
        end if;
        
        new_exp := to_integer(exp) - 2;  -- Divide by ~4 (approximates /pi)
        if new_exp < 1 then
            new_exp := 1;
        elsif new_exp > 254 then
            new_exp := 254;
        end if;
        
        angle_over_pi := s & std_logic_vector(to_unsigned(new_exp, 8)) & std_logic_vector(frac);
        return float_to_q31(angle_over_pi);
    end function;

end package body conversion_pkg;
