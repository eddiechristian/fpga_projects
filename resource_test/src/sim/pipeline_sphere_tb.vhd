library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- Simplified testbench that mimics sphere intersection workload
-- 3 spheres submit sequential operations: normalize → dot → mult → add → compare
entity pipeline_sphere_tb is
end pipeline_sphere_tb;

architecture Behavioral of pipeline_sphere_tb is

    constant CLK_PERIOD : time := 10 ns;
    constant NUM_MULT_UNITS : integer := 8;
    constant NUM_FMA_UNITS : integer := 5;
    constant NUM_ADD_UNITS : integer := 3;
    constant NUM_PRODUCERS : integer := 5;
    constant NUM_SPHERES : integer := 3;
    
    component pipeline_hw is
        generic (
            NUM_MULT_UNITS    : integer := 8;
            NUM_FMA_UNITS     : integer := 5;
            NUM_ADD_UNITS     : integer := 3;
            NUM_PRODUCERS     : integer := 5;
            FIFO_DEPTH        : integer := 32
        );
        port (
            clk_in      : in  std_logic;
            reset       : in  std_logic;
            mult_wr_data  : in  std_logic_vector(NUM_MULT_UNITS*64-1 downto 0);
            mult_wr_tid   : in  std_logic_vector(NUM_MULT_UNITS*16-1 downto 0);
            mult_wr_valid : in  std_logic_vector(NUM_MULT_UNITS-1 downto 0);
            mult_wr_ready : out std_logic_vector(NUM_MULT_UNITS-1 downto 0);
            fma_wr_data  : in  std_logic_vector(NUM_FMA_UNITS*96-1 downto 0);
            fma_wr_tid   : in  std_logic_vector(NUM_FMA_UNITS*16-1 downto 0);
            fma_wr_valid : in  std_logic_vector(NUM_FMA_UNITS-1 downto 0);
            fma_wr_ready : out std_logic_vector(NUM_FMA_UNITS-1 downto 0);
            addsub_wr_data  : in  std_logic_vector(NUM_ADD_UNITS*65-1 downto 0);
            addsub_wr_tid   : in  std_logic_vector(NUM_ADD_UNITS*16-1 downto 0);
            addsub_wr_valid : in  std_logic_vector(NUM_ADD_UNITS-1 downto 0);
            addsub_wr_ready : out std_logic_vector(NUM_ADD_UNITS-1 downto 0);
            output_rd_data  : out std_logic_vector(NUM_PRODUCERS*32-1 downto 0);
            output_rd_tid   : out std_logic_vector(NUM_PRODUCERS*16-1 downto 0);
            output_rd_valid : out std_logic_vector(NUM_PRODUCERS-1 downto 0);
            output_rd_ready : in  std_logic_vector(NUM_PRODUCERS-1 downto 0);
            clk_locked : out std_logic
        );
    end component;
    
    signal clk_in : std_logic := '0';
    signal reset : std_logic := '1';
    signal clk_locked : std_logic;
    
    signal mult_wr_data  : std_logic_vector(NUM_MULT_UNITS*64-1 downto 0) := (others => '0');
    signal mult_wr_tid   : std_logic_vector(NUM_MULT_UNITS*16-1 downto 0) := (others => '0');
    signal mult_wr_valid : std_logic_vector(NUM_MULT_UNITS-1 downto 0) := (others => '0');
    signal mult_wr_ready : std_logic_vector(NUM_MULT_UNITS-1 downto 0);
    
    signal fma_wr_data  : std_logic_vector(NUM_FMA_UNITS*96-1 downto 0) := (others => '0');
    signal fma_wr_tid   : std_logic_vector(NUM_FMA_UNITS*16-1 downto 0) := (others => '0');
    signal fma_wr_valid : std_logic_vector(NUM_FMA_UNITS-1 downto 0) := (others => '0');
    signal fma_wr_ready : std_logic_vector(NUM_FMA_UNITS-1 downto 0);
    
    signal addsub_wr_data  : std_logic_vector(NUM_ADD_UNITS*65-1 downto 0) := (others => '0');
    signal addsub_wr_tid   : std_logic_vector(NUM_ADD_UNITS*16-1 downto 0) := (others => '0');
    signal addsub_wr_valid : std_logic_vector(NUM_ADD_UNITS-1 downto 0) := (others => '0');
    signal addsub_wr_ready : std_logic_vector(NUM_ADD_UNITS-1 downto 0);
    
    signal output_rd_data  : std_logic_vector(NUM_PRODUCERS*32-1 downto 0);
    signal output_rd_tid   : std_logic_vector(NUM_PRODUCERS*16-1 downto 0);
    signal output_rd_valid : std_logic_vector(NUM_PRODUCERS-1 downto 0);
    signal output_rd_ready : std_logic_vector(NUM_PRODUCERS-1 downto 0) := (others => '1');
    
    signal sim_done : boolean := false;
    type sphere_state_t is (IDLE, SUBMIT_OP1, WAIT_OP1, SUBMIT_OP2, WAIT_OP2, DONE);
    type sphere_states_t is array (0 to NUM_SPHERES-1) of sphere_state_t;
    signal sphere_states : sphere_states_t := (others => IDLE);
    
    function to_fp32(val : real) return std_logic_vector is
        variable result : std_logic_vector(31 downto 0);
        variable exp_int : integer;
    begin
        if val = 0.0 then
            return x"00000000";
        end if;
        exp_int := integer(floor(log2(abs(val))));
        result := std_logic_vector(to_unsigned(127 + exp_int, 8)) & x"000000";
        return result;
    end function;
    
    function from_fp32(fp : std_logic_vector(31 downto 0)) return real is
        variable exponent : integer;
    begin
        exponent := to_integer(unsigned(fp(30 downto 23))) - 127;
        return 2.0 ** real(exponent);
    end function;

