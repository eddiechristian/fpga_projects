library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port ( 
        clk : in STD_LOGIC;  -- 100 MHz system clock
        reset_n : in STD_LOGIC;  -- Active low reset
        
        -- HDMI outputs (TMDS differential pairs)
        hdmi_clk_p : out STD_LOGIC;
        hdmi_clk_n : out STD_LOGIC;
        hdmi_data_p : out STD_LOGIC_VECTOR(2 downto 0);
        hdmi_data_n : out STD_LOGIC_VECTOR(2 downto 0);
        
        -- Debug LEDs
        led : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top_module;

architecture Behavioral of top_module is
    
    -- Component declarations
    component vga_controller is
        Port ( 
            clk_pixel : in STD_LOGIC;
            reset : in STD_LOGIC;
            red_in : in STD_LOGIC_VECTOR(3 downto 0);
            green_in : in STD_LOGIC_VECTOR(3 downto 0);
            blue_in : in STD_LOGIC_VECTOR(3 downto 0);
            hsync : out STD_LOGIC;
            vsync : out STD_LOGIC;
            red_out : out STD_LOGIC_VECTOR(3 downto 0);
            green_out : out STD_LOGIC_VECTOR(3 downto 0);
            blue_out : out STD_LOGIC_VECTOR(3 downto 0);
            pixel_x : out STD_LOGIC_VECTOR(9 downto 0);
            pixel_y : out STD_LOGIC_VECTOR(9 downto 0);
            video_active : out STD_LOGIC
        );
    end component;
    
    component ray_tracer_core is
        Generic (
            SCREEN_WIDTH : integer := 320;
            SCREEN_HEIGHT : integer := 240
        );
        Port ( 
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            pixel_x : in STD_LOGIC_VECTOR(9 downto 0);
            pixel_y : in STD_LOGIC_VECTOR(9 downto 0);
            pixel_valid : in STD_LOGIC;
            red : out STD_LOGIC_VECTOR(3 downto 0);
            green : out STD_LOGIC_VECTOR(3 downto 0);
            blue : out STD_LOGIC_VECTOR(3 downto 0);
            pixel_ready : out STD_LOGIC
        );
    end component;
    
    -- RGB to TMDS encoder
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
    
    -- Clock management
    component clk_wiz_0
        port (
            clk_out1 : out std_logic;  -- 25.175 MHz (pixel clock)
            clk_out2 : out std_logic;  -- 50 MHz (ray tracer clock)
            reset : in std_logic;
            locked : out std_logic;
            clk_in1 : in std_logic
        );
    end component;
    
    -- Signals
    signal reset : std_logic;
    signal clk_pixel : std_logic;  -- 25.175 MHz for video
    signal clk_50 : std_logic;     -- 50 MHz for ray tracer
    signal clk_locked : std_logic;
    
    signal pixel_x : std_logic_vector(9 downto 0);
    signal pixel_y : std_logic_vector(9 downto 0);
    signal video_active : std_logic;
    signal hsync, vsync : std_logic;
    signal video_data_out : std_logic_vector(11 downto 0);
    
    signal rt_red, rt_green, rt_blue : std_logic_vector(3 downto 0);
    signal rt_pixel_x, rt_pixel_y : std_logic_vector(9 downto 0);
    signal rt_pixel_valid : std_logic;
    signal rt_pixel_ready : std_logic;
    
    -- Framebuffer (dual port RAM)
    type framebuffer_type is array(0 to 307199) of std_logic_vector(11 downto 0);  -- 640x480
    signal framebuffer : framebuffer_type := (others => (others => '0'));
    
    signal fb_write_addr : integer range 0 to 307199 := 0;
    signal fb_read_addr : integer range 0 to 307199 := 0;
    signal fb_write_data : std_logic_vector(11 downto 0);
    signal fb_read_data : std_logic_vector(11 downto 0);
    signal fb_write_en : std_logic := '0';
    
    -- Ray tracer control
    signal render_x : unsigned(9 downto 0) := (others => '0');
    signal render_y : unsigned(9 downto 0) := (others => '0');
    signal rendering : std_logic := '0';
    
    type render_state_type is (IDLE, RENDER_PIXEL, WAIT_READY);
    signal render_state : render_state_type := IDLE;
    
begin
    
    reset <= not reset_n or not clk_locked;
    
    -- Clock wizard for generating pixel and ray tracer clocks
    clk_gen : clk_wiz_0
        port map (
            clk_out1 => clk_pixel,  -- 25.175 MHz (pixel clock)
            clk_out2 => clk_50,     -- 50 MHz (ray tracer)
            reset => not reset_n,
            locked => clk_locked,
            clk_in1 => clk
        );
    
    -- VGA Controller (generates timing, we use output for HDMI)
    vga_ctrl : vga_controller
        port map (
            clk_pixel => clk_pixel,
            reset => reset,
            red_in => fb_read_data(11 downto 8),
            green_in => fb_read_data(7 downto 4),
            blue_in => fb_read_data(3 downto 0),
            hsync => hsync,
            vsync => vsync,
            red_out => video_data_out(11 downto 8),
            green_out => video_data_out(7 downto 4),
            blue_out => video_data_out(3 downto 0),
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            video_active => video_active
        );
    
    -- RGB to HDMI/DVI converter
    hdmi_tx : rgb2tmds
        port map (
            clk_pixel => clk_pixel,
            reset => reset,
            video_data => video_data_out,
            video_active => video_active,
            hsync => hsync,
            vsync => vsync,
            tmds_clk_p => hdmi_clk_p,
            tmds_clk_n => hdmi_clk_n,
            tmds_data_p => hdmi_data_p,
            tmds_data_n => hdmi_data_n
        );
    
    -- Ray Tracer Core
    ray_tracer : ray_tracer_core
        generic map (
            SCREEN_WIDTH => 640,
            SCREEN_HEIGHT => 480
        )
        port map (
            clk => clk_50,
            reset => reset,
            pixel_x => rt_pixel_x,
            pixel_y => rt_pixel_y,
            pixel_valid => rt_pixel_valid,
            red => rt_red,
            green => rt_green,
            blue => rt_blue,
            pixel_ready => rt_pixel_ready
        );
    
    -- Framebuffer (dual port)
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            -- Write port
            if fb_write_en = '1' then
                framebuffer(fb_write_addr) <= fb_write_data;
            end if;
        end if;
    end process;
    
    process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            -- Read port (synchronized to VGA timing)
            -- Direct 1:1 mapping for 640x480
            fb_read_addr <= to_integer(unsigned(pixel_y)) * 640 + 
                           to_integer(unsigned(pixel_x));
            fb_read_data <= framebuffer(fb_read_addr);
        end if;
    end process;
    
    -- Ray tracer render control
    process(clk_50, reset)
    begin
        if reset = '1' then
            render_state <= IDLE;
            render_x <= (others => '0');
            render_y <= (others => '0');
            rt_pixel_valid <= '0';
            fb_write_en <= '0';
            rendering <= '0';
            
        elsif rising_edge(clk_50) then
            case render_state is
                when IDLE =>
                    -- Start rendering frame
                    render_x <= (others => '0');
                    render_y <= (others => '0');
                    rendering <= '1';
                    render_state <= RENDER_PIXEL;
                
                when RENDER_PIXEL =>
                    -- Send pixel to ray tracer
                    rt_pixel_x <= std_logic_vector(render_x);
                    rt_pixel_y <= std_logic_vector(render_y);
                    rt_pixel_valid <= '1';
                    render_state <= WAIT_READY;
                
                when WAIT_READY =>
                    rt_pixel_valid <= '0';
                    
                    if rt_pixel_ready = '1' then
                        -- Store result in framebuffer
                        fb_write_addr <= to_integer(render_y) * 640 + to_integer(render_x);
                        fb_write_data <= rt_red & rt_green & rt_blue;
                        fb_write_en <= '1';
                        
                        -- Move to next pixel
                        if render_x = 639 then
                            render_x <= (others => '0');
                            if render_y = 479 then
                                render_y <= (others => '0');
                                render_state <= IDLE;  -- Frame complete, start over
                            else
                                render_y <= render_y + 1;
                                render_state <= RENDER_PIXEL;
                            end if;
                        else
                            render_x <= render_x + 1;
                            render_state <= RENDER_PIXEL;
                        end if;
                    else
                        fb_write_en <= '0';
                    end if;
                
                when others =>
                    render_state <= IDLE;
            end case;
        end if;
    end process;
    
    -- Debug LEDs
    led(0) <= rendering;
    led(1) <= clk_locked;
    led(2) <= video_active;
    led(7 downto 3) <= (others => '0');

end Behavioral;
