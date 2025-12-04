library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.vec3_pkg.all;

entity vec3_normalize_tb is
end vec3_normalize_tb;

architecture behavioral of vec3_normalize_tb is
    
    -- Component declarations
    component vec3_sub_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            a         : in  Vec3;
            b         : in  Vec3;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    component vec3_normalize_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            v         : in  Vec3;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    -- Clock and control
    constant CLK_PERIOD : time := 10 ns;
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal sim_done     : boolean := false;
    
    -- Camera vectors (matching camera.vhd defaults)
    -- m_cameraPosition = (0, -10, 0)
    constant m_cameraPosition : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"C1200000",  -- -10.0
        z => X"00000000"   -- 0.0
    );
    
    -- m_cameraLookAt = (0, 0, 0)
    constant m_cameraLookAt : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"00000000",  -- 0.0
        z => X"00000000"   -- 0.0
    );
    
    -- Subtraction signals (lookAt - position)
    signal sub_valid_in  : std_logic := '0';
    signal sub_result    : Vec3;
    signal sub_valid_out : std_logic;
    
    -- Normalization signals
    signal norm_valid_in  : std_logic := '0';
    signal norm_result    : Vec3;
    signal norm_valid_out : std_logic;
    
begin
    
    -- Instantiate subtraction unit
    -- Compute alignment_vector = lookAt - position
    sub_inst : vec3_sub_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => sub_valid_in,
            a         => m_cameraLookAt,
            b         => m_cameraPosition,
            result    => sub_result,
            valid_out => sub_valid_out
        );
    
    -- Instantiate normalization unit (separate, independent)
    -- Normalize the alignment vector
    norm_inst : vec3_normalize_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => norm_valid_in,
            v         => sub_result,
            result    => norm_result,
            valid_out => norm_valid_out
        );
    
    -- Clock generation
    clk_process : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Stimulus process
    stim_proc : process
    begin
        -- Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 50 ns;
        
        report "Starting Vec3 Normalize Test";
        report "Camera Position: (0, -10, 0)";
        report "Camera LookAt:   (0, 0, 0)";
        
        -- Test: Compute lookAt - position
        report "Computing alignment_vector = lookAt - position";
        sub_valid_in <= '1';
        wait for CLK_PERIOD;
        sub_valid_in <= '0';
        
        -- Wait for subtraction to complete (11 cycles)
        wait for 120 ns;
        
        -- Expected result: (0, 0, 0) - (0, -10, 0) = (0, 10, 0)
        report "Subtraction complete. Expected: (0, 10, 0)";
        
        -- Now normalize the result
        -- Wait a bit to see the subtraction result clearly in waveform
        wait for 100 ns;
        
        report "Computing normalized alignment_vector";
        norm_valid_in <= '1';
        wait for CLK_PERIOD;
        norm_valid_in <= '0';
        
        -- Wait for normalization to complete (94 cycles)
        wait for 1000 ns;
        
        -- Expected result: (0, 10, 0) normalized = (0, 1, 0)
        report "Normalization complete. Expected: (0, 1, 0)";
        
        -- Keep running a bit to see final result
        wait for 200 ns;
        
        report "Test complete";
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor subtraction output
    monitor_sub : process(sub_valid_out)
    begin
        if sub_valid_out = '1' then
            report "SUB OUTPUT VALID - Alignment vector computed";
            report "  X component: 0x" & to_hstring(unsigned(sub_result.x));
            report "  Y component: 0x" & to_hstring(unsigned(sub_result.y));
            report "  Z component: 0x" & to_hstring(unsigned(sub_result.z));
        end if;
    end process;
    
    -- Monitor normalization output
    monitor_norm : process(norm_valid_out)
    begin
        if norm_valid_out = '1' then
            report "NORMALIZE OUTPUT VALID - Unit vector computed";
            report "  X component: 0x" & to_hstring(unsigned(norm_result.x));
            report "  Y component: 0x" & to_hstring(unsigned(norm_result.y));
            report "  Z component: 0x" & to_hstring(unsigned(norm_result.z));
        end if;
    end process;
    
end architecture behavioral;
