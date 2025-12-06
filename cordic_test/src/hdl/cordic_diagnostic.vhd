library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple diagnostic: just pass through raw CORDIC output
entity cordic_diagnostic is
    port (
        clk             : in std_logic;
        reset           : in std_logic;
        
        -- Test output
        test_angle      : out std_logic_vector(31 downto 0);
        raw_sin         : out std_logic_vector(31 downto 0);
        raw_cos         : out std_logic_vector(31 downto 0);
        result_valid    : out std_logic;
        test_index      : out integer range 0 to 7
    );
end cordic_diagnostic;

architecture Behavioral of cordic_diagnostic is

    component cordic_sincos
        port (
            aclk                    : in std_logic;
            s_axis_phase_tvalid     : in std_logic;
            s_axis_phase_tdata      : in std_logic_vector(31 downto 0);
            m_axis_dout_tvalid      : out std_logic;
            m_axis_dout_tdata       : out std_logic_vector(63 downto 0)
        );
    end component;

    signal counter : unsigned(15 downto 0) := (others => '0');
    signal angle_idx : integer range 0 to 7 := 0;
    signal phase_valid : std_logic := '0';
    signal phase_data : std_logic_vector(31 downto 0);
    signal cordic_valid : std_logic;
    signal cordic_result : std_logic_vector(63 downto 0);
    
    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of angle_idx : signal is "TRUE";
    attribute MARK_DEBUG of phase_data : signal is "TRUE";
    attribute MARK_DEBUG of phase_valid : signal is "TRUE";
    attribute MARK_DEBUG of cordic_valid : signal is "TRUE";
    attribute MARK_DEBUG of cordic_result : signal is "TRUE";

begin

    cordic_inst: cordic_sincos port map (
        aclk => clk,
        s_axis_phase_tvalid => phase_valid,
        s_axis_phase_tdata => phase_data,
        m_axis_dout_tvalid => cordic_valid,
        m_axis_dout_tdata => cordic_result
    );

    test_angle <= phase_data;
    raw_cos <= cordic_result(63 downto 32);
    raw_sin <= cordic_result(31 downto 0);
    result_valid <= cordic_valid;
    test_index <= angle_idx;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter <= (others => '0');
                angle_idx <= 0;
                phase_valid <= '0';
            else
                counter <= counter + 1;
                
                -- Send one angle every 256 cycles
                if counter = 10 and angle_idx < 7 then
                    phase_valid <= '1';
                    case angle_idx is
                        when 0 => phase_data <= x"00000000"; -- 0°
                        when 1 => phase_data <= x"15555555"; -- 30°
                        when 2 => phase_data <= x"20000000"; -- 45°
                        when 3 => phase_data <= x"2AAAAAAB"; -- 60°
                        when 4 => phase_data <= x"40000000"; -- 90°
                        when 5 => phase_data <= x"55555555"; -- 120°
                        when 6 => phase_data <= x"80000000"; -- 180°
                        when others => phase_data <= x"00000000";
                    end case;
                    angle_idx <= angle_idx + 1;
                else
                    phase_valid <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
