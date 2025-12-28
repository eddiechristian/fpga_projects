library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lin_alg_pkg.all;
use work.ray_tracing_pkg.all;

entity pixel_gen_tb is
end entity pixel_gen_tb;

architecture testbench of pixel_gen_tb is
    
    -- Clock and reset
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;
    
    -- Test control
    signal test_running : boolean := true;
    
    -- Scene setup (hardcoded)
    constant scene : Scene := (
        camera_val => (
            position => (
                x => X"00000000",  -- 0.0
                y => X"C1200000",  -- -10.0
                z => X"00000000"   -- 0.0
            ),
            lookat => VEC3_ZERO,
            up => VEC3_UNIT_Z,
            screen_centre => (
                x => X"00000000",  -- 0.0
                y => X"C1100000",  -- -9.0
                z => X"00000000"   -- 0.0
            ),
            screen_u => (
                x => X"3E800000",  -- 0.25
                y => X"00000000",  -- 0.0
                z => X"00000000"   -- 0.0
            ),
            screen_v => (
                x => X"00000000",  -- 0.0
                y => X"00000000",  -- 0.0
                z => X"3E100000"   -- 0.140625
            )
        )
    );
    
    -- Monitor signals
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
    dut : entity work.pixel_gen_hw
        generic map (
            WIDTH  => 640,
            HEIGHT => 480
        )
        port map (
            clk       => clk,
            reset     => reset,
            scene_val => scene
        );
    
    -- Test stimulus
    stimulus: process
    begin
        -- Hold reset
        reset <= '1';
        wait for 100 ns;
        
        -- Release reset
        reset <= '0';
        report "Pixel generator started - running until manually stopped";
        
        -- Run forever - user must stop simulation manually
        wait;
    end process;
    
    -- Monitor process: Track frame completion and calculate framerate
    monitor: process
        variable prev_x : integer := 0;
        variable prev_y : integer := 0;
        variable start_time : time := 0 ns;
        variable frame_time : time := 0 ns;
        variable elapsed_time : time := 0 ns;
        variable fps : real := 0.0;
    begin
        wait until reset = '0';
        wait for 10 ns;
        
        start_time := now;
        
        loop
            wait until rising_edge(clk);
            
            -- Detect when we wrap from end of frame to start
            if <<signal dut.x_counter : integer>> = 0 and <<signal dut.y_counter : integer>> = 0 and 
               (prev_x /= 0 or prev_y /= 0) then
                frame_count <= frame_count + 1;
                
                -- Report framerate every 100 frames
                if (frame_count + 1) mod 100 = 0 then
                    frame_time := now;
                    elapsed_time := frame_time - start_time;
                    fps := real(100) / (real(elapsed_time / 1 ns) / 1.0e9);
                    report "Frame " & integer'image(frame_count + 1) & " complete | " &
                           "Elapsed: " & time'image(elapsed_time) & " | " &
                           "FPS: " & integer'image(integer(fps)) & "." & 
                           integer'image(integer(abs(fps - real(integer(fps))) * 100.0));
                    start_time := now;
                end if;
            end if;
            
            prev_x := <<signal dut.x_counter : integer>>;
            prev_y := <<signal dut.y_counter : integer>>;
            
            exit when not test_running;
        end loop;
        
        wait;
    end process;
    
    -- Debug process commented out due to type visibility issues
    -- To debug, view signals in waveform viewer instead
    
end architecture testbench;
