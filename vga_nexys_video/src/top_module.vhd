library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port (
        clk_100mhz : in STD_LOGIC;
        reset      : in STD_LOGIC;
        vga_r      : out STD_LOGIC_VECTOR(3 downto 0);
        vga_g      : out STD_LOGIC_VECTOR(3 downto 0);
        vga_b      : out STD_LOGIC_VECTOR(3 downto 0);
        vga_hsync  : out STD_LOGIC;
        vga_vsync  : out STD_LOGIC
    );
end top_module;

architecture Behavioral of top_module is
    -- Clock divider for 25MHz pixel clock (640x480 @ 60Hz)
    signal clk_25mhz : STD_LOGIC := '0';
    signal clk_counter : unsigned(1 downto 0) := (others => '0');
    
    -- VGA timing signals
    signal h_count : unsigned(9 downto 0) := (others => '0');
    signal v_count : unsigned(9 downto 0) := (others => '0');
    signal video_on : STD_LOGIC;
    signal hsync_int, vsync_int : STD_LOGIC;
    
    -- VGA 640x480 @ 60Hz timing constants
    constant H_DISPLAY    : integer := 640;
    constant H_FRONT      : integer := 16;
    constant H_SYNC       : integer := 96;
    constant H_BACK       : integer := 48;
    constant H_TOTAL      : integer := 800;
    
    constant V_DISPLAY    : integer := 480;
    constant V_FRONT      : integer := 10;
    constant V_SYNC       : integer := 2;
    constant V_BACK       : integer := 33;
    constant V_TOTAL      : integer := 525;
    
begin

    -- Generate 25MHz pixel clock from 100MHz system clock
    process(clk_100mhz, reset)
    begin
        if reset = '1' then
            clk_counter <= (others => '0');
            clk_25mhz <= '0';
        elsif rising_edge(clk_100mhz) then
            if clk_counter = 1 then
                clk_25mhz <= not clk_25mhz;
                clk_counter <= (others => '0');
            else
                clk_counter <= clk_counter + 1;
            end if;
        end if;
    end process;
    
    -- Horizontal counter
    process(clk_25mhz, reset)
    begin
        if reset = '1' then
            h_count <= (others => '0');
        elsif rising_edge(clk_25mhz) then
            if h_count = H_TOTAL - 1 then
                h_count <= (others => '0');
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;
    
    -- Vertical counter
    process(clk_25mhz, reset)
    begin
        if reset = '1' then
            v_count <= (others => '0');
        elsif rising_edge(clk_25mhz) then
            if h_count = H_TOTAL - 1 then
                if v_count = V_TOTAL - 1 then
                    v_count <= (others => '0');
                else
                    v_count <= v_count + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Generate sync signals
    hsync_int <= '0' when (h_count >= H_DISPLAY + H_FRONT) and 
                          (h_count < H_DISPLAY + H_FRONT + H_SYNC) else '1';
    vsync_int <= '0' when (v_count >= V_DISPLAY + V_FRONT) and 
                          (v_count < V_DISPLAY + V_FRONT + V_SYNC) else '1';
    
    vga_hsync <= hsync_int;
    vga_vsync <= vsync_int;
    
    -- Video on when in display area
    video_on <= '1' when (h_count < H_DISPLAY) and (v_count < V_DISPLAY) else '0';
    
    -- Test pattern: Color bars
    process(clk_25mhz)
    begin
        if rising_edge(clk_25mhz) then
            if video_on = '1' then
                -- Vertical color bars (4-bit per channel)
                if h_count < 80 then
                    vga_r <= x"F"; vga_g <= x"F"; vga_b <= x"F";  -- White
                elsif h_count < 160 then
                    vga_r <= x"F"; vga_g <= x"F"; vga_b <= x"0";  -- Yellow
                elsif h_count < 240 then
                    vga_r <= x"0"; vga_g <= x"F"; vga_b <= x"F";  -- Cyan
                elsif h_count < 320 then
                    vga_r <= x"0"; vga_g <= x"F"; vga_b <= x"0";  -- Green
                elsif h_count < 400 then
                    vga_r <= x"F"; vga_g <= x"0"; vga_b <= x"F";  -- Magenta
                elsif h_count < 480 then
                    vga_r <= x"F"; vga_g <= x"0"; vga_b <= x"0";  -- Red
                elsif h_count < 560 then
                    vga_r <= x"0"; vga_g <= x"0"; vga_b <= x"F";  -- Blue
                else
                    vga_r <= x"0"; vga_g <= x"0"; vga_b <= x"0";  -- Black
                end if;
            else
                vga_r <= x"0";
                vga_g <= x"0";
                vga_b <= x"0";
            end if;
        end if;
    end process;

end Behavioral;
