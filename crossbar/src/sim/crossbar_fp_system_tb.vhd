library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library work;
use work.crossbar_pkg.all;
use work.lin_alg_pkg.all;

entity crossbar_fp_system_tb is
end crossbar_fp_system_tb;

architecture Behavioral of crossbar_fp_system_tb is

    -- Component declaration
    component crossbar_fp_system
        Port (
            clk_100mhz      : in std_logic;
            rst             : in std_logic;
            locked          : out std_logic;
            
            -- Producer interfaces
            prod_requests   : in producer_request_array_t;
            prod_grants     : out producer_grant_array_t;
            prod_results    : out producer_result_array_t
        );
    end component;
    
    -- Clock period
    constant CLK_PERIOD : time := 5 ns;  -- 200 MHz
    
    -- Test signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal locked : std_logic;
    signal prod_requests : producer_request_array_t;
    signal prod_grants : producer_grant_array_t;
    signal prod_results : producer_result_array_t;
    
    -- Test control
    signal sim_done : boolean := false;
    
    -- Helper function to convert real to FP32 std_logic_vector
    function real_to_fp32(r : real) return std_logic_vector is
        variable sign : std_logic;
        variable exp : integer;
        variable mantissa : unsigned(22 downto 0);
        variable result : std_logic_vector(31 downto 0);
        variable abs_r : real;
        variable norm_r : real;
        variable biased_exp : unsigned(7 downto 0);
    begin
        -- Handle zero
        if r = 0.0 then
            return X"00000000";
        end if;
        
        -- Extract sign
        if r < 0.0 then
            sign := '1';
            abs_r := -r;
        else
            sign := '0';
            abs_r := r;
        end if;
        
        -- Calculate exponent and mantissa (simplified)
        exp := integer(floor(log2(abs_r)));
        biased_exp := to_unsigned(exp + 127, 8);
        norm_r := abs_r / (2.0 ** real(exp));
        mantissa := to_unsigned(integer((norm_r - 1.0) * (2.0 ** 23.0)), 23);
        
        -- Construct FP32
        result := sign & std_logic_vector(biased_exp) & std_logic_vector(mantissa);
        return result;
    end function;
    
    -- Helper function to convert FP32 to real (approximate)
    function fp32_to_real(fp : std_logic_vector(31 downto 0)) return real is
        variable sign : std_logic;
        variable exp : unsigned(7 downto 0);
        variable mantissa : unsigned(22 downto 0);
        variable result : real;
        variable exp_val : integer;
    begin
        sign := fp(31);
        exp := unsigned(fp(30 downto 23));
        mantissa := unsigned(fp(22 downto 0));
        
        -- Handle zero
        if exp = X"00" and mantissa = 0 then
            return 0.0;
        end if;
        
        exp_val := to_integer(exp) - 127;
        result := (1.0 + real(to_integer(mantissa)) / (2.0 ** 23.0)) * (2.0 ** real(exp_val));
        
        if sign = '1' then
            result := -result;
        end if;
        
        return result;
    end function;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: crossbar_fp_system
        port map (
            clk_100mhz => clk,
            rst => rst,
            locked => locked,
            prod_requests => prod_requests,
            prod_grants => prod_grants,
            prod_results => prod_results
        );

    -- Clock process
    clk_process: process
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
    stim_proc: process
        variable tid : std_logic_vector(15 downto 0);
        variable test_count : integer := 0;
        variable result_val : real;
        variable expected_val : real;
        variable error : real;
    begin
        -- Initialize all requests to idle
        for i in 0 to NUM_PRODUCERS-1 loop
            prod_requests(i).valid <= '0';
            prod_requests(i).unit_type <= UNIT_MULT;
            prod_requests(i).unit_index <= 0;
            prod_requests(i).data <= (others => '0');
            prod_requests(i).tid <= std_logic_vector(to_unsigned(i, 16));
        end loop;
        
        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 10;
        rst <= '0';
        wait for CLK_PERIOD * 5;
        
        report "======================================";
        report "Starting Crossbar FP System Tests";
        report "======================================";
        
        -- Test 1: Simple multiplication from Producer 0
        report "Test 1: Multiplication (2.0 * 3.0 = 6.0)";
        wait until rising_edge(clk);
        prod_requests(0).valid <= '1';
        prod_requests(0).unit_type <= UNIT_MULT;
        prod_requests(0).unit_index <= 0;
        prod_requests(0).data(31 downto 0) <= real_to_fp32(2.0);    -- operand A
        prod_requests(0).data(63 downto 32) <= real_to_fp32(3.0);   -- operand B
        prod_requests(0).tid <= make_tid(0, 0);  -- Producer 0, operation 0
        wait until rising_edge(clk);
        prod_requests(0).valid <= '0';
        
        -- Wait for result (latency + arbitration + routing)
        wait for CLK_PERIOD * 20;
        
        -- Test 2: Subtraction from Producer 3 (swapped with Test 4)
        report "Test 2: Subtraction (10.0 - 2.5 = 7.5)";
        wait until rising_edge(clk);
        prod_requests(3).valid <= '1';
        prod_requests(3).unit_type <= UNIT_ADDSUB;
        prod_requests(3).unit_index <= 0;
        prod_requests(3).data(31 downto 0) <= real_to_fp32(10.0);   -- operand A
        prod_requests(3).data(63 downto 32) <= real_to_fp32(2.5);   -- operand B
        prod_requests(3).data(64) <= '1';  -- subtract operation
        prod_requests(3).tid <= make_tid(3, 3);  -- Producer 3, operation 3
        wait until rising_edge(clk);
        prod_requests(3).valid <= '0';
        
        wait for CLK_PERIOD * 20;
        report "Test 2 wait period complete - checking for results...";
        
        -- Test 3: Addition from Producer 2
        report "Test 3: Addition (5.5 + 3.25 = 8.75)";
        wait until rising_edge(clk);
        prod_requests(2).valid <= '1';
        prod_requests(2).unit_type <= UNIT_ADDSUB;
        prod_requests(2).unit_index <= 0;
        prod_requests(2).data(31 downto 0) <= real_to_fp32(5.5);    -- operand A
        prod_requests(2).data(63 downto 32) <= real_to_fp32(3.25);  -- operand B
        prod_requests(2).data(64) <= '0';  -- add operation
        prod_requests(2).tid <= make_tid(2, 2);  -- Producer 2, operation 2
        wait until rising_edge(clk);
        prod_requests(2).valid <= '0';
        
        wait for CLK_PERIOD * 20;
        report "Test 3 wait period complete - checking for results...";
        
        -- Test 4: FMA operation from Producer 1 (swapped with Test 2)
        report "Test 4: FMA (2.0 * 3.0 + 4.0 = 10.0)";
        wait until rising_edge(clk);
        prod_requests(1).valid <= '1';
        prod_requests(1).unit_type <= UNIT_FMA;
        prod_requests(1).unit_index <= 0;
        prod_requests(1).data(31 downto 0) <= real_to_fp32(2.0);    -- operand A
        prod_requests(1).data(63 downto 32) <= real_to_fp32(3.0);   -- operand B
        prod_requests(1).data(95 downto 64) <= real_to_fp32(4.0);   -- operand C
        prod_requests(1).tid <= make_tid(1, 1);  -- Producer 1, operation 1
        wait until rising_edge(clk);
        prod_requests(1).valid <= '0';
        
        wait for CLK_PERIOD * 20;
        report "Test 4 wait period complete - checking for results...";
        
        -- Test 5: Multiple concurrent requests (stress test)
        report "Test 5: Concurrent requests from multiple producers";
        wait until rising_edge(clk);
        
        -- Producer 0: MULT
        prod_requests(0).valid <= '1';
        prod_requests(0).unit_type <= UNIT_MULT;
        prod_requests(0).unit_index <= 0;
        prod_requests(0).data(31 downto 0) <= real_to_fp32(1.5);
        prod_requests(0).data(63 downto 32) <= real_to_fp32(2.0);
        prod_requests(0).tid <= make_tid(0, 100);  -- Producer 0, operation 100
        
        -- Producer 1: FMA
        prod_requests(1).valid <= '1';
        prod_requests(1).unit_type <= UNIT_FMA;
        prod_requests(1).unit_index <= 0;
        prod_requests(1).data(31 downto 0) <= real_to_fp32(1.0);
        prod_requests(1).data(63 downto 32) <= real_to_fp32(2.0);
        prod_requests(1).data(95 downto 64) <= real_to_fp32(3.0);
        prod_requests(1).tid <= make_tid(1, 101);  -- Producer 1, operation 101
        
        -- Producer 2: ADD
        prod_requests(2).valid <= '1';
        prod_requests(2).unit_type <= UNIT_ADDSUB;
        prod_requests(2).unit_index <= 0;
        prod_requests(2).data(31 downto 0) <= real_to_fp32(4.0);
        prod_requests(2).data(63 downto 32) <= real_to_fp32(5.0);
        prod_requests(2).data(64) <= '0';
        prod_requests(2).tid <= make_tid(2, 102);  -- Producer 2, operation 102
        
        wait until rising_edge(clk);
        prod_requests(0).valid <= '0';
        prod_requests(1).valid <= '0';
        prod_requests(2).valid <= '0';
        
        wait for CLK_PERIOD * 30;
        
        -- Test 6: Burst of operations
        report "Test 6: Burst of 5 multiplications from Producer 4";
        for i in 0 to 4 loop
            wait until rising_edge(clk);
            prod_requests(4).valid <= '1';
            prod_requests(4).unit_type <= UNIT_MULT;
            prod_requests(4).unit_index <= 0;
            prod_requests(4).data(31 downto 0) <= real_to_fp32(real(i) + 1.0);
            prod_requests(4).data(63 downto 32) <= real_to_fp32(1.0);
            prod_requests(4).tid <= make_tid(4, 200 + i);  -- Producer 4, operation 200+i
            wait until rising_edge(clk);
            prod_requests(4).valid <= '0';
            wait for CLK_PERIOD * 2;  -- Small gap between operations
        end loop;
        
        wait for CLK_PERIOD * 40;
        
        -- Test 7: All producers active simultaneously
        report "Test 7: All producers active simultaneously";
        wait until rising_edge(clk);
        for i in 0 to NUM_PRODUCERS-1 loop
            prod_requests(i).valid <= '1';
            prod_requests(i).unit_type <= UNIT_MULT;
            prod_requests(i).unit_index <= 0;
            prod_requests(i).data(31 downto 0) <= real_to_fp32(real(i) + 1.0);
            prod_requests(i).data(63 downto 32) <= real_to_fp32(10.0);
            prod_requests(i).tid <= make_tid(i, 300 + i);  -- Producer i, operation 300+i
        end loop;
        
        wait until rising_edge(clk);
        for i in 0 to NUM_PRODUCERS-1 loop
            prod_requests(i).valid <= '0';
        end loop;
        
        wait for CLK_PERIOD * 50;
        
        report "======================================";
        report "All tests completed";
        report "Check waveforms for results verification";
        report "======================================";
        
        sim_done <= true;
        wait;
    end process;
    
    -- Result monitor process with counters
    monitor_proc: process
        variable result_count : integer := 0;
    begin
        wait until rising_edge(clk);
        
        for i in 0 to NUM_PRODUCERS-1 loop
            if prod_results(i).valid = '1' then
                result_count := result_count + 1;
                report "[" & integer'image(result_count) & "] Producer " & integer'image(i) & 
                       " received result: TID=" & integer'image(to_integer(unsigned(prod_results(i).tid))) &
                       " Data=" & to_hstring(prod_results(i).data);
            end if;
        end loop;
        
        if sim_done then
            report "======================================";
            report "Total results captured: " & integer'image(result_count);
            report "======================================";
            wait;
        end if;
    end process;

end Behavioral;
