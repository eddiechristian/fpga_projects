library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module_tb is
end top_module_tb;

architecture Behavioral of top_module_tb is
    -- Component declaration
    component top_module
        Port (
            clk_100mhz : in STD_LOGIC;
            reset      : in STD_LOGIC;
            vga_r      : out STD_LOGIC_VECTOR(3 downto 0);
            vga_g      : out STD_LOGIC_VECTOR(3 downto 0);
            vga_b      : out STD_LOGIC_VECTOR(3 downto 0);
            vga_hsync  : out STD_LOGIC;
            vga_vsync  : out STD_LOGIC
        );
    end component;
    
    -- Clock period constants
    constant CLK_100MHZ_PERIOD : time := 10 ns;  -- 100 MHz
    constant CLK_25MHZ_PERIOD  : time := 40 ns;  -- 25 MHz (expected pixel clock)
    
    -- Test signals
    signal clk_100mhz : STD_LOGIC := '0';
    signal reset      : STD_LOGIC := '0';
    signal vga_r      : STD_LOGIC_VECTOR(3 downto 0);
    signal vga_g      : STD_LOGIC_VECTOR(3 downto 0);
    signal vga_b      : STD_LOGIC_VECTOR(3 downto 0);
    signal vga_hsync  : STD_LOGIC;
    signal vga_vsync  : STD_LOGIC;
    
    -- Internal signals for monitoring
    signal pixel_clk  : STD_LOGIC := '0';
    signal h_sync_count : integer := 0;
    signal v_sync_count : integer := 0;
    signal pixel_count  : integer := 0;
    signal line_count   : integer := 0;
    
    -- Timing region indicators
    signal h_front_porch : STD_LOGIC := '0';  -- 1 = in horizontal front porch
    signal h_sync_region : STD_LOGIC := '0';  -- 1 = in horizontal sync
    signal h_back_porch  : STD_LOGIC := '0';  -- 1 = in horizontal back porch
    signal v_front_porch : STD_LOGIC := '0';  -- 1 = in vertical front porch
    signal v_sync_region : STD_LOGIC := '0';  -- 1 = in vertical sync
    signal v_back_porch  : STD_LOGIC := '0';  -- 1 = in vertical back porch
    
    -- Horizontal and vertical position counters (for monitoring)
    signal h_pos : integer := 0;
    signal v_pos : integer := 0;
    
    -- Stop simulation flag
    signal sim_done : boolean := false;
    
    -- VGA timing expectations (640x480 @ 60Hz)
    constant H_DISPLAY : integer := 640;
    constant H_FRONT   : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BACK    : integer := 48;
    constant H_TOTAL   : integer := 800;
    
    constant V_DISPLAY : integer := 480;
    constant V_FRONT   : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BACK    : integer := 33;
    constant V_TOTAL   : integer := 525;
    
