library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- CORDIC Wrapper with Manual K-Factor Compensation
-- The Xilinx CORDIC in SignedFraction mode doesn't support automatic compensation
-- This wrapper multiplies the output by K = 1.6467602581210654... to correct the gain

entity cordic_sincos_compensated is
    port (
        aclk                    : in std_logic;
        s_axis_phase_tvalid     : in std_logic;
        s_axis_phase_tdata      : in std_logic_vector(31 downto 0);
        m_axis_dout_tvalid      : out std_logic;
        m_axis_dout_tdata       : out std_logic_vector(63 downto 0)
    );
end cordic_sincos_compensated;

architecture Behavioral of cordic_sincos_compensated is

    component cordic_sincos
        port (
            aclk                    : in std_logic;
            s_axis_phase_tvalid     : in std_logic;
            s_axis_phase_tdata      : in std_logic_vector(31 downto 0);
            m_axis_dout_tvalid      : out std_logic;
            m_axis_dout_tdata       : out std_logic_vector(63 downto 0)
        );
    end component;

    signal cordic_valid : std_logic;
    signal cordic_result : std_logic_vector(63 downto 0);
    signal cordic_cos : signed(31 downto 0);
    signal cordic_sin : signed(31 downto 0);
    
    -- K factor = 1.646760258... in Q2.30 format (to multiply with Q1.31)
    -- K * 2^30 = 1.646760258 * 1073741824 = 1768874734 = 0x696B6D8E
    constant K_FACTOR : signed(31 downto 0) := signed(to_signed(1768874734, 32));
    
    -- Multiplier results (64-bit)
    signal cos_mult : signed(63 downto 0);
    signal sin_mult : signed(63 downto 0);
    
    -- Compensated outputs (take upper 32 bits of 64-bit product)
    signal cos_comp : signed(31 downto 0);
    signal sin_comp : signed(31 downto 0);
    
    -- Pipeline stages
    signal valid_pipe : std_logic_vector(2 downto 0) := (others => '0');
    
    -- Debug attributes to preserve signals
    attribute MARK_DEBUG : string;
    attribute KEEP : string;
    attribute MARK_DEBUG of cordic_cos : signal is "TRUE";
    attribute MARK_DEBUG of cordic_sin : signal is "TRUE";
    attribute MARK_DEBUG of cos_mult : signal is "TRUE";
    attribute MARK_DEBUG of sin_mult : signal is "TRUE";
    attribute MARK_DEBUG of cos_comp : signal is "TRUE";
    attribute MARK_DEBUG of sin_comp : signal is "TRUE";
    attribute KEEP of cordic_cos : signal is "TRUE";
    attribute KEEP of cordic_sin : signal is "TRUE";

begin

    -- Instantiate uncompensated CORDIC
    cordic_inst: cordic_sincos port map (
        aclk => aclk,
        s_axis_phase_tvalid => s_axis_phase_tvalid,
        s_axis_phase_tdata => s_axis_phase_tdata,
        m_axis_dout_tvalid => cordic_valid,
        m_axis_dout_tdata => cordic_result
    );
    
    -- Extract cos and sin from CORDIC output
    cordic_cos <= signed(cordic_result(63 downto 32));
    cordic_sin <= signed(cordic_result(31 downto 0));
    
    -- Apply K-factor compensation
    process(aclk)
    begin
        if rising_edge(aclk) then
            -- Stage 1: Multiply by K factor
            cos_mult <= cordic_cos * K_FACTOR;
            sin_mult <= cordic_sin * K_FACTOR;
            valid_pipe(0) <= cordic_valid;
            
            -- Stage 2: Extract upper bits (Q1.31 * Q2.30 = Q3.61, take bits [61:30] for Q1.31)
            cos_comp <= cos_mult(61 downto 30);
            sin_comp <= sin_mult(61 downto 30);
            valid_pipe(1) <= valid_pipe(0);
            
            -- Stage 3: Output
            m_axis_dout_tdata <= std_logic_vector(cos_comp) & std_logic_vector(sin_comp);
            valid_pipe(2) <= valid_pipe(1);
            m_axis_dout_tvalid <= valid_pipe(2);
        end if;
    end process;

end Behavioral;
