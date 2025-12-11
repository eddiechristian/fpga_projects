library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cordic_tb is
end entity cordic_tb;

architecture tb of cordic_tb is

    -- Component Declaration for the Unit Under Test (UUT)
    component cordic_sincos is
        generic (
            g_DATA_WIDTH : integer := 16;
            g_ANGLE_WIDTH : integer := 16;
            g_ITERATIONS : integer := 14
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
    end component;

    -- Constants
    -- 30 * (PI/180) = 0.523598 radians
    -- 0.523598 * 2^14 = 8578.4 
    constant TB_ANGLE_30_DEG : SIGNED (15 downto 0) := to_signed(8578, 16);
    constant CLK_PERIOD : time := 10 ns;

    -- Signals
    signal clk : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1'; -- Start with reset high
    signal start : STD_LOGIC := '0';
    signal angle_in : SIGNED (15 downto 0) := (others => '0');

    -- Outputs from the UUT
    signal sin_out : SIGNED (15 downto 0);
    signal cos_out : SIGNED (15 downto 0);
    signal ready : STD_LOGIC;

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: cordic_sincos
        port map (
            clk => clk,
            reset => reset,
            angle_in => angle_in,
            start => start,
            sin_out => sin_out,
            cos_out => cos_out,
            ready => ready
        );

    -- Clock process definitions
    clk_process : process
    begin
        while now < 1 us loop -- Run simulation for 1 microsecond
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_process : process
        variable sin_real_val, cos_real_val : REAL;
        constant FRAC_BITS : integer := 14; -- Matching the code's assumption
    begin
        -- Release reset after a short time
        wait for 20 ns;
        reset <= '0';
        wait for 10 ns;

        -- Apply the 30-degree input value
        angle_in <= TB_ANGLE_30_DEG;
        start <= '1'; -- Pulse the start signal
        wait for 10 ns;
        start <= '0';

        -- Wait until the 'ready' signal is asserted (will take 14+ cycles)
        wait until ready = '1';

        -- Convert output fixed-point values back to real numbers for verification
        -- Conversion formula: Value / 2^FRAC_BITS
        sin_real_val := to_real(sin_out) / (2.0**FRAC_BITS);
        cos_real_val := to_real(cos_out) / (2.0**FRAC_BITS);

        -- Print results to the simulator console
        report "Simulation finished.";
        report "Input Angle (fixed): " & integer'image(to_integer(TB_ANGLE_30_DEG));
        report "Output Sine (fixed): " & integer'image(to_integer(sin_out)) & " -> Real: " & real'image(sin_real_val);
        report "Output Cosine (fixed): " & integer'image(to_integer(cos_out)) & " -> Real: " & real'image(cos_real_val);

        wait; -- Stop the simulation process
    end process;

end architecture tb;