begin

    clk_in <= not clk_in after CLK_PERIOD / 2 when not sim_done else '0';
    
    dut : pipeline_hw
        generic map (
            NUM_MULT_UNITS => NUM_MULT_UNITS,
            NUM_FMA_UNITS  => NUM_FMA_UNITS,
            NUM_ADD_UNITS  => NUM_ADD_UNITS,
            NUM_PRODUCERS  => NUM_PRODUCERS,
            FIFO_DEPTH     => 32
        )
        port map (
            clk_in          => clk_in,
            reset           => reset,
            mult_wr_data    => mult_wr_data,
            mult_wr_tid     => mult_wr_tid,
            mult_wr_valid   => mult_wr_valid,
            mult_wr_ready   => mult_wr_ready,
            fma_wr_data     => fma_wr_data,
            fma_wr_tid      => fma_wr_tid,
            fma_wr_valid    => fma_wr_valid,
            fma_wr_ready    => fma_wr_ready,
            addsub_wr_data  => addsub_wr_data,
            addsub_wr_tid   => addsub_wr_tid,
            addsub_wr_valid => addsub_wr_valid,
            addsub_wr_ready => addsub_wr_ready,
            output_rd_data  => output_rd_data,
            output_rd_tid   => output_rd_tid,
            output_rd_valid => output_rd_valid,
            output_rd_ready => output_rd_ready,
            clk_locked      => clk_locked
        );
    
    -- Sphere 0: Submits 2 sequential operations
    sphere_0 : process
        variable tid : std_logic_vector(15 downto 0);
    begin
        wait until reset = '0' and clk_locked = '1';
        wait for 50 ns;
        
        report "=== Sphere 0 starting ===";
        
        -- Operation 1: MULT (a * b) = 2.0 * 3.0 = 6.0, with TID = 0 (sphere_id=0, op=0)
        tid := std_logic_vector(to_unsigned(0 * 8192 + 0, 16));
        mult_wr_data(63 downto 0) <= x"40400000" & x"40000000";  -- 3.0, 2.0
        mult_wr_tid(15 downto 0) <= tid;
        mult_wr_valid(0) <= '1';
        wait until rising_edge(clk_in);
        mult_wr_valid(0) <= '0';
        report "Sphere 0: Submitted MULT op, TID=" & integer'image(to_integer(unsigned(tid)));
        
        -- Wait for result
        wait until output_rd_valid(0) = '1';
        report "Sphere 0: Got result! TID=" & integer'image(to_integer(unsigned(output_rd_tid(15 downto 0)))) &
               " Value=" & real'image(from_fp32(output_rd_data(31 downto 0)));
        
        -- Operation 2: FMA (a*b + c) = 1.0*4.0 + 5.0 = 9.0, with TID = 1
        tid := std_logic_vector(to_unsigned(0 * 8192 + 1, 16));
        wait for 30 ns;  -- Align to clock edge
        wait until rising_edge(clk_in);
        wait for 1 ns;  -- Delta delay after clock
        fma_wr_data(95 downto 0) <= x"40A00000" & x"40800000" & x"3F800000";  -- 5.0, 4.0, 1.0
        fma_wr_tid(15 downto 0) <= tid;
        fma_wr_valid(0) <= '1';
        wait until rising_edge(clk_in);
        fma_wr_valid(0) <= '0';
        report "Sphere 0: Submitted FMA op, TID=" & integer'image(to_integer(unsigned(tid)));
        
        wait until output_rd_valid(0) = '1';
        report "Sphere 0: Got result! TID=" & integer'image(to_integer(unsigned(output_rd_tid(15 downto 0)))) &
               " Value=" & real'image(from_fp32(output_rd_data(31 downto 0)));
        
        report "=== Sphere 0 DONE ===";
        wait;
    end process;
    
    -- Sphere 1: Submits 2 sequential operations
    sphere_1 : process
        variable tid : std_logic_vector(15 downto 0);
    begin
        wait until reset = '0' and clk_locked = '1';
        wait for 100 ns;
        
        report "=== Sphere 1 starting ===";
        
        -- Operation 1: MULT = 7.0 * 8.0 = 56.0, with TID = 8192 (sphere_id=1, op=0)
        tid := std_logic_vector(to_unsigned(1 * 8192 + 0, 16));
        mult_wr_data(127 downto 64) <= x"41000000" & x"40E00000";  -- 8.0, 7.0
        mult_wr_tid(31 downto 16) <= tid;
        mult_wr_valid(1) <= '1';
        wait until rising_edge(clk_in);
        mult_wr_valid(1) <= '0';
        report "Sphere 1: Submitted MULT op, TID=" & integer'image(to_integer(unsigned(tid)));
        
        wait until output_rd_valid(1) = '1';
        report "Sphere 1: Got result! TID=" & integer'image(to_integer(unsigned(output_rd_tid(31 downto 16)))) &
               " Value=" & real'image(from_fp32(output_rd_data(63 downto 32)));
        
        -- Operation 2: FMA = 2.0*9.0 + 10.0 = 28.0, with TID = 8193
        tid := std_logic_vector(to_unsigned(1 * 8192 + 1, 16));
        wait for 30 ns;  -- Align to clock edge
        wait until rising_edge(clk_in);
        wait for 1 ns;  -- Delta delay after clock
        fma_wr_data(191 downto 96) <= x"41200000" & x"41100000" & x"40000000";  -- 10.0, 9.0, 2.0
        fma_wr_tid(31 downto 16) <= tid;
        fma_wr_valid(1) <= '1';
        wait until rising_edge(clk_in);
        fma_wr_valid(1) <= '0';
        report "Sphere 1: Submitted FMA op, TID=" & integer'image(to_integer(unsigned(tid)));
        
        wait until output_rd_valid(1) = '1';
        report "Sphere 1: Got result! TID=" & integer'image(to_integer(unsigned(output_rd_tid(31 downto 16)))) &
               " Value=" & real'image(from_fp32(output_rd_data(63 downto 32)));
        
        report "=== Sphere 1 DONE ===";
        wait;
    end process;
    
    -- Sphere 2: Submits 2 sequential operations
    sphere_2 : process
        variable tid : std_logic_vector(15 downto 0);
    begin
        wait until reset = '0' and clk_locked = '1';
        wait for 150 ns;
        
        report "=== Sphere 2 starting ===";
        
        -- Operation 1: MULT = 11.0 * 12.0 = 132.0, with TID = 16384 (sphere_id=2, op=0)
        tid := std_logic_vector(to_unsigned(2 * 8192 + 0, 16));
        mult_wr_data(191 downto 128) <= x"41400000" & x"41300000";  -- 12.0, 11.0
        mult_wr_tid(47 downto 32) <= tid;
        mult_wr_valid(2) <= '1';
        wait until rising_edge(clk_in);
        mult_wr_valid(2) <= '0';
        report "Sphere 2: Submitted MULT op, TID=" & integer'image(to_integer(unsigned(tid)));
        
        wait until output_rd_valid(2) = '1';
        report "Sphere 2: Got result! TID=" & integer'image(to_integer(unsigned(output_rd_tid(47 downto 32)))) &
               " Value=" & real'image(from_fp32(output_rd_data(95 downto 64)));
        
        -- Operation 2: FMA = 3.0*13.0 + 14.0 = 53.0, with TID = 16385
        tid := std_logic_vector(to_unsigned(2 * 8192 + 1, 16));
        wait for 30 ns;  -- Align to clock edge
        wait until rising_edge(clk_in);
        wait for 1 ns;  -- Delta delay after clock
        fma_wr_data(287 downto 192) <= x"41600000" & x"41500000" & x"40400000";  -- 14.0, 13.0, 3.0
        fma_wr_tid(47 downto 32) <= tid;
        fma_wr_valid(2) <= '1';
        wait until rising_edge(clk_in);
        fma_wr_valid(2) <= '0';
        report "Sphere 2: Submitted FMA op, TID=" & integer'image(to_integer(unsigned(tid)));
        
        wait until output_rd_valid(2) = '1';
        report "Sphere 2: Got result! TID=" & integer'image(to_integer(unsigned(output_rd_tid(47 downto 32)))) &
               " Value=" & real'image(from_fp32(output_rd_data(95 downto 64)));
        
        report "=== Sphere 2 DONE ===";
        wait;
    end process;
    
    -- Main control
    main_control : process
    begin
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        report "========================================";
        report "Starting sphere intersection test";
        report "3 spheres, each submits 2 operations";
        report "========================================";
        
        wait for 5000 ns;
        
        report "========================================";
        report "Test complete!";
        report "========================================";
        sim_done <= true;
        wait;
    end process;

end Behavioral;
