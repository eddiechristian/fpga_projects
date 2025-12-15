library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity pipeline_concurrent_tb is
end pipeline_concurrent_tb;

architecture Behavioral of pipeline_concurrent_tb is

    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant NUM_MULT_UNITS : integer := 8;
    constant NUM_FMA_UNITS : integer := 5;
    constant NUM_ADD_UNITS : integer := 3;
    constant NUM_PRODUCERS : integer := 5;
    
    constant NUM_OPS_PER_PRODUCER : integer := 20;  -- Each producer submits 20 ops
    constant PRODUCER_A_ID : integer := 0;
    constant PRODUCER_B_ID : integer := 1;
    constant PRODUCER_C_ID : integer := 2;
    
    -- Component declaration
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
    
    -- Signals
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
    
    -- Debug signals for waveform viewing
    signal prod0_result : std_logic_vector(31 downto 0);
    signal prod0_tid    : std_logic_vector(15 downto 0);
    signal prod1_result : std_logic_vector(31 downto 0);
    signal prod1_tid    : std_logic_vector(15 downto 0);
    signal prod2_result : std_logic_vector(31 downto 0);
    signal prod2_tid    : std_logic_vector(15 downto 0);
    signal prod3_result : std_logic_vector(31 downto 0);
    signal prod3_tid    : std_logic_vector(15 downto 0);
    signal prod4_result : std_logic_vector(31 downto 0);
    signal prod4_tid    : std_logic_vector(15 downto 0);
    
    -- Debug signals: input operands for each producer
    signal prod0_wr_a_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod0_wr_b_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod0_wr_c_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod0_wr_tid      : std_logic_vector(15 downto 0) := (others => '0');
    signal prod0_wr_valid    : std_logic := '0';
    
    signal prod1_wr_a_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod1_wr_b_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod1_wr_c_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod1_wr_tid      : std_logic_vector(15 downto 0) := (others => '0');
    signal prod1_wr_valid    : std_logic := '0';
    
    signal prod2_wr_a_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod2_wr_b_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod2_wr_c_val    : std_logic_vector(31 downto 0) := (others => '0');
    signal prod2_wr_tid      : std_logic_vector(15 downto 0) := (others => '0');
    signal prod2_wr_valid    : std_logic := '0';
    
    -- Debug signals for monitoring output valid states
    signal debug_prod0_rd_valid : std_logic;
    signal debug_prod1_rd_valid : std_logic;
    signal debug_prod2_rd_valid : std_logic;
    
    -- Helper functions
    function to_fp32(val : real) return std_logic_vector is
        variable sign : std_logic;
        variable exponent : std_logic_vector(7 downto 0);
        variable mantissa : std_logic_vector(22 downto 0);
        variable result : std_logic_vector(31 downto 0);
        variable abs_val : real;
        variable exp_int : integer;
        variable mant_real : real;
    begin
        if val = 0.0 then
            return x"00000000";
        end if;
        
        if val < 0.0 then
            sign := '1';
            abs_val := -val;
        else
            sign := '0';
            abs_val := val;
        end if;
        
        exp_int := integer(floor(log2(abs_val)));
        exponent := std_logic_vector(to_unsigned(exp_int + 127, 8));
        
        mant_real := (abs_val / (2.0 ** real(exp_int))) - 1.0;
        mantissa := std_logic_vector(to_unsigned(integer(mant_real * (2.0 ** 23)), 23));
        
        result := sign & exponent & mantissa;
        return result;
    end function;
    
    function from_fp32(fp : std_logic_vector(31 downto 0)) return real is
        variable sign : std_logic;
        variable exponent : integer;
        variable mantissa : real;
        variable result : real;
    begin
        sign := fp(31);
        exponent := to_integer(unsigned(fp(30 downto 23))) - 127;
        mantissa := 1.0 + (real(to_integer(unsigned(fp(22 downto 0)))) / (2.0 ** 23));
        
        result := mantissa * (2.0 ** real(exponent));
        
        if sign = '1' then
            result := -result;
        end if;
        
        return result;
    end function;
    
    signal producer_a_done : boolean := false;
    signal producer_b_done : boolean := false;
    signal producer_c_done : boolean := false;
    signal sim_done : boolean := false;

