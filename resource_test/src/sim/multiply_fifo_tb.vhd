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
            NUM_MULTIPLIERS : integer := 20;
            TDEST_WIDTH     : integer := 5
        );
        port (
            clk_in             : in  std_logic;
            reset              : in  std_logic;
            input_tdata        : in  std_logic_vector(63 downto 0);
            input_tid          : in  std_logic_vector(15 downto 0);
            input_tvalid       : in  std_logic;
            input_tready       : out std_logic;
            output_tdata       : out std_logic_vector(31 downto 0);
            output_tid         : out std_logic_vector(15 downto 0);
            output_tvalid      : out std_logic;
            output_tready      : in  std_logic;
            clk_locked         : out std_logic
        );
    end component;
    
    -- Test parameters
    constant NUM_MULTIPLIERS : integer := 20;
    constant NUM_TEST_OPS    : integer := 2000; -- Increased to 2000 to fill 1024-deep FIFOs
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
    signal output_tdata       : std_logic_vector(31 downto 0);
    signal output_tid         : std_logic_vector(15 downto 0);
    signal output_tvalid      : std_logic;
    signal output_tready      : std_logic := '0';
    signal clk_locked         : std_logic;
    
    -- Test control
    signal test_done          : boolean := false;
    signal input_count        : integer := 0;
    signal output_count       : integer := 0;
    
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
            NUM_MULTIPLIERS => NUM_MULTIPLIERS,
            TDEST_WIDTH     => 5
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
            
            -- Send operation to input with sequential TID
            input_tdata <= operand_b & operand_a;
            input_tid <= std_logic_vector(to_unsigned(current_tid, 16));
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
    output_collection : process
        variable cycle_count : integer := 0;
    begin
        wait until clk_locked = '1';
        
        -- Initially NOT ready to force input FIFO to fill up
        output_tready <= '0';
        
        -- Wait for burst to be sent (this will cause backpressure)
        wait for 2 us;
        
        report "Starting to drain output FIFO after burst...";
        
        -- Collect results with periodic backpressure to test FIFO buffering
        while output_count < NUM_TEST_OPS loop
            wait until rising_edge(clk_in);
            
            cycle_count := cycle_count + 1;
            
            -- Create backpressure: Ready for 10 cycles, not ready for 20 cycles
            -- This creates heavy backpressure to fill FIFOs
            if cycle_count mod 30 < 10 then
                output_tready <= '1';
            else
                output_tready <= '0';
            end if;
            
            if output_tvalid = '1' and output_tready = '1' then
                output_count <= output_count + 1;
                
                -- Report progress every 100 operations with TID info
                if (output_count + 1) mod 100 = 0 then
                    report "Received " & integer'image(output_count + 1) & " results (last TID: " & 
                           integer'image(to_integer(unsigned(output_tid))) & ")";
                end if;
            end if;
        end loop;
        
        end_time <= now;
        total_time <= end_time - start_time;
        
        -- Calculate throughput
        throughput_mops <= real(NUM_TEST_OPS) / (real(total_time / 1 ns) / 1.0e9);
        
        report "========================================";
        report "STAGE 1 MULTIPLY FIFO TEST RESULTS";
        report "========================================";
        report "Configuration:";
        report "  Number of multipliers: " & integer'image(NUM_MULTIPLIERS);
        report "  Total operations: " & integer'image(NUM_TEST_OPS);
        report "";
        report "Performance:";
        report "  Total time: " & time'image(total_time);
        report "  Throughput: " & real'image(throughput_mops) & " MOPS";
        report "  Operations per second: " & real'image(throughput_mops * 1.0e6);
        report "";
        report "Backpressure Status:";
        report "  Input backpressure detected: " & boolean'image(backpressure_detected);
        report "  Output backpressure: Applied heavily (20 cycles stall every 30 cycles)";
        if backpressure_detected then
            report "  SUCCESS: Input backpressure was triggered as expected!";
        else
            report "  WARNING: Input backpressure was NOT detected";
        end if;
        report "========================================";
        
        test_done <= true;
        wait;
    end process;
    
end Behavioral;
