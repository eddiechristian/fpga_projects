library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module_raytracer_tb is
end entity top_module_raytracer_tb;

architecture testbench of top_module_raytracer_tb is
    
    -- Clock and reset
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- DUT signals
    signal frame_done : std_logic;
    
    -- Test control
    signal test_running : boolean := true;
    
    -- Monitoring
    signal frame_count : integer := 0;
    
begin
    
    -- Clock generation
    clk_process: process
    begin
        while test_running loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- DUT instantiation
    dut : entity work.top_module_raytracer
        port map (
            clk        => clk,
            rst        => rst,
            frame_done => frame_done
        );
    
    -- Test stimulus
    stimulus: process
    begin
        -- Hold reset
        rst <= '1';
        wait for 200 ns;
        
        -- Release reset
        rst <= '0';
        report "=== Ray tracer started ===";
        
        -- Run until user stops
        wait;
    end process;
    
    -- Frame monitor
    monitor: process
        variable elapsed : time;
        variable fps : real;
        variable start_time : time := 0 ns;
        variable frame_time : time := 0 ns;
    begin
        wait until rst = '0';
        wait for 10 ns;
        
        start_time := now;
        
        loop
            wait until rising_edge(clk);
            
            -- Detect frame completion
            if frame_done = '1' then
                frame_count <= frame_count + 1;
                frame_time := now;
                elapsed := frame_time - start_time;
                
                -- Calculate FPS
                if elapsed > 0 ns then
                    fps := real(frame_count + 1) / (real(elapsed / 1 ns) / 1.0e9);
                    
                    report "=== FRAME " & integer'image(frame_count + 1) & " COMPLETE ===" & LF &
                           "  Elapsed time: " & time'image(elapsed) & LF &
                           "  Average FPS: " & integer'image(integer(fps));
                end if;
                
                -- Reset timer for next frame rate calculation
                if (frame_count + 1) mod 10 = 0 then
                    start_time := now;
                    frame_count <= 0;
                end if;
            end if;
            
            exit when not test_running;
        end loop;
        
        wait;
    end process;
    
end architecture testbench;