begin

    -- Clock generation
    clk_in <= not clk_in after CLK_PERIOD / 2 when not sim_done else '0';
    
    -- Debug signal assignments for waveform viewing
    prod0_result <= output_rd_data(31 downto 0);
    prod0_tid    <= output_rd_tid(15 downto 0);
    prod1_result <= output_rd_data(63 downto 32);
    prod1_tid    <= output_rd_tid(31 downto 16);
    prod2_result <= output_rd_data(95 downto 64);
    prod2_tid    <= output_rd_tid(47 downto 32);
    prod3_result <= output_rd_data(127 downto 96);
    prod3_tid    <= output_rd_tid(63 downto 48);
    prod4_result <= output_rd_data(159 downto 128);
    prod4_tid    <= output_rd_tid(79 downto 64);
    
    -- Debug valid signal assignments
    debug_prod0_rd_valid <= output_rd_valid(0);
    debug_prod1_rd_valid <= output_rd_valid(1);
    debug_prod2_rd_valid <= output_rd_valid(2);
    
    -- DUT instantiation
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
    
    -- Producer A: Submits MULT operations
    producer_a : process
        variable seed1, seed2 : integer := 100;
        variable rand : real;
        variable a_val, b_val : real;
        variable a_fp, b_fp : std_logic_vector(31 downto 0);
        variable tid_val : std_logic_vector(15 downto 0);
        variable mult_unit_idx : integer := 0;
    begin
        -- Wait for reset
        wait until reset = '0' and clk_locked = '1';
        wait for 20 ns;
        
        report "Producer A starting (MULT operations)...";
        
        -- Generate MULT operations
        for i in 0 to NUM_OPS_PER_PRODUCER-1 loop
            uniform(seed1, seed2, rand);
            a_val := rand * 10.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 10.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            
            -- TID format: ProducerID (bits 15:13) + operation index (bits 12:0)
            tid_val := std_logic_vector(to_unsigned(PRODUCER_A_ID * 8192 + i, 16));
            
            wait until rising_edge(clk_in);
            mult_wr_data((mult_unit_idx+1)*64-1 downto mult_unit_idx*64) <= b_fp & a_fp;
            mult_wr_tid((mult_unit_idx+1)*16-1 downto mult_unit_idx*16) <= tid_val;
            mult_wr_valid(mult_unit_idx) <= '1';
            
            wait until rising_edge(clk_in) and mult_wr_ready(mult_unit_idx) = '1';
            mult_wr_valid(mult_unit_idx) <= '0';
            
            mult_unit_idx := (mult_unit_idx + 1) mod NUM_MULT_UNITS;
            
            report "[Producer A] MULT #" & integer'image(i) & 
                   " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                   " A=" & real'image(a_val) & " B=" & real'image(b_val) &
                   " Expected=" & real'image(a_val * b_val);
        end loop;
        
        report "Producer A finished all operations";
        producer_a_done <= true;
        wait;
    end process;
    
    -- Producer B: Submits FMA operations
    producer_b : process
        variable seed1, seed2 : integer := 200;
        variable rand : real;
        variable a_val, b_val, c_val : real;
        variable a_fp, b_fp, c_fp : std_logic_vector(31 downto 0);
        variable tid_val : std_logic_vector(15 downto 0);
        variable fma_unit_idx : integer := 0;
    begin
        -- Wait for reset
        wait until reset = '0' and clk_locked = '1';
        wait for 20 ns;
        
        report "Producer B starting (FMA operations)...";
        
        -- Generate FMA operations
        for i in 0 to NUM_OPS_PER_PRODUCER-1 loop
            uniform(seed1, seed2, rand);
            a_val := rand * 5.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 5.0;
            uniform(seed1, seed2, rand);
            c_val := rand * 5.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            c_fp := to_fp32(c_val);
            
            -- TID format: ProducerID (bits 15:13) + operation index (bits 12:0)
            tid_val := std_logic_vector(to_unsigned(PRODUCER_B_ID * 8192 + i, 16));
            
            wait until rising_edge(clk_in);
            fma_wr_data((fma_unit_idx+1)*96-1 downto fma_unit_idx*96) <= c_fp & b_fp & a_fp;
            fma_wr_tid((fma_unit_idx+1)*16-1 downto fma_unit_idx*16) <= tid_val;
            fma_wr_valid(fma_unit_idx) <= '1';
            
            wait until rising_edge(clk_in) and fma_wr_ready(fma_unit_idx) = '1';
            fma_wr_valid(fma_unit_idx) <= '0';
            
            fma_unit_idx := (fma_unit_idx + 1) mod NUM_FMA_UNITS;
            
            report "[Producer B] FMA #" & integer'image(i) & 
                   " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                   " A=" & real'image(a_val) & " B=" & real'image(b_val) & " C=" & real'image(c_val) &
                   " Expected=" & real'image(a_val * b_val + c_val);
        end loop;
        
        report "Producer B finished all operations";
        producer_b_done <= true;
        wait;
    end process;
    
    -- Producer C: Submits mixed MULT and FMA operations
    producer_c : process
        variable seed1, seed2 : integer := 300;
        variable rand : real;
        variable a_val, b_val, c_val : real;
        variable a_fp, b_fp, c_fp : std_logic_vector(31 downto 0);
        variable tid_val : std_logic_vector(15 downto 0);
        variable use_mult : boolean;
        variable mult_unit_idx : integer := 0;
        variable fma_unit_idx : integer := 0;
    begin
        -- Wait for reset
        wait until reset = '0' and clk_locked = '1';
        wait for 20 ns;
        
        report "Producer C starting (mixed MULT/FMA operations)...";
        
        -- Generate mixed operations
        for i in 0 to NUM_OPS_PER_PRODUCER-1 loop
            -- Alternate between MULT and FMA
            use_mult := (i mod 2) = 0;
            
            uniform(seed1, seed2, rand);
            a_val := rand * 8.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 8.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            
            -- TID format: ProducerID (bits 15:13) + operation index (bits 12:0)
            tid_val := std_logic_vector(to_unsigned(PRODUCER_C_ID * 8192 + i, 16));
            
            if use_mult then
                -- Submit MULT operation
                wait until rising_edge(clk_in);
                mult_wr_data((mult_unit_idx+1)*64-1 downto mult_unit_idx*64) <= b_fp & a_fp;
                mult_wr_tid((mult_unit_idx+1)*16-1 downto mult_unit_idx*16) <= tid_val;
                mult_wr_valid(mult_unit_idx) <= '1';
                
                wait until rising_edge(clk_in) and mult_wr_ready(mult_unit_idx) = '1';
                mult_wr_valid(mult_unit_idx) <= '0';
                
                mult_unit_idx := (mult_unit_idx + 1) mod NUM_MULT_UNITS;
                
                report "[Producer C] MULT #" & integer'image(i) & 
                       " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                       " A=" & real'image(a_val) & " B=" & real'image(b_val) &
                       " Expected=" & real'image(a_val * b_val);
            else
                -- Submit FMA operation
                uniform(seed1, seed2, rand);
                c_val := rand * 8.0;
                c_fp := to_fp32(c_val);
                
                wait until rising_edge(clk_in);
                fma_wr_data((fma_unit_idx+1)*96-1 downto fma_unit_idx*96) <= c_fp & b_fp & a_fp;
                fma_wr_tid((fma_unit_idx+1)*16-1 downto fma_unit_idx*16) <= tid_val;
                fma_wr_valid(fma_unit_idx) <= '1';
                
                wait until rising_edge(clk_in) and fma_wr_ready(fma_unit_idx) = '1';
                fma_wr_valid(fma_unit_idx) <= '0';
                
                fma_unit_idx := (fma_unit_idx + 1) mod NUM_FMA_UNITS;
                
                report "[Producer C] FMA #" & integer'image(i) & 
                       " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                       " A=" & real'image(a_val) & " B=" & real'image(b_val) & " C=" & real'image(c_val) &
                       " Expected=" & real'image(a_val * b_val + c_val);
            end if;
        end loop;
        
        report "Producer C finished all operations";
        producer_c_done <= true;
        wait;
    end process;
    
    -- Consumer for Producer A results
    consumer_a : process
        variable count : integer := 0;
        variable result_val : real;
        variable tid_val : integer;
        variable wait_cycles : integer := 0;
    begin
        wait until reset = '0' and clk_locked = '1';
        report "[Consumer A] Started, waiting for results...";
        
        while count < NUM_OPS_PER_PRODUCER loop
            wait until rising_edge(clk_in);
            wait_cycles := wait_cycles + 1;
            
            if output_rd_valid(PRODUCER_A_ID) = '1' and output_rd_ready(PRODUCER_A_ID) = '1' then
                result_val := from_fp32(output_rd_data((PRODUCER_A_ID+1)*32-1 downto PRODUCER_A_ID*32));
                tid_val := to_integer(unsigned(output_rd_tid((PRODUCER_A_ID+1)*16-1 downto PRODUCER_A_ID*16)));
                
                report "[Producer A RESULT] TID=" & integer'image(tid_val) &
                       " Result=" & real'image(result_val) &
                       " (waited " & integer'image(wait_cycles) & " cycles)";
                
                count := count + 1;
                wait_cycles := 0;
            elsif wait_cycles mod 100 = 0 then
                report "[Consumer A] Still waiting... (count=" & integer'image(count) &
                       "/" & integer'image(NUM_OPS_PER_PRODUCER) &
                       ", rd_valid=" & std_logic'image(output_rd_valid(PRODUCER_A_ID)) & ")";
            end if;
        end loop;
        
        report "Producer A: Collected all " & integer'image(count) & " results";
        wait;
    end process;
    
    -- Consumer for Producer B results
    consumer_b : process
        variable count : integer := 0;
        variable result_val : real;
        variable tid_val : integer;
        variable wait_cycles : integer := 0;
    begin
        wait until reset = '0' and clk_locked = '1';
        report "[Consumer B] Started, waiting for results...";
        
        while count < NUM_OPS_PER_PRODUCER loop
            wait until rising_edge(clk_in);
            wait_cycles := wait_cycles + 1;
            
            if output_rd_valid(PRODUCER_B_ID) = '1' and output_rd_ready(PRODUCER_B_ID) = '1' then
                result_val := from_fp32(output_rd_data((PRODUCER_B_ID+1)*32-1 downto PRODUCER_B_ID*32));
                tid_val := to_integer(unsigned(output_rd_tid((PRODUCER_B_ID+1)*16-1 downto PRODUCER_B_ID*16)));
                
                report "[Producer B RESULT] TID=" & integer'image(tid_val) &
                       " Result=" & real'image(result_val) &
                       " (waited " & integer'image(wait_cycles) & " cycles)";
                
                count := count + 1;
                wait_cycles := 0;
            elsif wait_cycles mod 100 = 0 then
                report "[Consumer B] Still waiting... (count=" & integer'image(count) &
                       "/" & integer'image(NUM_OPS_PER_PRODUCER) &
                       ", rd_valid=" & std_logic'image(output_rd_valid(PRODUCER_B_ID)) & ")";
            end if;
        end loop;
        
        report "Producer B: Collected all " & integer'image(count) & " results";
        wait;
    end process;
    
    -- Consumer for Producer C results
    consumer_c : process
        variable count : integer := 0;
        variable result_val : real;
        variable tid_val : integer;
        variable wait_cycles : integer := 0;
    begin
        wait until reset = '0' and clk_locked = '1';
        report "[Consumer C] Started, waiting for results...";
        
        while count < NUM_OPS_PER_PRODUCER loop
            wait until rising_edge(clk_in);
            wait_cycles := wait_cycles + 1;
            
            if output_rd_valid(PRODUCER_C_ID) = '1' and output_rd_ready(PRODUCER_C_ID) = '1' then
                result_val := from_fp32(output_rd_data((PRODUCER_C_ID+1)*32-1 downto PRODUCER_C_ID*32));
                tid_val := to_integer(unsigned(output_rd_tid((PRODUCER_C_ID+1)*16-1 downto PRODUCER_C_ID*16)));
                
                report "[Producer C RESULT] TID=" & integer'image(tid_val) &
                       " Result=" & real'image(result_val) &
                       " (waited " & integer'image(wait_cycles) & " cycles)";
                
                count := count + 1;
                wait_cycles := 0;
            elsif wait_cycles mod 100 = 0 then
                report "[Consumer C] Still waiting... (count=" & integer'image(count) &
                       "/" & integer'image(NUM_OPS_PER_PRODUCER) &
                       ", rd_valid=" & std_logic'image(output_rd_valid(PRODUCER_C_ID)) & ")";
            end if;
        end loop;
        
        report "Producer C: Collected all " & integer'image(count) & " results";
        wait;
    end process;
    
    -- Main control process
    main_control : process
    begin
        -- Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        report "========================================";
        report "Starting concurrent producer test";
        report "Producer A: " & integer'image(NUM_OPS_PER_PRODUCER) & " MULT operations";
        report "Producer B: " & integer'image(NUM_OPS_PER_PRODUCER) & " FMA operations";
        report "Producer C: " & integer'image(NUM_OPS_PER_PRODUCER) & " mixed MULT/FMA operations";
        report "========================================";
        
        -- Wait for all three producers to finish
        wait until producer_a_done and producer_b_done and producer_c_done;
        
        -- Give some time for results to propagate (FP latency + routing)
        wait for 5000 ns;
        
        report "========================================";
        report "Concurrent producer test complete!";
        report "========================================";
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor output valid signals and report changes
    output_valid_monitor : process(clk_in)
        variable prod0_valid_count : integer := 0;
        variable prod1_valid_count : integer := 0;
        variable prod2_valid_count : integer := 0;
    begin
        if rising_edge(clk_in) then
            if reset = '0' and clk_locked = '1' then
                if output_rd_valid(0) = '1' then
                    prod0_valid_count := prod0_valid_count + 1;
                    if prod0_valid_count <= 5 or prod0_valid_count mod 5 = 0 then
                        report "[FIFO Monitor] Producer 0 rd_valid asserted (count=" & 
                               integer'image(prod0_valid_count) & ")";
                    end if;
                end if;
                
                if output_rd_valid(1) = '1' then
                    prod1_valid_count := prod1_valid_count + 1;
                    if prod1_valid_count <= 5 or prod1_valid_count mod 5 = 0 then
                        report "[FIFO Monitor] Producer 1 rd_valid asserted (count=" & 
                               integer'image(prod1_valid_count) & ")";
                    end if;
                end if;
                
                if output_rd_valid(2) = '1' then
                    prod2_valid_count := prod2_valid_count + 1;
                    if prod2_valid_count <= 5 or prod2_valid_count mod 5 = 0 then
                        report "[FIFO Monitor] Producer 2 rd_valid asserted (count=" & 
                               integer'image(prod2_valid_count) & ")";
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Monitor inputs and update debug signals for waveform
    input_monitor : process(clk_in, reset)
        variable producer_id : integer;
        variable tid_val : integer;
    begin
        if reset = '1' then
            -- Initialize all debug signals to zero on reset
            prod0_wr_a_val <= (others => '0');
            prod0_wr_b_val <= (others => '0');
            prod0_wr_c_val <= (others => '0');
            prod0_wr_tid   <= (others => '0');
            prod0_wr_valid <= '0';
            prod1_wr_a_val <= (others => '0');
            prod1_wr_b_val <= (others => '0');
            prod1_wr_c_val <= (others => '0');
            prod1_wr_tid   <= (others => '0');
            prod1_wr_valid <= '0';
            prod2_wr_a_val <= (others => '0');
            prod2_wr_b_val <= (others => '0');
            prod2_wr_c_val <= (others => '0');
            prod2_wr_tid   <= (others => '0');
            prod2_wr_valid <= '0';
        elsif rising_edge(clk_in) then
            -- Default: clear valid flags but keep data (hold previous values)
            prod0_wr_valid <= '0';
            prod1_wr_valid <= '0';
            prod2_wr_valid <= '0';
            
            -- Monitor MULT operations - only update when valid
            for i in 0 to NUM_MULT_UNITS-1 loop
                if mult_wr_valid(i) = '1' then
                    tid_val := to_integer(unsigned(mult_wr_tid((i+1)*16-1 downto i*16)));
                    producer_id := tid_val / 8192;
                    
                    case producer_id is
                        when 0 =>
                            prod0_wr_a_val <= mult_wr_data(i*64+31 downto i*64);
                            prod0_wr_b_val <= mult_wr_data(i*64+63 downto i*64+32);
                            prod0_wr_c_val <= (others => '0');
                            prod0_wr_tid   <= mult_wr_tid((i+1)*16-1 downto i*16);
                            prod0_wr_valid <= '1';
                        when 1 =>
                            prod1_wr_a_val <= mult_wr_data(i*64+31 downto i*64);
                            prod1_wr_b_val <= mult_wr_data(i*64+63 downto i*64+32);
                            prod1_wr_c_val <= (others => '0');
                            prod1_wr_tid   <= mult_wr_tid((i+1)*16-1 downto i*16);
                            prod1_wr_valid <= '1';
                        when 2 =>
                            prod2_wr_a_val <= mult_wr_data(i*64+31 downto i*64);
                            prod2_wr_b_val <= mult_wr_data(i*64+63 downto i*64+32);
                            prod2_wr_c_val <= (others => '0');
                            prod2_wr_tid   <= mult_wr_tid((i+1)*16-1 downto i*16);
                            prod2_wr_valid <= '1';
                        when others => null;
                    end case;
                end if;
            end loop;
            
            -- Monitor FMA operations - only update when valid
            for i in 0 to NUM_FMA_UNITS-1 loop
                if fma_wr_valid(i) = '1' then
                    tid_val := to_integer(unsigned(fma_wr_tid((i+1)*16-1 downto i*16)));
                    producer_id := tid_val / 8192;
                    
                    case producer_id is
                        when 0 =>
                            prod0_wr_a_val <= fma_wr_data(i*96+31 downto i*96);
                            prod0_wr_b_val <= fma_wr_data(i*96+63 downto i*96+32);
                            prod0_wr_c_val <= fma_wr_data(i*96+95 downto i*96+64);
                            prod0_wr_tid   <= fma_wr_tid((i+1)*16-1 downto i*16);
                            prod0_wr_valid <= '1';
                        when 1 =>
                            prod1_wr_a_val <= fma_wr_data(i*96+31 downto i*96);
                            prod1_wr_b_val <= fma_wr_data(i*96+63 downto i*96+32);
                            prod1_wr_c_val <= fma_wr_data(i*96+95 downto i*96+64);
                            prod1_wr_tid   <= fma_wr_tid((i+1)*16-1 downto i*16);
                            prod1_wr_valid <= '1';
                        when 2 =>
                            prod2_wr_a_val <= fma_wr_data(i*96+31 downto i*96);
                            prod2_wr_b_val <= fma_wr_data(i*96+63 downto i*96+32);
                            prod2_wr_c_val <= fma_wr_data(i*96+95 downto i*96+64);
                            prod2_wr_tid   <= fma_wr_tid((i+1)*16-1 downto i*16);
                            prod2_wr_valid <= '1';
                        when others => null;
                    end case;
                end if;
            end loop;
        end if;
    end process;

end Behavioral;
