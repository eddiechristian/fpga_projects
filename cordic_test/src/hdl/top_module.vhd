library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- CORDIC Test Module - Floating Point Version
-- Tests Xilinx CORDIC IP with floating-point sin/cos

entity top_module is
    Port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        led     : out std_logic_vector(3 downto 0)
    );
end top_module;

architecture Behavioral of top_module is

    component clk_wiz_0
        port (
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    component cordic_sincos
        port (
            aclk                    : in std_logic;
            s_axis_phase_tvalid     : in std_logic;
            s_axis_phase_tdata      : in std_logic_vector(31 downto 0);
            m_axis_dout_tvalid      : out std_logic;
            m_axis_dout_tdata       : out std_logic_vector(63 downto 0)
        );
    end component;

    signal clk_200mhz : std_logic;
    signal locked : std_logic;
    signal counter : unsigned(15 downto 0) := (others => '0');
    
    -- CORDIC signals (floating-point)
    signal cordic_phase_valid : std_logic := '0';
    signal cordic_phase : std_logic_vector(31 downto 0);
    signal cordic_result_valid : std_logic;
    signal cordic_result : std_logic_vector(63 downto 0);
    
    -- Extract sin and cos from CORDIC result
    signal cos_out : std_logic_vector(31 downto 0);
    signal sin_out : std_logic_vector(31 downto 0);
    
    -- Latched outputs
    signal latched_sin : std_logic_vector(31 downto 0);
    signal latched_cos : std_logic_vector(31 downto 0);
    signal latched_index : integer range 0 to 7 := 0;
    signal latched_valid : std_logic := '0';
    
    -- Test angle index
    signal angle_index : integer range 0 to 7 := 0;
    signal sent_index : integer range 0 to 7 := 0;
    signal test_complete : std_logic := '0';
    
    -- Debug attributes
    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of angle_index : signal is "TRUE";
    attribute MARK_DEBUG of cordic_phase : signal is "TRUE";
    attribute MARK_DEBUG of cordic_phase_valid : signal is "TRUE";
    attribute MARK_DEBUG of cordic_result_valid : signal is "TRUE";
    attribute MARK_DEBUG of sin_out : signal is "TRUE";
    attribute MARK_DEBUG of cos_out : signal is "TRUE";
    attribute MARK_DEBUG of latched_sin : signal is "TRUE";
    attribute MARK_DEBUG of latched_cos : signal is "TRUE";
    attribute MARK_DEBUG of latched_index : signal is "TRUE";
    attribute MARK_DEBUG of latched_valid : signal is "TRUE";

begin

    clk_wiz_inst: clk_wiz_0 port map (
        clk_out1 => clk_200mhz,
        reset => reset,
        locked => locked,
        clk_in1 => clk
    );

    cordic_inst: cordic_sincos port map (
        aclk => clk_200mhz,
        s_axis_phase_tvalid => cordic_phase_valid,
        s_axis_phase_tdata => cordic_phase,
        m_axis_dout_tvalid => cordic_result_valid,
        m_axis_dout_tdata => cordic_result
    );
    
    -- CORDIC outputs: cos in [63:32], sin in [31:0] (both IEEE-754 float)
    cos_out <= cordic_result(63 downto 32);
    sin_out <= cordic_result(31 downto 0);

    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset = '1' then
                counter <= (others => '0');
                angle_index <= 0;
                sent_index <= 0;
                cordic_phase_valid <= '0';
                test_complete <= '0';
                latched_valid <= '0';
            else
                counter <= counter + 1;

                -- Send one angle every 256 cycles
                if counter = 10 and angle_index < 7 then
                    cordic_phase_valid <= '1';
                    sent_index <= angle_index;
                    case angle_index is
                        when 0 => cordic_phase <= x"00000000"; -- 0.0 rad (0°)
                        when 1 => cordic_phase <= x"3F060A92"; -- 0.5236 rad (30°) = pi/6
                        when 2 => cordic_phase <= x"3F490FDB"; -- 0.7854 rad (45°) = pi/4
                        when 3 => cordic_phase <= x"3F860A92"; -- 1.0472 rad (60°) = pi/3
                        when 4 => cordic_phase <= x"3FC90FDB"; -- 1.5708 rad (90°) = pi/2
                        when 5 => cordic_phase <= x"3FF0C152"; -- 2.0944 rad (120°) = 2*pi/3
                        when 6 => cordic_phase <= x"40490FDB"; -- 3.1416 rad (180°) = pi
                        when others => cordic_phase <= x"00000000";
                    end case;
                    angle_index <= angle_index + 1;
                else
                    cordic_phase_valid <= '0';
                end if;

                -- Latch result when valid
                if cordic_result_valid = '1' then
                    latched_sin <= sin_out;
                    latched_cos <= cos_out;
                    latched_index <= sent_index;
                    latched_valid <= '1';
                else
                    latched_valid <= '0';
                end if;

                if angle_index = 7 then
                    test_complete <= '1';
                end if;
            end if;
        end if;
    end process;
    
    -- LED output
    led(0) <= locked;
    led(1) <= test_complete;
    led(2) <= cordic_result_valid;
    led(3) <= cordic_phase_valid;

end Behavioral;
