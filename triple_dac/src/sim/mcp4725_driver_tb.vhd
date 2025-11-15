library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mcp4725_driver_tb is
end mcp4725_driver_tb;

architecture Behavioral of mcp4725_driver_tb is
    component mcp4725_driver is
        Generic (
            CLK_FREQ    : integer;
            I2C_FREQ    : integer;
            I2C_ADDR    : std_logic_vector(6 downto 0)
        );
        Port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            dac_value   : in  std_logic_vector(11 downto 0);
            update      : in  std_logic;
            busy        : out std_logic;
            done        : out std_logic;
            scl         : inout std_logic;
            sda         : inout std_logic
        );
    end component;
    
    -- Clock and reset
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    
    -- DUT signals
    signal dac_value : std_logic_vector(11 downto 0) := (others => '0');
    signal update : std_logic := '0';
    signal busy : std_logic;
    signal done : std_logic;
    signal scl : std_logic;
    signal sda : std_logic;
    
    -- Simulation control
    signal sim_done : boolean := false;

begin
    -- Clock generation
    clk_proc: process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- I2C pull-ups (simulate external pull-up resistors)
    scl <= 'H';
    sda <= 'H';
    
    -- DUT instantiation
    dut: mcp4725_driver
        generic map (
            CLK_FREQ => 100_000_000,
            I2C_FREQ => 400_000,  -- Fast mode for faster simulation
            I2C_ADDR => "1100000"  -- 0x60
        )
        port map (
            clk       => clk,
            rst       => rst,
            dac_value => dac_value,
            update    => update,
            busy      => busy,
            done      => done,
            scl       => scl,
            sda       => sda
        );
    
    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        rst <= '1';
        update <= '0';
        dac_value <= x"000";
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;
        
        report "Starting MCP4725 driver test";
        
        -- Test 1: Send minimum value (0x000)
        report "Test 1: Sending DAC value 0x000";
        dac_value <= x"000";
        wait for 20 ns;
        update <= '1';
        wait for 20 ns;
        update <= '0';
        
        wait until done = '1';
        wait for 100 ns;
        report "Test 1 complete";
        
        -- Test 2: Send mid-scale value (0x800)
        report "Test 2: Sending DAC value 0x800";
        dac_value <= x"800";
        wait for 20 ns;
        update <= '1';
        wait for 20 ns;
        update <= '0';
        
        wait until done = '1';
        wait for 100 ns;
        report "Test 2 complete";
        
        -- Test 3: Send maximum value (0xFFF)
        report "Test 3: Sending DAC value 0xFFF";
        dac_value <= x"FFF";
        wait for 20 ns;
        update <= '1';
        wait for 20 ns;
        update <= '0';
        
        wait until done = '1';
        wait for 100 ns;
        report "Test 3 complete";
        
        -- Test 4: Rapid updates
        report "Test 4: Rapid sequential updates";
        for i in 0 to 3 loop
            dac_value <= std_logic_vector(to_unsigned(i * 1024, 12));
            wait for 20 ns;
            update <= '1';
            wait for 20 ns;
            update <= '0';
            wait until done = '1';
            wait for 50 ns;
        end loop;
        report "Test 4 complete";
        
        -- End simulation
        wait for 1 us;
        report "All tests completed successfully!";
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor process
    monitor_proc: process(clk)
    begin
        if rising_edge(clk) then
            if done = '1' then
                report "DAC update completed for value: " & 
                       integer'image(to_integer(unsigned(dac_value)));
            end if;
        end if;
    end process;

end Behavioral;
