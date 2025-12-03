library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port ( 
        clk : in STD_LOGIC;  -- 100 MHz system clock
        
        -- HDMI outputs
        hdmi_clk_p : out STD_LOGIC;
        hdmi_clk_n : out STD_LOGIC;
        hdmi_data_p : out STD_LOGIC_VECTOR(2 downto 0);
        hdmi_data_n : out STD_LOGIC_VECTOR(2 downto 0);
        
        -- Debug LED
        led : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top_module;

architecture Behavioral of top_module is
    
    -- Clock wizard component
    component clk_wiz_0
        port (
            clk_out1 : out std_logic;  -- 25 MHz (VGA pixel clock)
            clk_out2 : out std_logic;  -- 125 MHz (5x pixel clock for TMDS)
            reset : in std_logic;
            locked : out std_logic;
            clk_in1 : in std_logic
        );
    end component;
    
    -- TMDS encoder component
    component rgb2tmds is
        Port ( 
            clk_pixel : in STD_LOGIC;
            reset : in STD_LOGIC;
            video_data : in STD_LOGIC_VECTOR(11 downto 0);
            video_active : in STD_LOGIC;
            hsync : in STD_LOGIC;
            vsync : in STD_LOGIC;
            tmds_clk_p : out STD_LOGIC;
            tmds_clk_n : out STD_LOGIC;
            tmds_data_p : out STD_LOGIC_VECTOR(2 downto 0);
            tmds_data_n : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;
    
    signal clk_pixel : std_logic;
    signal clk_tmds : std_logic;
    signal clk_locked : std_logic;
    signal reset : std_logic;
    
    -- Video timing signals (VGA: 640x480@60Hz)
    constant H_ACTIVE : integer := 640;
    constant H_FP : integer := 16;     -- Front porch
    constant H_SYNC : integer := 96;   -- Sync pulse
    constant H_BP : integer := 48;     -- Back porch
    constant H_TOTAL : integer := H_ACTIVE + H_FP + H_SYNC + H_BP;  -- 800
    
    constant V_ACTIVE : integer := 480;
    constant V_FP : integer := 10;
    constant V_SYNC : integer := 2;
    constant V_BP : integer := 33;
    constant V_TOTAL : integer := V_ACTIVE + V_FP + V_SYNC + V_BP;  -- 525
    
    signal h_count : integer range 0 to H_TOTAL-1 := 0;
    signal v_count : integer range 0 to V_TOTAL-1 := 0;
    
    signal hsync : std_logic := '0';
    signal vsync : std_logic := '0';
    signal video_active : std_logic := '0';
    
    signal red : std_logic_vector(3 downto 0);
    signal green : std_logic_vector(3 downto 0);
    signal blue : std_logic_vector(3 downto 0);
    signal video_data : std_logic_vector(11 downto 0);
    
begin
    
    reset <= not clk_locked;
    
    -- Generate pixel and TMDS clocks
    clk_gen : clk_wiz_0
        port map (
            clk_out1 => clk_pixel,   -- 25 MHz
            clk_out2 => clk_tmds,    -- 125 MHz
            reset => '0',
            locked => clk_locked,
            clk_in1 => clk
        );
    
    -- Video timing generator
    process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            if reset = '1' then
                h_count <= 0;
                v_count <= 0;
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
                
                -- Generate sync signals (negative polarity for VGA)
                if h_count >= (H_ACTIVE + H_FP) and h_count < (H_ACTIVE + H_FP + H_SYNC) then
                    hsync <= '0';  -- Negative polarity
                else
                    hsync <= '1';
                end if;
                
                if v_count >= (V_ACTIVE + V_FP) and v_count < (V_ACTIVE + V_FP + V_SYNC) then
                    vsync <= '0';  -- Negative polarity
                else
                    vsync <= '1';
                end if;
                
                -- Video active region
                if h_count < H_ACTIVE and v_count < V_ACTIVE then
                    video_active <= '1';
                else
                    video_active <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Test pattern generator: Solid white to test HDMI output
    process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            if video_active = '1' then
                -- Solid white
                red <= x"F";
                green <= x"F";
                blue <= x"F";
            else
                -- Blanking
                red <= x"0";
                green <= x"0";
                blue <= x"0";
            end if;
        end if;
    end process;
    
    video_data <= red & green & blue;
    
    -- RGB to HDMI/TMDS encoder
    hdmi_tx : rgb2tmds
        port map (
            clk_pixel => clk_pixel,
            reset => reset,
            video_data => video_data,
            video_active => video_active,
            hsync => hsync,
            vsync => vsync,
            tmds_clk_p => hdmi_clk_p,
            tmds_clk_n => hdmi_clk_n,
            tmds_data_p => hdmi_data_p,
            tmds_data_n => hdmi_data_n
        );
    
    -- Debug LEDs
    led(0) <= clk_locked;
    led(1) <= video_active;
    led(7 downto 2) <= (others => '0');
    
end Behavioral;
