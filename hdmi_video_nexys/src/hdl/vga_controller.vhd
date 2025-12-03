library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port ( 
        clk_pixel : in STD_LOGIC;  -- 25.175 MHz pixel clock for 640x480@60Hz
        reset : in STD_LOGIC;
        
        -- Pixel data input (12-bit RGB)
        red_in : in STD_LOGIC_VECTOR(3 downto 0);
        green_in : in STD_LOGIC_VECTOR(3 downto 0);
        blue_in : in STD_LOGIC_VECTOR(3 downto 0);
        
        -- VGA outputs
        hsync : out STD_LOGIC;
        vsync : out STD_LOGIC;
        red_out : out STD_LOGIC_VECTOR(3 downto 0);
        green_out : out STD_LOGIC_VECTOR(3 downto 0);
        blue_out : out STD_LOGIC_VECTOR(3 downto 0);
        
        -- Current pixel position
        pixel_x : out STD_LOGIC_VECTOR(9 downto 0);
        pixel_y : out STD_LOGIC_VECTOR(9 downto 0);
        video_active : out STD_LOGIC
    );
end vga_controller;

architecture Behavioral of vga_controller is
    -- VGA 640x480 @ 60 Hz timing parameters
    constant H_VISIBLE : integer := 640;
    constant H_FRONT : integer := 16;
    constant H_SYNC : integer := 96;
    constant H_BACK : integer := 48;
    constant H_TOTAL : integer := 800;
    
    constant V_VISIBLE : integer := 480;
    constant V_FRONT : integer := 10;
    constant V_SYNC : integer := 2;
    constant V_BACK : integer := 33;
    constant V_TOTAL : integer := 525;
    
    signal h_counter : integer range 0 to H_TOTAL-1 := 0;
    signal v_counter : integer range 0 to V_TOTAL-1 := 0;
    
    signal hsync_i : std_logic := '0';
    signal vsync_i : std_logic := '0';
    signal video_active_i : std_logic := '0';
    
begin
    -- Counter process
    process(clk_pixel, reset)
    begin
        if reset = '1' then
            h_counter <= 0;
            v_counter <= 0;
        elsif rising_edge(clk_pixel) then
            if h_counter = H_TOTAL-1 then
                h_counter <= 0;
                if v_counter = V_TOTAL-1 then
                    v_counter <= 0;
                else
                    v_counter <= v_counter + 1;
                end if;
            else
                h_counter <= h_counter + 1;
            end if;
        end if;
    end process;
    
    -- Sync signal generation
    process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            -- Horizontal sync (active low)
            if h_counter >= (H_VISIBLE + H_FRONT) and 
               h_counter < (H_VISIBLE + H_FRONT + H_SYNC) then
                hsync_i <= '0';
            else
                hsync_i <= '1';
            end if;
            
            -- Vertical sync (active low)
            if v_counter >= (V_VISIBLE + V_FRONT) and 
               v_counter < (V_VISIBLE + V_FRONT + V_SYNC) then
                vsync_i <= '0';
            else
                vsync_i <= '1';
            end if;
            
            -- Video active region
            if h_counter < H_VISIBLE and v_counter < V_VISIBLE then
                video_active_i <= '1';
            else
                video_active_i <= '0';
            end if;
        end if;
    end process;
    
    -- Output assignments
    hsync <= hsync_i;
    vsync <= vsync_i;
    video_active <= video_active_i;
    
    pixel_x <= std_logic_vector(to_unsigned(h_counter, 10));
    pixel_y <= std_logic_vector(to_unsigned(v_counter, 10));
    
    -- Color output (blank during blanking interval)
    red_out <= red_in when video_active_i = '1' else (others => '0');
    green_out <= green_in when video_active_i = '1' else (others => '0');
    blue_out <= blue_in when video_active_i = '1' else (others => '0');
    
end Behavioral;
