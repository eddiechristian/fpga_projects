library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity pipeline_hw_tb is
end pipeline_hw_tb;

architecture Behavioral of pipeline_hw_tb is

    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    constant NUM_MULT_UNITS : integer := 8;
    constant NUM_FMA_UNITS : integer := 5;
    constant NUM_ADD_UNITS : integer := 3;
    constant NUM_PRODUCERS : integer := 5;
    
    constant NUM_OPS_PER_TYPE : integer := 10;  -- 10 mult, 10 FMA, 10 add, 10 sub
    
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
    
    -- Counter for round-robin unit selection
    shared variable mult_unit_idx : integer := 0;
    shared variable fma_unit_idx : integer := 0;
    shared variable add_unit_idx : integer := 0;
    shared variable sub_unit_idx : integer := 0;
    
    signal sim_done : boolean := false;

begin

    -- Clock generation
    clk_in <= not clk_in after CLK_PERIOD / 2 when not sim_done else '0';
    
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
    
    -- Stimulus process
    stimulus : process
        variable seed1, seed2 : integer := 42;
        variable rand : real;
        variable a_val, b_val, c_val : real;
        variable a_fp, b_fp, c_fp : std_logic_vector(31 downto 0);
        variable tid_val : std_logic_vector(15 downto 0);
        variable producer_id : integer;
        variable op_count : integer := 0;
    begin
        -- Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait until clk_locked = '1';
        wait for 20 ns;
        
        report "Starting stimulus...";
        
        -- Generate multiply operations (round-robin across mult units)
        for i in 0 to NUM_OPS_PER_TYPE-1 loop
            uniform(seed1, seed2, rand);
            a_val := rand * 4.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 4.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            
            producer_id := i mod NUM_PRODUCERS;
            tid_val := std_logic_vector(to_unsigned(producer_id * 8192 + i, 16));
            
            -- Target next mult unit (round-robin)
            wait until rising_edge(clk_in);
            mult_wr_data((mult_unit_idx+1)*64-1 downto mult_unit_idx*64) <= b_fp & a_fp;
            mult_wr_tid((mult_unit_idx+1)*16-1 downto mult_unit_idx*16) <= tid_val;
            mult_wr_valid(mult_unit_idx) <= '1';
            
            wait until rising_edge(clk_in) and mult_wr_ready(mult_unit_idx) = '1';
            mult_wr_valid(mult_unit_idx) <= '0';
            
            report "[INPUT] Op=MULT Unit=" & integer'image(mult_unit_idx) & 
                   " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                   " Prod=" & integer'image(producer_id) &
                   " A=" & real'image(a_val) & " B=" & real'image(b_val);
            
            mult_unit_idx := (mult_unit_idx + 1) mod NUM_MULT_UNITS;
            op_count := op_count + 1;
        end loop;
        
        -- Generate FMA operations
        for i in 0 to NUM_OPS_PER_TYPE-1 loop
            uniform(seed1, seed2, rand);
            a_val := rand * 4.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 4.0;
            uniform(seed1, seed2, rand);
            c_val := rand * 4.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            c_fp := to_fp32(c_val);
            
            producer_id := i mod NUM_PRODUCERS;
            tid_val := std_logic_vector(to_unsigned(producer_id * 8192 + NUM_OPS_PER_TYPE + i, 16));
            
            wait until rising_edge(clk_in);
            fma_wr_data((fma_unit_idx+1)*96-1 downto fma_unit_idx*96) <= c_fp & b_fp & a_fp;
            fma_wr_tid((fma_unit_idx+1)*16-1 downto fma_unit_idx*16) <= tid_val;
            fma_wr_valid(fma_unit_idx) <= '1';
            
            wait until rising_edge(clk_in) and fma_wr_ready(fma_unit_idx) = '1';
            fma_wr_valid(fma_unit_idx) <= '0';
            
            report "[INPUT] Op=FMA Unit=" & integer'image(fma_unit_idx) & 
                   " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                   " Prod=" & integer'image(producer_id) &
                   " A=" & real'image(a_val) & " B=" & real'image(b_val) & " C=" & real'image(c_val);
            
            fma_unit_idx := (fma_unit_idx + 1) mod NUM_FMA_UNITS;
            op_count := op_count + 1;
        end loop;
        
        -- Generate ADD operations
        for i in 0 to NUM_OPS_PER_TYPE-1 loop
            uniform(seed1, seed2, rand);
            a_val := rand * 4.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 4.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            
            producer_id := i mod NUM_PRODUCERS;
            tid_val := std_logic_vector(to_unsigned(producer_id * 8192 + 2*NUM_OPS_PER_TYPE + i, 16));
            
            wait until rising_edge(clk_in);
            addsub_wr_data((add_unit_idx+1)*65-1 downto add_unit_idx*65) <= '0' & b_fp & a_fp;  -- op=0 (add)
            addsub_wr_tid((add_unit_idx+1)*16-1 downto add_unit_idx*16) <= tid_val;
            addsub_wr_valid(add_unit_idx) <= '1';
            
            wait until rising_edge(clk_in) and addsub_wr_ready(add_unit_idx) = '1';
            addsub_wr_valid(add_unit_idx) <= '0';
            
            report "[INPUT] Op=ADD Unit=" & integer'image(add_unit_idx) & 
                   " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                   " Prod=" & integer'image(producer_id) &
                   " A=" & real'image(a_val) & " B=" & real'image(b_val);
            
            add_unit_idx := (add_unit_idx + 1) mod NUM_ADD_UNITS;
            op_count := op_count + 1;
        end loop;
        
        -- Generate SUB operations
        for i in 0 to NUM_OPS_PER_TYPE-1 loop
            uniform(seed1, seed2, rand);
            a_val := rand * 4.0;
            uniform(seed1, seed2, rand);
            b_val := rand * 4.0;
            
            a_fp := to_fp32(a_val);
            b_fp := to_fp32(b_val);
            
            producer_id := i mod NUM_PRODUCERS;
            tid_val := std_logic_vector(to_unsigned(producer_id * 8192 + 3*NUM_OPS_PER_TYPE + i, 16));
            
            wait until rising_edge(clk_in);
            addsub_wr_data((sub_unit_idx+1)*65-1 downto sub_unit_idx*65) <= '1' & b_fp & a_fp;  -- op=1 (sub)
            addsub_wr_tid((sub_unit_idx+1)*16-1 downto sub_unit_idx*16) <= tid_val;
            addsub_wr_valid(sub_unit_idx) <= '1';
            
            wait until rising_edge(clk_in) and addsub_wr_ready(sub_unit_idx) = '1';
            addsub_wr_valid(sub_unit_idx) <= '0';
            
            report "[INPUT] Op=SUB Unit=" & integer'image(sub_unit_idx) & 
                   " TID=" & integer'image(to_integer(unsigned(tid_val))) &
                   " Prod=" & integer'image(producer_id) &
                   " A=" & real'image(a_val) & " B=" & real'image(b_val);
            
            sub_unit_idx := (sub_unit_idx + 1) mod NUM_ADD_UNITS;
            op_count := op_count + 1;
        end loop;
        
        report "All " & integer'image(op_count) & " operations sent";
        wait;
    end process;
    
    -- Output collection process
    output_collection : process
        variable output_count : integer := 0;
        variable expected_total : integer := NUM_OPS_PER_TYPE * 4;  -- mult, FMA, add, sub
        variable result_val : real;
        variable tid_val : integer;
        variable producer_id : integer;
    begin
        wait until reset = '0' and clk_locked = '1';
        
        -- Always ready to accept outputs
        output_rd_ready <= (others => '1');
        
        while output_count < expected_total loop
            wait until rising_edge(clk_in);
            
            for prod in 0 to NUM_PRODUCERS-1 loop
                if output_rd_valid(prod) = '1' and output_rd_ready(prod) = '1' then
                    result_val := from_fp32(output_rd_data((prod+1)*32-1 downto prod*32));
                    tid_val := to_integer(unsigned(output_rd_tid((prod+1)*16-1 downto prod*16)));
                    producer_id := tid_val / 8192;
                    
                    report "[OUTPUT] Prod=" & integer'image(prod) &
                           " TID=" & integer'image(tid_val) &
                           " Result=" & real'image(result_val);
                    
                    output_count := output_count + 1;
                end if;
            end loop;
        end loop;
        
        report "Simulation complete: Collected " & integer'image(output_count) & " outputs";
        sim_done <= true;
        wait;
    end process;

end Behavioral;