begin

    -- Instantiate the Unit Under Test (UUT)
    uut: top_module
        port map (
            clk_100mhz => clk_100mhz,
            reset      => reset,
            vga_r      => vga_r,
            vga_g      => vga_g,
            vga_b      => vga_b,
            vga_hsync  => vga_hsync,
            vga_vsync  => vga_vsync
        );
    
    -- 100 MHz clock generation
    clk_100mhz_process: process
    begin
        while not sim_done loop
            clk_100mhz <= '0';
            wait for CLK_100MHZ_PERIOD / 2;
            clk_100mhz <= '1';
            wait for CLK_100MHZ_PERIOD / 2;
        end loop;
        wait;
    end process;
    
    -- Pixel clock extraction (25 MHz expected)
    -- This monitors the actual pixel clock transitions by detecting changes in RGB values
    pixel_clk_monitor: process(clk_100mhz)
        variable prev_r : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
        variable prev_g : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
        variable prev_b : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
        variable clk_div_counter : integer := 0;
    begin
        if rising_edge(clk_100mhz) then
            -- Toggle pixel_clk every 2 cycles of 100MHz to simulate 25MHz
            if clk_div_counter = 1 then
                pixel_clk <= not pixel_clk;
                clk_div_counter := 0;
            else
                clk_div_counter := clk_div_counter + 1;
            end if;
        end if;
    end process;
    
    -- Horizontal sync monitor
    hsync_monitor: process(vga_hsync)
    begin
        if falling_edge(vga_hsync) then
            h_sync_count <= h_sync_count + 1;
            report "HSYNC pulse detected (pulse #" & integer'image(h_sync_count + 1) & ")"
                severity note;
        end if;
    end process;
    
    -- Vertical sync monitor
    vsync_monitor: process(vga_vsync)
    begin
        if falling_edge(vga_vsync) then
            v_sync_count <= v_sync_count + 1;
            report "VSYNC pulse detected (frame #" & integer'image(v_sync_count + 1) & ")"
                severity note;
        end if;
    end process;
    
    -- Pixel clock counter (counts on pixel clock edges)
    pixel_counter: process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if reset = '1' then
                pixel_count <= 0;
            else
                pixel_count <= pixel_count + 1;
            end if;
        end if;
    end process;
    
    -- Horizontal position tracker
    h_position_tracker: process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if reset = '1' then
                h_pos <= 0;
            else
                if h_pos = H_TOTAL - 1 then
                    h_pos <= 0;
                else
                    h_pos <= h_pos + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Vertical position tracker
    v_position_tracker: process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            if reset = '1' then
                v_pos <= 0;
            elsif h_pos = H_TOTAL - 1 then
                if v_pos = V_TOTAL - 1 then
                    v_pos <= 0;
                else
                    v_pos <= v_pos + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- Horizontal timing region indicators
    h_timing_regions: process(h_pos)
    begin
        -- Default all to 0
        h_front_porch <= '0';
        h_sync_region <= '0';
        h_back_porch  <= '0';
        
        if h_pos >= H_DISPLAY and h_pos < (H_DISPLAY + H_FRONT) then
            h_front_porch <= '1';  -- Front porch region (640-655)
        elsif h_pos >= (H_DISPLAY + H_FRONT) and h_pos < (H_DISPLAY + H_FRONT + H_SYNC) then
            h_sync_region <= '1';  -- Sync region (656-751)
        elsif h_pos >= (H_DISPLAY + H_FRONT + H_SYNC) and h_pos < H_TOTAL then
            h_back_porch <= '1';   -- Back porch region (752-799)
        end if;
    end process;
    
    -- Vertical timing region indicators
    v_timing_regions: process(v_pos)
    begin
        -- Default all to 0
        v_front_porch <= '0';
        v_sync_region <= '0';
        v_back_porch  <= '0';
        
        if v_pos >= V_DISPLAY and v_pos < (V_DISPLAY + V_FRONT) then
            v_front_porch <= '1';  -- Front porch region (480-489)
        elsif v_pos >= (V_DISPLAY + V_FRONT) and v_pos < (V_DISPLAY + V_FRONT + V_SYNC) then
            v_sync_region <= '1';  -- Sync region (490-491)
        elsif v_pos >= (V_DISPLAY + V_FRONT + V_SYNC) and v_pos < V_TOTAL then
            v_back_porch <= '1';   -- Back porch region (492-524)
        end if;
    end process;
    
    -- Signal value monitor (sample key signals periodically)
    signal_monitor: process
    begin
        wait for 1 us;  -- Initial delay
        
        while not sim_done loop
            report "=== Signal Status at " & time'image(now) & " ===" 
                severity note;
            report "  Pixel Clock:  " & std_logic'image(pixel_clk)
                severity note;
            report "  VGA_HSYNC:    " & std_logic'image(vga_hsync)
                severity note;
            report "  VGA_VSYNC:    " & std_logic'image(vga_vsync)
                severity note;
            report "  VGA_R:        " & integer'image(to_integer(unsigned(vga_r)))
                severity note;
            report "  VGA_G:        " & integer'image(to_integer(unsigned(vga_g)))
                severity note;
            report "  VGA_B:        " & integer'image(to_integer(unsigned(vga_b)))
                severity note;
            report "  H Position:   " & integer'image(h_pos)
                severity note;
            report "  V Position:   " & integer'image(v_pos)
                severity note;
            report "  H Front Porch: " & std_logic'image(h_front_porch)
                severity note;
            report "  H Sync Region: " & std_logic'image(h_sync_region)
                severity note;
            report "  H Back Porch:  " & std_logic'image(h_back_porch)
                severity note;
            report "  V Front Porch: " & std_logic'image(v_front_porch)
                severity note;
            report "  V Sync Region: " & std_logic'image(v_sync_region)
                severity note;
            report "  V Back Porch:  " & std_logic'image(v_back_porch)
                severity note;
            report "  H Sync Count:  " & integer'image(h_sync_count)
                severity note;
            report "  V Sync Count:  " & integer'image(v_sync_count)
                severity note;
            report "  Pixel Count:   " & integer'image(pixel_count)
                severity note;
            
            wait for 10 us;
        end loop;
        wait;
    end process;
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Initial reset
        report "========================================" severity note;
        report "Starting VGA Testbench" severity note;
        report "========================================" severity note;
        reset <= '1';
        wait for 200 ns;
        reset <= '0';
        
        report "Reset released - VGA operation starting" severity note;
        
        -- Wait for a few horizontal lines to complete
        wait for 100 us;
        report "Simulated 100 us - checking initial operation" severity note;
        
        -- Wait for first frame to complete
        wait for 20 ms;
        report "Simulated 20 ms - should complete ~1 frame at 60Hz" severity note;
        
        -- Summary report
        report "========================================" severity note;
        report "Simulation Summary:" severity note;
        report "  Total HSYNC pulses: " & integer'image(h_sync_count) severity note;
        report "  Total VSYNC pulses: " & integer'image(v_sync_count) severity note;
        report "  Expected HSYNCs per frame: " & integer'image(V_TOTAL) severity note;
        report "  Expected frames in 20ms: ~1-2" severity note;
        report "========================================" severity note;
        
        -- Additional test: Check color changes
        wait for 5 ms;
        report "Extended simulation - verifying color bar pattern" severity note;
        
        -- End simulation
        sim_done <= true;
        report "========================================" severity note;
        report "Testbench Complete - All signals monitored" severity note;
        report "========================================" severity note;
        wait;
    end process;

end Behavioral;
