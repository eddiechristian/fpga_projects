library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_timing is
    Port ( 
        clk : in STD_LOGIC;
        red : out STD_LOGIC_VECTOR(7 downto 0);
        green : out STD_LOGIC_VECTOR(7 downto 0);
        blue : out STD_LOGIC_VECTOR(7 downto 0);
        hsync : out STD_LOGIC;
        vsync : out STD_LOGIC;
        video_active : out STD_LOGIC;
        led : out STD_LOGIC
    );
end vga_timing;

architecture Behavioral of vga_timing is
    -- 640x480 @ 60Hz timing
    constant H_ACTIVE : integer := 640;
    constant H_FP : integer := 16;
    constant H_SYNC : integer := 96;
    constant H_BP : integer := 48;
    constant H_TOTAL : integer := 800;
    
    constant V_ACTIVE : integer := 480;
    constant V_FP : integer := 10;
    constant V_SYNC : integer := 2;
    constant V_BP : integer := 33;
    constant V_TOTAL : integer := 525;
    
    signal h_count : integer range 0 to H_TOTAL-1 := 0;
    signal v_count : integer range 0 to V_TOTAL-1 := 0;
    signal active : std_logic;
    
begin
    
    process(clk)
    begin
        if rising_edge(clk) then
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
            
            -- Generate sync signals
            if h_count >= (H_ACTIVE + H_FP) and h_count < (H_ACTIVE + H_FP + H_SYNC) then
                hsync <= '0';
            else
                hsync <= '1';
            end if;
            
            if v_count >= (V_ACTIVE + V_FP) and v_count < (V_ACTIVE + V_FP + V_SYNC) then
                vsync <= '0';
            else
                vsync <= '1';
            end if;
            
            -- Active video region
            if h_count < H_ACTIVE and v_count < V_ACTIVE then
                active <= '1';
                -- Color bars - 8 vertical bars
                if h_count < 80 then
                    red <= x"FF"; green <= x"FF"; blue <= x"FF";  -- White
                elsif h_count < 160 then
                    red <= x"FF"; green <= x"FF"; blue <= x"00";  -- Yellow
                elsif h_count < 240 then
                    red <= x"00"; green <= x"FF"; blue <= x"FF";  -- Cyan
                elsif h_count < 320 then
                    red <= x"00"; green <= x"FF"; blue <= x"00";  -- Green
                elsif h_count < 400 then
                    red <= x"FF"; green <= x"00"; blue <= x"FF";  -- Magenta
                elsif h_count < 480 then
                    red <= x"FF"; green <= x"00"; blue <= x"00";  -- Red
                elsif h_count < 560 then
                    red <= x"00"; green <= x"00"; blue <= x"FF";  -- Blue
                else
                    red <= x"00"; green <= x"00"; blue <= x"00";  -- Black
                end if;
            else
                active <= '0';
                red <= x"00";
                green <= x"00";
                blue <= x"00";
            end if;
            
        end if;
    end process;
    
    video_active <= active;
    led <= active;  -- Blink LED with active video
    
end Behavioral;
