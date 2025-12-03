library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module_simple is
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
end top_module_simple;

architecture Behavioral of top_module_simple is

    -- Component declaration for the block design
    component hdmi_video_bd_wrapper is
        port (
            sys_clock : in STD_LOGIC;
            sys_resetn : in STD_LOGIC;
            hdmi_tx_clk_p : out STD_LOGIC;
            hdmi_tx_clk_n : out STD_LOGIC;
            hdmi_tx_p : out STD_LOGIC_VECTOR(2 downto 0);
            hdmi_tx_n : out STD_LOGIC_VECTOR(2 downto 0);
            vid_data : in STD_LOGIC_VECTOR(23 downto 0);
            vid_hsync : in STD_LOGIC;
            vid_vsync : in STD_LOGIC;
            vid_active : in STD_LOGIC;
            pixel_clk : out STD_LOGIC;
            locked : out STD_LOGIC
        );
    end component;
    
    -- 1920x1080@60Hz timing parameters
    constant H_ACTIVE : integer := 1920;
    constant H_FP     : integer := 88;
    constant H_SYNC   : integer := 44;
    constant H_BP     : integer := 148;
    constant H_TOTAL  : integer := H_ACTIVE + H_FP + H_SYNC + H_BP; -- 2200
    
    constant V_ACTIVE : integer := 1080;
    constant V_FP     : integer := 4;
    constant V_SYNC   : integer := 5;
    constant V_BP     : integer := 36;
    constant V_TOTAL  : integer := V_ACTIVE + V_FP + V_SYNC + V_BP; -- 1125
    
    -- Video signals
    signal vid_data_i : STD_LOGIC_VECTOR(23 downto 0);
    signal vid_hsync_i : STD_LOGIC := '0';
    signal vid_vsync_i : STD_LOGIC := '0';
    signal vid_active_i : STD_LOGIC := '0';
    
    -- Counters
    signal h_count : integer range 0 to H_TOTAL-1 := 0;
    signal v_count : integer range 0 to V_TOTAL-1 := 0;
    
    -- Pixel clock (148.5 MHz from clocking wizard)
    signal pixel_clk : STD_LOGIC;
    signal locked : STD_LOGIC;
    signal reset_n : STD_LOGIC;

begin

    reset_n <= CPU_RESETN;

    -- Instantiate the block design
    bd_inst : hdmi_video_bd_wrapper
        port map (
            sys_clock => CLK100MHZ,
            sys_resetn => reset_n,
            hdmi_tx_clk_p => hdmi_tx_clk_p,
            hdmi_tx_clk_n => hdmi_tx_clk_n,
            hdmi_tx_p => hdmi_tx_p,
            hdmi_tx_n => hdmi_tx_n,
            vid_data => vid_data_i,
            vid_hsync => vid_hsync_i,
            vid_vsync => vid_vsync_i,
            vid_active => vid_active_i,
            pixel_clk => pixel_clk,
            locked => locked
        );
    
    -- Video timing generator running on pixel clock
    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if reset_n = '0' or locked = '0' then
                h_count <= 0;
                v_count <= 0;
                vid_hsync_i <= '0';
                vid_vsync_i <= '0';
                vid_active_i <= '0';
            else
                -- Horizontal counter
                if h_count = H_TOTAL - 1 then
                    h_count <= 0;
                    -- Vertical counter
                    if v_count = V_TOTAL - 1 then
                        v_count <= 0;
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;
                
                -- Generate hsync (active high)
                if h_count >= (H_ACTIVE + H_FP) and h_count < (H_ACTIVE + H_FP + H_SYNC) then
                    vid_hsync_i <= '1';
                else
                    vid_hsync_i <= '0';
                end if;
                
                -- Generate vsync (active high)
                if v_count >= (V_ACTIVE + V_FP) and v_count < (V_ACTIVE + V_FP + V_SYNC) then
                    vid_vsync_i <= '1';
                else
                    vid_vsync_i <= '0';
                end if;
                
                -- Generate active video signal
                if h_count < H_ACTIVE and v_count < V_ACTIVE then
                    vid_active_i <= '1';
                else
                    vid_active_i <= '0';
                end if;
                
                -- Generate color bar pattern
                if h_count < H_ACTIVE and v_count < V_ACTIVE then
                    -- 8 vertical color bars
                    if h_count < H_ACTIVE/8 then
                        vid_data_i <= x"FFFFFF"; -- White
                    elsif h_count < 2*H_ACTIVE/8 then
                        vid_data_i <= x"FFFF00"; -- Yellow
                    elsif h_count < 3*H_ACTIVE/8 then
                        vid_data_i <= x"00FFFF"; -- Cyan
                    elsif h_count < 4*H_ACTIVE/8 then
                        vid_data_i <= x"00FF00"; -- Green
                    elsif h_count < 5*H_ACTIVE/8 then
                        vid_data_i <= x"FF00FF"; -- Magenta
                    elsif h_count < 6*H_ACTIVE/8 then
                        vid_data_i <= x"FF0000"; -- Red
                    elsif h_count < 7*H_ACTIVE/8 then
                        vid_data_i <= x"0000FF"; -- Blue
                    else
                        vid_data_i <= x"000000"; -- Black
                    end if;
                else
                    vid_data_i <= x"000000"; -- Black during blanking
                end if;
            end if;
        end if;
    end process;

end Behavioral;
