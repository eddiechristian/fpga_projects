library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module_raytracer is
    Port (
        -- System clock and reset
        CLK100MHZ : in STD_LOGIC;
        CPU_RESETN : in STD_LOGIC;
        
        -- HDMI output
        hdmi_tx_clk_p : out STD_LOGIC;
        hdmi_tx_clk_n : out STD_LOGIC;
        hdmi_tx_p : out STD_LOGIC_VECTOR(2 downto 0);
        hdmi_tx_n : out STD_LOGIC_VECTOR(2 downto 0);
        
        -- Debug LEDs
        LED : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top_module_raytracer;

architecture Behavioral of top_module_raytracer is

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
            clk_50 : out STD_LOGIC;
            locked : out STD_LOGIC
        );
    end component;
    
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
    
    component ray_tracer_core_fp is
        Generic (
            SCREEN_WIDTH : integer := 640;
            SCREEN_HEIGHT : integer := 480
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
    
    -- Clocks and reset
    signal pixel_clk : STD_LOGIC;  -- 25.175 MHz
    signal clk_50 : STD_LOGIC;     -- 50 MHz for ray tracer
    signal locked : STD_LOGIC;
    signal reset : STD_LOGIC;
    signal reset_n : STD_LOGIC;
    
    -- Video timing signals
    signal pixel_x : STD_LOGIC_VECTOR(9 downto 0);
    signal pixel_y : STD_LOGIC_VECTOR(9 downto 0);
    signal video_active : STD_LOGIC;
    signal hsync, vsync : STD_LOGIC;
    signal vga_red, vga_green, vga_blue : STD_LOGIC_VECTOR(3 downto 0);
    
    -- Signals to block design
    signal vid_data_i : STD_LOGIC_VECTOR(23 downto 0);
    signal vid_hsync_i : STD_LOGIC;
    signal vid_vsync_i : STD_LOGIC;
    signal vid_active_i : STD_LOGIC;
    
    -- Ray tracer signals
    signal rt_red, rt_green, rt_blue : STD_LOGIC_VECTOR(3 downto 0);
    signal rt_pixel_x, rt_pixel_y : STD_LOGIC_VECTOR(9 downto 0);
    signal rt_pixel_valid : STD_LOGIC;
    signal rt_pixel_ready : STD_LOGIC;
    
    -- Framebuffer (dual port RAM) - 640x480x12 bits
    type framebuffer_type is array(0 to 307199) of STD_LOGIC_VECTOR(11 downto 0);
    signal framebuffer : framebuffer_type := (others => (others => '0'));
    
    signal fb_write_addr : integer range 0 to 307199 := 0;
    signal fb_read_addr : integer range 0 to 307199 := 0;
    signal fb_write_data : STD_LOGIC_VECTOR(11 downto 0);
    signal fb_read_data : STD_LOGIC_VECTOR(11 downto 0);
    signal fb_write_en : STD_LOGIC := '0';
    
    -- Ray tracer render control
    signal render_x : unsigned(9 downto 0) := (others => '0');
    signal render_y : unsigned(9 downto 0) := (others => '0');
    signal rendering : STD_LOGIC := '0';
    
    type render_state_type is (IDLE, RENDER_PIXEL, WAIT_READY);
    signal render_state : render_state_type := IDLE;

begin

    reset_n <= CPU_RESETN;
    reset <= not CPU_RESETN or not locked;

    -- Instantiate the block design (HDMI output)
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
            clk_50 => clk_50,
            locked => locked
        );
    
    -- VGA Controller (640x480 timing)
    vga_ctrl : vga_controller
        port map (
            clk_pixel => pixel_clk,
            reset => reset,
            red_in => fb_read_data(11 downto 8),
            green_in => fb_read_data(7 downto 4),
            blue_in => fb_read_data(3 downto 0),
            hsync => hsync,
            vsync => vsync,
            red_out => vga_red,
            green_out => vga_green,
            blue_out => vga_blue,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            video_active => video_active
        );
    
    -- Convert VGA signals to block design format
    -- Note: VGA controller outputs active-low sync, need to check polarity
    vid_hsync_i <= not hsync;  -- Convert to active high for HDMI
    vid_vsync_i <= not vsync;
    vid_active_i <= video_active;
    -- Observed: sending B,R,G shows B,G,R on display
    -- Channels: [23:16], [15:8], [7:0] map to display as: 0, 2, 1
    -- To get R,G,B on display (order 0,1,2), send in positions that map correctly
    -- Send R in position that displays as 0, G in position that displays as 1, B in position that displays as 2
    vid_data_i <= vga_red & "0000" & vga_blue & "0000" & vga_green & "0000";
    
    -- Ray Tracer Core (Floating Point version)
    ray_tracer : ray_tracer_core_fp
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
    
    -- Framebuffer write port (ray tracer clock domain)
    process(clk_50)
    begin
        if rising_edge(clk_50) then
            if fb_write_en = '1' then
                framebuffer(fb_write_addr) <= fb_write_data;
            end if;
        end if;
    end process;
    
    -- Framebuffer read port (pixel clock domain)
    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
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
    LED(0) <= rendering;
    LED(1) <= locked;
    LED(2) <= video_active;
    LED(7 downto 3) <= (others => '0');

end Behavioral;
