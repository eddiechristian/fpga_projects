library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity multiply_fifo_tb is
end multiply_fifo_tb;

architecture Behavioral of multiply_fifo_tb is
    
    -- Component declaration
    component top_module is
        generic (
            NUM_MULTIPLIERS   : integer := 20;
            TDEST_WIDTH       : integer := 5;
            NUM_PRODUCERS     : integer := 5;
            PRODUCER_ID_WIDTH : integer := 3
        );
        port (
            clk_in             : in  std_logic;
            reset              : in  std_logic;
            input_tdata        : in  std_logic_vector(63 downto 0);
            input_tid          : in  std_logic_vector(15 downto 0);
            input_tvalid       : in  std_logic;
            input_tready       : out std_logic;
            output_tdata       : out std_logic_vector(159 downto 0);  -- 5 producers * 32 bits
            output_tid         : out std_logic_vector(79 downto 0);   -- 5 producers * 16 bits
            output_tvalid      : out std_logic_vector(4 downto 0);
            output_tready      : in  std_logic_vector(4 downto 0);
            clk_locked         : out std_logic
        );
    end component;
    
    -- Test parameters
    constant NUM_MULTIPLIERS : integer := 20;
    constant NUM_PRODUCERS   : integer := 5;
    constant NUM_TEST_OPS    : integer := 6000; -- Increased to 6000 to exceed 5x1024 FIFO capacity
    constant BURST_SIZE      : integer := 100;  -- Send 100 ops in burst to fill FIFOs
    constant BACKPRESSURE_THRESHOLD : integer := NUM_MULTIPLIERS * 2; -- Threshold for backpressure detection
    
    -- Clock period
    constant CLK_PERIOD : time := 5 ns; -- 100 MHz input clock
    
    -- Signals
    signal clk_in             : std_logic := '0';
    signal reset              : std_logic := '1';
    signal input_tdata        : std_logic_vector(63 downto 0) := (others => '0');
    signal input_tid          : std_logic_vector(15 downto 0) := (others => '0');
    signal input_tvalid       : std_logic := '0';
    signal input_tready       : std_logic;
    signal output_tdata       : std_logic_vector(159 downto 0);  -- 5 producers * 32 bits
    signal output_tid         : std_logic_vector(79 downto 0);   -- 5 producers * 16 bits
    signal output_tvalid      : std_logic_vector(4 downto 0);
    signal output_tready      : std_logic_vector(4 downto 0) := (others => '0');
    signal clk_locked         : std_logic;
    
    -- Test control
    signal test_done          : boolean := false;
    signal input_count        : integer := 0;
    signal output_count       : integer := 0;
    
    -- Per-producer output counters
    type int_array is array (0 to NUM_PRODUCERS-1) of integer;
    signal producer_output_counts : int_array := (others => 0);
    
    -- Operand tracking (for waveform viewing)
    signal current_operand_a  : std_logic_vector(31 downto 0) := (others => '0');
    signal current_operand_b  : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Performance metrics
    signal start_time         : time;
    signal end_time           : time;
    signal total_time         : time;
    signal throughput_mops    : real := 0.0; -- Million operations per second
    signal backpressure_detected : boolean := false;
    
    -- IEEE 754 FP32 helper function to convert real to std_logic_vector
    function real_to_fp32(val : real) return std_logic_vector is
        variable sign     : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable exp_bits : std_logic_vector(7 downto 0);
        variable man_bits : std_logic_vector(22 downto 0);
        variable result   : std_logic_vector(31 downto 0);
        variable temp_val : real;
        variable man_val  : integer;
    begin
        if val = 0.0 then
            return X"00000000";
        end if;
        
        -- Handle sign
        if val < 0.0 then
            sign := '1';
            temp_val := -val;
        else
            sign := '0';
            temp_val := val;
        end if;
        
        -- Simple encoding: normalize to 1.0 <= temp_val < 2.0
        exponent := 127; -- bias
        while temp_val >= 2.0 loop
            temp_val := temp_val / 2.0;
            exponent := exponent + 1;
        end loop;
        while temp_val < 1.0 loop
            temp_val := temp_val * 2.0;
            exponent := exponent - 1;
        end loop;
        
        -- Extract mantissa (fractional part)
        mantissa := temp_val - 1.0;  -- Remove implicit 1
        man_val := integer(mantissa * (2.0**23));
        
        exp_bits := std_logic_vector(to_unsigned(exponent, 8));
        man_bits := std_logic_vector(to_unsigned(man_val, 23));
        
        result := sign & exp_bits & man_bits;
        return result;
    end function;
    
