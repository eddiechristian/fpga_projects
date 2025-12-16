library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library work;
use work.crossbar_pkg.all;

entity dot_product_tb is
end dot_product_tb;

architecture Behavioral of dot_product_tb is

    -- Clock and reset
    constant CLK_PERIOD : time := 5 ns;  -- 200 MHz
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal sim_done : boolean := false;
    
    -- DUT signals
    signal prod_requests : producer_request_array_t;
    signal prod_grants : producer_grant_array_t;
    signal prod_results : producer_result_array_t;
    signal locked : std_logic;
    
    -- Individual producer request signals (to avoid multiple driver conflict)
    signal prod0_request : producer_request_t;
    signal prod1_request : producer_request_t;
    
    -- Component declaration
    component crossbar_fp_system is
        Port (
            clk_100mhz      : in std_logic;
            rst             : in std_logic;
            locked          : out std_logic;
            prod_requests   : in producer_request_array_t;
            prod_grants     : out producer_grant_array_t;
            prod_results    : out producer_result_array_t
        );
    end component;
    
    -- Helper function: Convert real to FP32 (IEEE 754 single precision)
    function real_to_fp32(r : real) return std_logic_vector is
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable exp_biased : unsigned(7 downto 0);
        variable mant_bits : unsigned(22 downto 0);
        variable result : std_logic_vector(31 downto 0);
        variable abs_r : real;
    begin
        -- Handle zero
        if r = 0.0 then
            return X"00000000";
        end if;
        
        -- Determine sign
        if r < 0.0 then
            sign := '1';
            abs_r := -r;
        else
            sign := '0';
            abs_r := r;
        end if;
        
        -- Calculate exponent and mantissa
        exponent := integer(floor(log2(abs_r)));
        mantissa := abs_r / (2.0 ** real(exponent));
        
        -- Normalize mantissa to [1.0, 2.0)
        if mantissa >= 2.0 then
            mantissa := mantissa / 2.0;
            exponent := exponent + 1;
        elsif mantissa < 1.0 then
            mantissa := mantissa * 2.0;
            exponent := exponent - 1;
        end if;
        
        -- Bias exponent (IEEE 754 bias = 127)
        exp_biased := to_unsigned(exponent + 127, 8);
        
        -- Convert mantissa to 23-bit representation (remove implicit 1)
        mant_bits := to_unsigned(integer((mantissa - 1.0) * (2.0 ** 23)), 23);
        
        -- Construct the FP32 word
        result(31) := sign;
        result(30 downto 23) := std_logic_vector(exp_biased);
        result(22 downto 0) := std_logic_vector(mant_bits);
        
        return result;
    end function;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';
    
    -- DUT instantiation
    uut: crossbar_fp_system
        port map (
            clk_100mhz => clk,
            rst => rst,
            locked => locked,
            prod_requests => prod_requests,
            prod_grants => prod_grants,
            prod_results => prod_results
        );
    
    -- Combine individual producer requests into array
    prod_requests(0) <= prod0_request;
    prod_requests(1) <= prod1_request;
    -- Initialize unused producers
    gen_unused: for i in 2 to NUM_PRODUCERS-1 generate
        prod_requests(i) <= init_producer_request;
    end generate;
    
    -- Producer 0 process: Computes dot([2.0, 3.0], [4.0, 5.0])
    producer0_proc: process
        variable mult1_result : std_logic_vector(31 downto 0);
        variable mult2_result : std_logic_vector(31 downto 0);
        variable mult1_received : boolean := false;
        variable mult2_received : boolean := false;
    begin
        -- Initialize
        prod0_request.valid <= '0';
        prod0_request.unit_type <= UNIT_MULT;
        prod0_request.unit_index <= 0;
        prod0_request.data <= (others => '0');
        prod0_request.tid <= (others => '0');
        wait for 0 ns;  -- Let initialization take effect
        
        -- Wait for reset
        wait until rst = '0';
        wait for CLK_PERIOD * 5;
        
        report "Producer 0: Computing dot([2.0, 3.0], [4.0, 5.0])";
        
        -- Submit MULT 1: 2.0 * 4.0
        prod0_request.valid <= '1';
        prod0_request.unit_type <= UNIT_MULT;
        prod0_request.unit_index <= 0;
        prod0_request.data(31 downto 0) <= real_to_fp32(2.0);
        prod0_request.data(63 downto 32) <= real_to_fp32(4.0);
        prod0_request.tid <= make_tid(0, 0);
        report "Producer 0: Requesting MULT1 - unit_index=" & integer'image(0) & 
               ", TID=0x" & to_hstring(make_tid(0, 0)) &
               ", OpA=0x" & to_hstring(real_to_fp32(2.0)) &
               ", OpB=0x" & to_hstring(real_to_fp32(4.0));
        
        wait until rising_edge(clk);
        report "Producer 0: After clock - valid=" & std_logic'image(prod0_request.valid) &
               ", grant=" & std_logic'image(prod_grants(0).granted);
        prod0_request.valid <= '0';
        if prod_grants(0).granted = '1' then
            report "Producer 0: MULT1 request GRANTED";
        else
            report "Producer 0: MULT1 request NOT granted" severity warning;
        end if;
        
        -- Submit MULT 2: 3.0 * 5.0
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        prod0_request.valid <= '1';
        prod0_request.unit_type <= UNIT_MULT;
        prod0_request.unit_index <= 1;
        prod0_request.data(31 downto 0) <= real_to_fp32(3.0);
        prod0_request.data(63 downto 32) <= real_to_fp32(5.0);
        prod0_request.tid <= make_tid(0, 1);
        report "Producer 0: Requesting MULT2 (3.0 * 5.0), TID=0x" & to_hstring(make_tid(0, 1));
        
        wait until rising_edge(clk);
        if prod_grants(0).granted = '1' then
            report "Producer 0: MULT2 request GRANTED";
        else
            report "Producer 0: MULT2 request NOT granted" severity warning;
        end if;
        prod0_request.valid <= '0';
        
        -- Wait for both MULT results
        report "Producer 0: Waiting for MULT results...";
        for timeout in 0 to 100 loop
            exit when (mult1_received and mult2_received);
            wait until rising_edge(clk);
            
            if prod_results(0).valid = '1' then
                -- Check which operation completed
                if prod_results(0).tid = make_tid(0, 0) then
                    mult1_result := prod_results(0).data;
                    mult1_received := true;
                    report "Producer 0: Captured MULT1 result = 0x" & to_hstring(mult1_result);
                elsif prod_results(0).tid = make_tid(0, 1) then
                    mult2_result := prod_results(0).data;
                    mult2_received := true;
                    report "Producer 0: Captured MULT2 result = 0x" & to_hstring(mult2_result);
                end if;
            end if;
        end loop;
        
        if not (mult1_received and mult2_received) then
            report "Producer 0: TIMEOUT waiting for MULT results!" severity error;
        end if;
        
        -- Submit ADD using captured MULT results
        wait until rising_edge(clk);
        prod0_request.valid <= '1';
        prod0_request.unit_type <= UNIT_ADDSUB;
        prod0_request.unit_index <= 0;
        prod0_request.data(31 downto 0) <= mult1_result;
        prod0_request.data(63 downto 32) <= mult2_result;
        prod0_request.data(64) <= '0';  -- ADD
        prod0_request.tid <= make_tid(0, 2);
        report "Producer 0: Submitted ADD (MULT1 + MULT2), TID=0x" & to_hstring(make_tid(0, 2));
        
        wait until rising_edge(clk);
        prod0_request.valid <= '0';
        
        -- Wait for final result
        report "Producer 0: Waiting for final dot product result...";
        loop
            wait until rising_edge(clk);
            if prod_results(0).valid = '1' and prod_results(0).tid = make_tid(0, 2) then
                report "Producer 0: Final dot product = 0x" & to_hstring(prod_results(0).data) & " (expected 0x41B80000 = 23.0)";
                exit;
            end if;
        end loop;
        
        wait;
    end process;
    
    -- Producer 1 process: Computes dot([1.0, 2.0], [3.0, 4.0])
    producer1_proc: process
        variable mult1_result : std_logic_vector(31 downto 0);
        variable mult2_result : std_logic_vector(31 downto 0);
        variable mult1_received : boolean := false;
        variable mult2_received : boolean := false;
    begin
        -- Initialize
        prod1_request.valid <= '0';
        prod1_request.unit_type <= UNIT_MULT;
        prod1_request.unit_index <= 0;
        prod1_request.data <= (others => '0');
        prod1_request.tid <= (others => '0');
        wait for 0 ns;  -- Let initialization take effect
        
        -- Wait for reset
        wait until rst = '0';
        wait for CLK_PERIOD * 8;  -- Start 3 cycles later than Producer 0
        
        report "Producer 1: Computing dot([1.0, 2.0], [3.0, 4.0])";
        
        -- Submit MULT 1: 1.0 * 3.0
        prod1_request.valid <= '1';
        prod1_request.unit_type <= UNIT_MULT;
        prod1_request.unit_index <= 2;
        prod1_request.data(31 downto 0) <= real_to_fp32(1.0);
        prod1_request.data(63 downto 32) <= real_to_fp32(3.0);
        prod1_request.tid <= make_tid(1, 0);
        report "Producer 1: Requesting MULT1 - unit_index=" & integer'image(2) & 
               ", TID=0x" & to_hstring(make_tid(1, 0)) &
               ", OpA=0x" & to_hstring(real_to_fp32(1.0)) &
               ", OpB=0x" & to_hstring(real_to_fp32(3.0));
        
        wait until rising_edge(clk);
        report "Producer 1: After clock - valid=" & std_logic'image(prod1_request.valid) &
               ", grant=" & std_logic'image(prod_grants(1).granted);
        if prod_grants(1).granted = '1' then
            report "Producer 1: MULT1 request GRANTED";
        else
            report "Producer 1: MULT1 request NOT granted" severity warning;
        end if;
        prod1_request.valid <= '0';
        
        -- Submit MULT 2: 2.0 * 4.0
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        prod1_request.valid <= '1';
        prod1_request.unit_type <= UNIT_MULT;
        prod1_request.unit_index <= 3;
        prod1_request.data(31 downto 0) <= real_to_fp32(2.0);
        prod1_request.data(63 downto 32) <= real_to_fp32(4.0);
        prod1_request.tid <= make_tid(1, 1);
        report "Producer 1: Requesting MULT2 (2.0 * 4.0), TID=0x" & to_hstring(make_tid(1, 1));
        
        wait until rising_edge(clk);
        if prod_grants(1).granted = '1' then
            report "Producer 1: MULT2 request GRANTED";
        else
            report "Producer 1: MULT2 request NOT granted" severity warning;
        end if;
        prod1_request.valid <= '0';
        
        -- Wait for both MULT results
        report "Producer 1: Waiting for MULT results...";
        for timeout in 0 to 100 loop
            exit when (mult1_received and mult2_received);
            wait until rising_edge(clk);
            
            if prod_results(1).valid = '1' then
                -- Check which operation completed
                if prod_results(1).tid = make_tid(1, 0) then
                    mult1_result := prod_results(1).data;
                    mult1_received := true;
                    report "Producer 1: Captured MULT1 result = 0x" & to_hstring(mult1_result);
                elsif prod_results(1).tid = make_tid(1, 1) then
                    mult2_result := prod_results(1).data;
                    mult2_received := true;
                    report "Producer 1: Captured MULT2 result = 0x" & to_hstring(mult2_result);
                end if;
            end if;
        end loop;
        
        if not (mult1_received and mult2_received) then
            report "Producer 1: TIMEOUT waiting for MULT results!" severity error;
        end if;
        
        -- Submit ADD using captured MULT results
        wait until rising_edge(clk);
        prod1_request.valid <= '1';
        prod1_request.unit_type <= UNIT_ADDSUB;
        prod1_request.unit_index <= 2;
        prod1_request.data(31 downto 0) <= mult1_result;
        prod1_request.data(63 downto 32) <= mult2_result;
        prod1_request.data(64) <= '0';  -- ADD
        prod1_request.tid <= make_tid(1, 2);
        report "Producer 1: Submitted ADD (MULT1 + MULT2), TID=0x" & to_hstring(make_tid(1, 2));
        
        wait until rising_edge(clk);
        prod1_request.valid <= '0';
        
        -- Wait for final result
        report "Producer 1: Waiting for final dot product result...";
        loop
            wait until rising_edge(clk);
            if prod_results(1).valid = '1' and prod_results(1).tid = make_tid(1, 2) then
                report "Producer 1: Final dot product = 0x" & to_hstring(prod_results(1).data) & " (expected 0x41300000 = 11.0)";
                exit;
            end if;
        end loop;
        
        wait;
    end process;
    
    -- Control process
    control_proc: process
    begin
        -- Initialize other producers
        for i in 2 to NUM_PRODUCERS-1 loop
            prod_requests(i) <= init_producer_request;
        end loop;
        
        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 10;
        rst <= '0';
        
        report "======================================";
        report "Starting Dot Product Test";
        report "Producer 0: dot([2.0, 3.0], [4.0, 5.0]) = 23.0";
        report "Producer 1: dot([1.0, 2.0], [3.0, 4.0]) = 11.0";
        report "======================================";
        
        -- Wait for completion
        wait for CLK_PERIOD * 200;
        
        report "======================================";
        report "Dot Product Test Complete";
        report "======================================";
        
        sim_done <= true;
        wait;
    end process;

end Behavioral;
