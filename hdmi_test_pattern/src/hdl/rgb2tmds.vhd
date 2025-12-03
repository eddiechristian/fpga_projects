library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rgb2tmds is
    Port ( 
        clk_pixel : in STD_LOGIC;      -- Pixel clock (25.175 MHz for 640x480)
        reset : in STD_LOGIC;
        
        -- Video input
        video_data : in STD_LOGIC_VECTOR(11 downto 0);  -- RGB444 (4:4:4)
        video_active : in STD_LOGIC;
        hsync : in STD_LOGIC;
        vsync : in STD_LOGIC;
        
        -- TMDS outputs (serialized)
        tmds_clk_p : out STD_LOGIC;
        tmds_clk_n : out STD_LOGIC;
        tmds_data_p : out STD_LOGIC_VECTOR(2 downto 0);
        tmds_data_n : out STD_LOGIC_VECTOR(2 downto 0)
    );
end rgb2tmds;

architecture Behavioral of rgb2tmds is
    
    -- TMDS encoding functions
    function tmds_encode(data_in : std_logic_vector(7 downto 0);
                         c0, c1 : std_logic;
                         active : std_logic) return std_logic_vector is
        variable encoded : std_logic_vector(9 downto 0);
        variable n1 : integer;
        variable data_xor, data_xnor : std_logic_vector(8 downto 0);
        variable ctrl : std_logic_vector(1 downto 0);
    begin
        if active = '0' then
            -- Control period
            ctrl := c1 & c0;
            case ctrl is
                when "00" => encoded := "1101010100";
                when "01" => encoded := "0010101011";
                when "10" => encoded := "0101010100";
                when others => encoded := "1010101011";
            end case;
        else
            -- Video data period - simplified TMDS encoding
            -- Count ones in data
            n1 := 0;
            for i in 0 to 7 loop
                if data_in(i) = '1' then
                    n1 := n1 + 1;
                end if;
            end loop;
            
            -- Use XOR or XNOR based on transition minimization
            if n1 > 4 or (n1 = 4 and data_in(0) = '0') then
                -- Use XNOR
                data_xnor(0) := data_in(0);
                for i in 1 to 7 loop
                    data_xnor(i) := data_xnor(i-1) xnor data_in(i);
                end loop;
                data_xnor(8) := '1';  -- XNOR encoding flag
                encoded := data_xnor & '0';
            else
                -- Use XOR
                data_xor(0) := data_in(0);
                for i in 1 to 7 loop
                    data_xor(i) := data_xor(i-1) xor data_in(i);
                end loop;
                data_xor(8) := '0';  -- XOR encoding flag  
                encoded := data_xor & '1';
            end if;
        end if;
        
        return encoded;
    end function;
    
    -- Signals
    signal red_8bit, green_8bit, blue_8bit : std_logic_vector(7 downto 0);
    signal tmds_red, tmds_green, tmds_blue : std_logic_vector(9 downto 0);
    
    -- Note: For production design, OSERDESE2 primitives should be used for proper serialization
    -- This simplified version outputs parallel TMDS data
    
    -- OBUFDS for differential output
    component OBUFDS
        port (
            I : in std_logic;
            O : out std_logic;
            OB : out std_logic
        );
    end component;
    
begin
    
    -- Expand 4-bit color to 8-bit (replicate high nibble to low nibble)
    red_8bit <= video_data(11 downto 8) & video_data(11 downto 8);
    green_8bit <= video_data(7 downto 4) & video_data(7 downto 4);
    blue_8bit <= video_data(3 downto 0) & video_data(3 downto 0);
    
    -- TMDS encoding (done in pixel clock domain)
    process(clk_pixel, reset)
    begin
        if reset = '1' then
            tmds_red <= (others => '0');
            tmds_green <= (others => '0');
            tmds_blue <= (others => '0');
        elsif rising_edge(clk_pixel) then
            -- Channel 0 (Blue) carries hsync/vsync during blanking
            tmds_blue <= tmds_encode(blue_8bit, hsync, vsync, video_active);
            -- Channel 1 (Green)
            tmds_green <= tmds_encode(green_8bit, '0', '0', video_active);
            -- Channel 2 (Red)
            tmds_red <= tmds_encode(red_8bit, '0', '0', video_active);
        end if;
    end process;
    
    -- Simple differential output without proper serialization
    -- This won't produce a fully compliant HDMI signal but may work for testing
    
    obuf_clk : OBUFDS
        port map (
            I => clk_pixel,
            O => tmds_clk_p,
            OB => tmds_clk_n
        );
    
    obuf_data0 : OBUFDS
        port map (
            I => tmds_blue(0),
            O => tmds_data_p(0),
            OB => tmds_data_n(0)
        );
    
    obuf_data1 : OBUFDS
        port map (
            I => tmds_green(0),
            O => tmds_data_p(1),
            OB => tmds_data_n(1)
        );
    
    obuf_data2 : OBUFDS
        port map (
            I => tmds_red(0),
            O => tmds_data_p(2),
            OB => tmds_data_n(2)
        );
    
end Behavioral;
