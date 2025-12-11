library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- Required for initial constant calculation in VHDL

entity cordic_sincos is
    generic (
        g_DATA_WIDTH : integer := 16; -- Total data width (e.g., 2 sign + 14 fractional bits)
        g_ANGLE_WIDTH : integer := 16; -- Angle data width (e.g., 2 integer + 14 fractional bits)
        g_ITERATIONS : integer := 14  -- Number of CORDIC iterations
    );
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        angle_in : in SIGNED (g_ANGLE_WIDTH - 1 downto 0);
        start : in STD_LOGIC;
        sin_out : out SIGNED (g_DATA_WIDTH - 1 downto 0);
        cos_out : out SIGNED (g_DATA_WIDTH - 1 downto 0);
        ready : out STD_LOGIC
    );
end entity cordic_sincos;

architecture rtl of cordic_sincos is

    -- Type for fixed-point math (signed, specific fractional bits)
    subtype fixed_point_t is SIGNED (g_DATA_WIDTH - 1 downto 0);

    -- CORDIC angle look-up table for arctan(2^-i)
    type angle_table_t is array (0 to g_ITERATIONS - 1) of fixed_point_t;

    -- Calculate the angle table at compile time
    function init_angles return angle_table_t is
        variable temp_table : angle_table_t;
        constant PI_HALF : REAL := MATH_PI / 2.0;
        -- Assuming 2 bits for integer part (sign + 1 integer bit), rest fractional
        constant FRAC_BITS : integer := g_ANGLE_WIDTH - 2; 
    begin
        for i in 0 to g_ITERATIONS - 1 loop
            -- Calculate arctan(2^-i) in radians, scale to fixed point format
            temp_table(i) := to_signed(integer(
                atan(2.0**(-i)) * (2.0**(FRAC_BITS))
            ), g_ANGLE_WIDTH);
        end loop;
        return temp_table;
    end function init_angles;

    constant CORDIC_ANGLES : angle_table_t := init_angles;

    -- The inverse of the CORDIC gain K (approx 0.60725)
    -- Scaled to fixed point. Assuming 2 integer bits.
    constant INV_K_FIXED : fixed_point_t := to_signed(integer(
        0.607252935 * (2.0**(g_DATA_WIDTH - 2))
    ), g_DATA_WIDTH);

    signal x_reg, y_reg, z_reg : fixed_point_t;
    signal iteration_count : integer range 0 to g_ITERATIONS;
    signal busy : STD_LOGIC;

begin

    process(clk)
        variable x_next, y_next, z_next : fixed_point_t;
        variable direction : SIGNED (0 downto 0); -- -1 or +1
    begin
        if reset = '1' then
            x_reg <= (others => '0');
            y_reg <= (others => '0');
            z_reg <= (others => '0');
            iteration_count <= 0;
            busy <= '0';
            ready <= '0';
        elsif rising_edge(clk) then
            if start = '1' and busy = '0' then
                -- Initial values for sine/cosine generation
                x_reg <= INV_K_FIXED; -- Start with 1/K scaled
                y_reg <= (others => '0');
                z_reg <= resize(angle_in, g_ANGLE_WIDTH); -- Input angle
                iteration_count <= 0;
                busy <= '1';
                ready <= '0';
            elsif busy = '1' then
                if iteration_count < g_ITERATIONS then
                    -- Determine direction of rotation
                    if z_reg(g_ANGLE_WIDTH - 1) = '1' then -- Check sign bit
                        direction := to_signed(-1, 1);
                    else
                        direction := to_signed(1, 1);
                    end if;

                    -- CORDIC equations (using shifts instead of multiplications)
                    -- Note: VHDL shifts are logical, but numeric_std allows signed
                    -- Left shift (multiplication by 2), Right shift (division by 2)
                    x_next := x_reg - resize(y_reg sra iteration_count, g_DATA_WIDTH) * direction;
                    y_next := y_reg + resize(x_reg sra iteration_count, g_DATA_WIDTH) * direction;
                    z_next := z_reg - resize(CORDIC_ANGLES(iteration_count), g_ANGLE_WIDTH) * direction;

                    x_reg <= x_next;
                    y_reg <= y_next;
                    z_reg <= z_next;
                    iteration_count <= iteration_count + 1;
                else
                    -- Done with iterations
                    sin_out <= y_reg;
                    cos_out <= x_reg;
                    busy <= '0';
                    ready <= '1';
                    iteration_count <= 0;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;

