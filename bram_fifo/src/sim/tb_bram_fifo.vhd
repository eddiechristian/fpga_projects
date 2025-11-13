library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_bram_fifo is
end tb_bram_fifo;

architecture Behavioral of tb_bram_fifo is
    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant DATA_WIDTH : integer := 32;
    constant ADDR_WIDTH : integer := 9;
    constant FIFO_DEPTH : integer := 512;
    
    -- Component declaration
    component bram_fifo is
        Generic (
            DATA_WIDTH : integer := 32;
            FIFO_DEPTH : integer := 512;
            ADDR_WIDTH : integer := 9
        );
        Port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            wr_en   : in  std_logic;
            wr_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            full    : out std_logic;
            rd_en   : in  std_logic;
            rd_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
            empty   : out std_logic
        );
    end component;
    
    -- Signals
    signal clk     : std_logic := '0';
    signal rst     : std_logic := '0';
    signal wr_en   : std_logic := '0';
    signal wr_data : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal full    : std_logic;
    signal rd_en   : std_logic := '0';
    signal rd_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal empty   : std_logic;
    signal state_dd : std_logic_vector(3 downto 0);
    -- Testbench control
    signal test_done : boolean := false;
    
begin
    -- Clock generation
    clk_process : process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- DUT instantiation
    dut : bram_fifo
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FIFO_DEPTH => FIFO_DEPTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk     => clk,
            rst     => rst,
            wr_en   => wr_en,
            wr_data => wr_data,
            full    => full,
            rd_en   => rd_en,
            rd_data => rd_data,
            empty   => empty
        );
    
    -- Stimulus process
    stim_proc : process
        variable expected_data : unsigned(DATA_WIDTH-1 downto 0);
    begin
        state_dd <= B"0000";
        -- Test 1: Reset
        report "Test 1: Reset";
        rst <= '1';
        wait for CLK_PERIOD * 5;
        rst <= '0';
        wait for CLK_PERIOD;
        assert empty = '1' report "FIFO should be empty after reset" severity error;
        assert full = '0' report "FIFO should not be full after reset" severity error;
        state_dd <= B"0001";
        -- Test 2: Write single value
        report "Test 2: Write single value";
        wait for CLK_PERIOD;
        wr_data <= x"DEADBEEF";
        wr_en <= '1';
        wait for CLK_PERIOD;
        wr_en <= '0';
        wait for CLK_PERIOD * 2;
        assert empty = '0' report "FIFO should not be empty after write" severity error;
        state_dd <= B"0010";
        -- Test 3: Read single value
        report "Test 3: Read single value";
        rd_en <= '1';
        wait for CLK_PERIOD;
        rd_en <= '0';
        wait for CLK_PERIOD * 2;
        assert rd_data = x"DEADBEEF" report "Read data mismatch" severity error;
        assert empty = '1' report "FIFO should be empty after reading all data" severity error;
        state_dd <= B"0011";
        -- Test 4: Write multiple values
        report "Test 4: Write 10 sequential values";
        for i in 0 to 9 loop
            wr_data <= std_logic_vector(to_unsigned(i + 100, DATA_WIDTH));
            wr_en <= '1';
            wait for CLK_PERIOD;
        end loop;
        wr_en <= '0';
        wait for CLK_PERIOD * 2;
        state_dd <= B"0100";
        -- Test 5: Read multiple values and verify
        report "Test 5: Read and verify 10 values";
        for i in 0 to 9 loop
            rd_en <= '1';
            wait for CLK_PERIOD;
            rd_en <= '0';
            wait for CLK_PERIOD;
            expected_data := to_unsigned(i + 100, DATA_WIDTH);
            assert rd_data = std_logic_vector(expected_data) 
                report "Read data mismatch at index " & integer'image(i) & 
                       ": expected " & integer'image(to_integer(expected_data)) & 
                       ", got " & integer'image(to_integer(unsigned(rd_data)))
                severity error;
        end loop;
        wait for CLK_PERIOD;
        assert empty = '1' report "FIFO should be empty after reading all data" severity error;
        state_dd <= B"0101";
        -- Test 6: Fill FIFO to capacity
        report "Test 6: Fill FIFO to capacity (512 entries)";
        for i in 0 to FIFO_DEPTH-1 loop
            wr_data <= std_logic_vector(to_unsigned(i, DATA_WIDTH));
            wr_en <= '1';
            wait for CLK_PERIOD;
        end loop;
        wr_en <= '0';
        wait for CLK_PERIOD;
        assert full = '1' report "FIFO should be full after writing 512 entries" severity error;
        state_dd <= B"0110";
        -- Test 7: Try to write when full (should be ignored)
        report "Test 7: Attempt write when full";
        wr_data <= x"FFFFFFFF";
        wr_en <= '1';
        wait for CLK_PERIOD;
        wr_en <= '0';
        wait for CLK_PERIOD;
        state_dd <= B"0111";
        -- Test 8: Read all data from full FIFO
        report "Test 8: Read and verify all 512 entries";
        for i in 0 to FIFO_DEPTH-1 loop
            rd_en <= '1';
            wait for CLK_PERIOD;
            rd_en <= '0';
            wait for CLK_PERIOD;
            expected_data := to_unsigned(i, DATA_WIDTH);
            assert rd_data = std_logic_vector(expected_data)
                report "Read data mismatch at index " & integer'image(i)
                severity error;
        end loop;
        wait for CLK_PERIOD;
        assert empty = '1' report "FIFO should be empty after reading all entries" severity error;
         state_dd <= B"1000";
        -- Test 9: Simultaneous read and write
        report "Test 9: Simultaneous read and write";
        -- First fill with some data
        for i in 0 to 49 loop
            wr_data <= std_logic_vector(to_unsigned(i + 200, DATA_WIDTH));
            wr_en <= '1';
            wait for CLK_PERIOD;
        end loop;
        wr_en <= '0';
        wait for CLK_PERIOD * 2;
        
        -- Now read and write simultaneously
        for i in 0 to 9 loop
            wr_data <= std_logic_vector(to_unsigned(i + 300, DATA_WIDTH));
            wr_en <= '1';
            rd_en <= '1';
            wait for CLK_PERIOD;
        end loop;
        wr_en <= '0';
        rd_en <= '0';
        wait for CLK_PERIOD * 2;
         state_dd <= B"1001";
        -- Test 10: Rapid alternating read/write
        report "Test 10: Rapid alternating read/write";
        for i in 0 to 19 loop
            -- Write
            wr_data <= std_logic_vector(to_unsigned(i + 400, DATA_WIDTH));
            wr_en <= '1';
            rd_en <= '0';
            wait for CLK_PERIOD;
            
            -- Read
            wr_en <= '0';
            rd_en <= '1';
            wait for CLK_PERIOD;
            rd_en <= '0';
            wait for CLK_PERIOD;
        end loop;
        
        wait for CLK_PERIOD * 10;
        
        report "All tests completed successfully!";
        test_done <= true;
        wait;
    end process;

end Behavioral;

