library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_module is
    Port (
        -- System clock and reset
        CLK100MHZ : in STD_LOGIC;
        CPU_RESETN : in STD_LOGIC;
        
        -- HDMI output
        hdmi_tx_clk_p : out STD_LOGIC;
        hdmi_tx_clk_n : out STD_LOGIC;
        hdmi_tx_p : out STD_LOGIC_VECTOR(2 downto 0);
        hdmi_tx_n : out STD_LOGIC_VECTOR(2 downto 0)
    );
end top_module;

architecture Behavioral of top_module is

    -- Component declaration for the block design
    component hdmi_video_bd_wrapper is
        port (
            sys_clock : in STD_LOGIC;
            sys_resetn : in STD_LOGIC;
            hdmi_tx_clk_p : out STD_LOGIC;
            hdmi_tx_clk_n : out STD_LOGIC;
            hdmi_tx_p : out STD_LOGIC_VECTOR(2 downto 0);
            hdmi_tx_n : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

begin

    -- Instantiate the block design
    bd_inst : hdmi_video_bd_wrapper
        port map (
            sys_clock => CLK100MHZ,
            sys_resetn => CPU_RESETN,
            hdmi_tx_clk_p => hdmi_tx_clk_p,
            hdmi_tx_clk_n => hdmi_tx_clk_n,
            hdmi_tx_p => hdmi_tx_p,
            hdmi_tx_n => hdmi_tx_n
        );

end Behavioral;