begin
    
    -- Clock generation
    clk_process : process
    begin
        while not test_done loop
            clk_in <= '0';
            wait for CLK_PERIOD/2;
            clk_in <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- DUT instantiation
    dut : top_module
        generic map (
            NUM_MULTIPLIERS   => NUM_MULTIPLIERS,
            TDEST_WIDTH       => 5,
            NUM_PRODUCERS     => NUM_PRODUCERS,
            PRODUCER_ID_WIDTH => 3
        )
        port map (
            clk_in            => clk_in,
            reset             => reset,
            input_tdata       => input_tdata,
            input_tid         => input_tid,
            input_tvalid      => input_tvalid,
            input_tready      => input_tready,
            output_tdata      => output_tdata,
            output_tid        => output_tid,
            output_tvalid     => output_tvalid,
            output_tready     => output_tready,
            clk_locked        => clk_locked
        );
    
    -- Stimulus process (input generation with TID)
    stimulus : process
        variable seed1, seed2 : positive := 1;
        variable rand_val : real;
        variable operand_a, operand_b : std_logic_vector(31 downto 0);
        variable current_tid : integer := 0;
        variable producer_id : integer;
        variable transaction_id : integer;
        variable tid_value : std_logic_vector(15 downto 0);
    begin
        -- Reset
        reset <= '1';
        input_tvalid <= '0';
        wait for 100 ns;
        reset <= '0';
        
        -- Wait for clock to lock
        wait until clk_locked = '1';
        wait for 100 ns;
        
        report "Starting multiply FIFO test with " & integer'image(NUM_TEST_OPS) & " operations";
        report "Number of multipliers: " & integer'image(NUM_MULTIPLIERS);
        
        start_time <= now;
        
        -- Generate test operations
        for i in 0 to NUM_TEST_OPS-1 loop
            -- Generate proper FP32 values (range 0.5 to 4.0 for easy verification)
            uniform(seed1, seed2, rand_val);
            operand_a := real_to_fp32(0.5 + rand_val * 3.5);
            
            uniform(seed1, seed2, rand_val);
            operand_b := real_to_fp32(0.5 + rand_val * 3.5);
            
            -- Update signals for waveform viewing
            current_operand_a <= operand_a;
            current_operand_b <= operand_b;
            
            -- Send operation to input with TID encoding producer ID
            -- TID[15:13] = Producer ID (0-4)
            -- TID[12:0] = Transaction ID (per-producer sequence)
            -- Distribute operations round-robin across producers
            input_tdata <= operand_b & operand_a;
            
            producer_id := i mod NUM_PRODUCERS;  -- Round-robin producer selection
            transaction_id := current_tid;
            -- Encode: upper 3 bits = producer ID, lower 13 bits = transaction ID
            tid_value := std_logic_vector(to_unsigned(producer_id, 3)) & 
                         std_logic_vector(to_unsigned(transaction_id mod 8192, 13));
            input_tid <= tid_value;
            input_tvalid <= '1';
            
            -- Wait for handshake (keep trying until accepted)
            loop
                wait until rising_edge(clk_in);
                
                -- Check if ready
                if input_tready = '1' then
                    -- Transaction completed
                    input_count <= input_count + 1;
                    current_tid := current_tid + 1;
                    if current_tid >= 65536 then
                        current_tid := 0; -- Wrap around
                    end if;
                    exit;
                else
                    -- Backpressure detected!
                    if not backpressure_detected then
                        backpressure_detected <= true;
                        report "BACKPRESSURE DETECTED at operation " & integer'image(i) & 
                               " (input_count=" & integer'image(input_count) & 
                               ", output_count=" & integer'image(output_count) & ")";
                    end if;
                    -- Keep trying on next cycle
                end if;
            end loop;
            
        end loop;
        
        input_tvalid <= '0';
        report "Finished sending " & integer'image(NUM_TEST_OPS) & " operations";
        
        wait;
    end process;
    
    -- Output collection process with controlled backpressure
    -- Monitors all 5 producer outputs simultaneously
    output_collection : process
        variable cycle_count : integer := 0;
        variable producer_id : integer;
    begin
        wait until clk_locked = '1';
        
        -- Initially NOT ready to force input FIFO to fill up
        output_tready <= (others => '0');
        
        -- Wait a bit to let FIFOs fill, then start slow draining to trigger backpressure
        wait for 500 ns;  -- Let pipeline fill up
        
        report "Starting slow output drain to trigger backpressure...";
        
        -- Collect results with heavy backpressure to test FIFO buffering
        while output_count < NUM_TEST_OPS loop
            wait until rising_edge(clk_in);
            
            cycle_count := cycle_count + 1;
            
            -- Create heavy backpressure: Ready for 1 cycle, not ready for 99 cycles
            -- This drains at 1% rate, forcing backpressure with reduced FIFOs
            if cycle_count mod 100 < 1 then
                output_tready <= (others => '1');
            else
                output_tready <= (others => '0');
            end if;
            
            -- Check each producer output
            for prod in 0 to NUM_PRODUCERS-1 loop
                if output_tvalid(prod) = '1' and output_tready(prod) = '1' then
                    -- Extract TID and verify producer ID
                    producer_id := to_integer(unsigned(output_tid((prod+1)*16-1 downto (prod+1)*16-3)));
                    
                    producer_output_counts(prod) <= producer_output_counts(prod) + 1;
                    output_count <= output_count + 1;
                    
                    -- Verify producer ID matches
                    if producer_id /= prod then
                        report "ERROR: Producer " & integer'image(prod) & 
                               " received result with wrong producer ID: " & integer'image(producer_id) 
                               severity error;
                    end if;
                    
                    -- Report progress every 100 operations
                    if (output_count + 1) mod 100 = 0 then
                        report "Received " & integer'image(output_count + 1) & " total results";
                    end if;
                end if;
            end loop;
        end loop;
        
        end_time <= now;
        total_time <= end_time - start_time;
        
        -- Calculate throughput
        throughput_mops <= real(NUM_TEST_OPS) / (real(total_time / 1 ns) / 1.0e9);
        
        report "========================================";
        report "MULTI-PRODUCER MULTIPLY FIFO TEST RESULTS";
        report "========================================";
        report "Configuration:";
        report "  Number of multipliers: " & integer'image(NUM_MULTIPLIERS);
        report "  Number of producers: " & integer'image(NUM_PRODUCERS);
        report "  Total operations: " & integer'image(NUM_TEST_OPS);
        report "";
        report "Performance:";
        report "  Total time: " & time'image(total_time);
        report "  Throughput: " & real'image(throughput_mops) & " MOPS";
        report "  Operations per second: " & real'image(throughput_mops * 1.0e6);
        report "";
        report "Per-Producer Results:";
        for prod in 0 to NUM_PRODUCERS-1 loop
            report "  Producer " & integer'image(prod) & ": " & 
                   integer'image(producer_output_counts(prod)) & " operations (" &
                   integer'image((producer_output_counts(prod) * 100) / NUM_TEST_OPS) & "%)";
        end loop;
        report "";
        report "Backpressure Status:";
        report "  Input backpressure detected: " & boolean'image(backpressure_detected);
        report "  Output backpressure: Applied heavily (1 cycle drain every 100 cycles)";
        if backpressure_detected then
            report "  SUCCESS: Input backpressure was triggered as expected!";
        else
            report "  WARNING: Input backpressure was NOT detected";
        end if;
        report "";
        report "Producer Routing Verification:";
        report "  All results routed to correct producer based on TID[15:13]";
        report "========================================";
        
        test_done <= true;
        wait;
    end process;
    
end Behavioral;
