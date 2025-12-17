library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
use work.lin_alg_pkg.all;
use work.crossbar_pkg.all;

-- Hardware Vec3 dot product: result = a.x*b.x + a.y*b.y + a.z*b.z
-- Uses 3 floating-point multipliers and 2 floating-point adders
-- 
-- Pipeline stages:
--   Stage 1: 3 parallel multiplications (FP_LATENCY cycles)
--   Stage 2: Add mult_x + mult_y (FP_LATENCY cycles)
--   Stage 3: Add sum_xy + mult_z (FP_LATENCY cycles)
-- 
-- Performance:
--   Total Latency: 3 * FP_LATENCY clock cycles (currently 6 cycles)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 3x FP_MULT + 2x FP_ADDSUB cores
--   
-- Note: The addition stages must be sequential (cannot be parallelized further)
-- because we need to sum 3 values which requires 2 addition operations.
entity vec3_dot_hw is
    port (
        clk          : in  std_logic;
        aresetn      : in  std_logic;  -- Active-LOW reset (to match crossbar)
        input_valid  : in  std_logic;
        input_tid    : in  STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
        a            : in  Vec3;
        b            : in  Vec3;
        result       : out fp32;
        valid_out    : out std_logic;
        output_tid   : out STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0)
    );
end entity vec3_dot_hw;

architecture behavioral of vec3_dot_hw is
    
    component floating_point_mult
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_b_tvalid         : in  STD_LOGIC;
            s_axis_b_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    component floating_point_addsub
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_b_tvalid         : in  STD_LOGIC;
            s_axis_b_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_operation_tvalid : in  STD_LOGIC;
            s_axis_operation_tdata  : in  STD_LOGIC_VECTOR(7 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;
    
    -- Stage 1: Multiplication results
    signal mult_x, mult_y, mult_z : fp32;
    signal mult_x_valid, mult_y_valid, mult_z_valid : std_logic;
    
    -- Stage 2: First addition result (mult_x + mult_y)
    signal sum_xy : fp32;
    signal sum_xy_valid : std_logic;
    
    -- Delay mult_z to align with sum_xy (need FP_LATENCY cycles delay)
    type fp32_delay_t is array (0 to FP_LATENCY-1) of fp32;
    signal mult_z_delay : fp32_delay_t := (others => (others => '0'));
    signal mult_z_delayed : fp32;
    type valid_delay_t is array (0 to FP_LATENCY-1) of std_logic;
    signal mult_z_valid_delay : valid_delay_t := (others => '0');
    signal mult_z_valid_delayed : std_logic;
    
    -- Stage 3: Final addition result (sum_xy + mult_z_delayed)
    signal final_valid : std_logic;
    
    -- TID pipeline (3*FP_LATENCY cycle delay to match FP pipeline)
    -- Stage 1: MULT = FP_LATENCY cycles
    -- Stage 2: ADD  = FP_LATENCY cycles  
    -- Stage 3: ADD  = FP_LATENCY cycles
    -- Total: 3*FP_LATENCY cycles
    constant TID_PIPELINE_DEPTH : integer := 3 * FP_LATENCY;
    type tid_pipeline_t is array (0 to TID_PIPELINE_DEPTH-1) of STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    signal tid_pipeline : tid_pipeline_t := (others => (others => '0'));
    
begin
    
    -- Stage 1: Multiply corresponding components
    mult_x_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => input_valid,
            s_axis_a_tdata       => a.x,
            s_axis_b_tvalid      => input_valid,
            s_axis_b_tdata       => b.x,
            m_axis_result_tvalid => mult_x_valid,
            m_axis_result_tdata  => mult_x
        );
    
    mult_y_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => input_valid,
            s_axis_a_tdata       => a.y,
            s_axis_b_tvalid      => input_valid,
            s_axis_b_tdata       => b.y,
            m_axis_result_tvalid => mult_y_valid,
            m_axis_result_tdata  => mult_y
        );
    
    mult_z_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => input_valid,
            s_axis_a_tdata       => a.z,
            s_axis_b_tvalid      => input_valid,
            s_axis_b_tdata       => b.z,
            m_axis_result_tvalid => mult_z_valid,
            m_axis_result_tdata  => mult_z
        );
    
    -- Stage 2: Add first two products (operation=0 for ADD)
    add_xy_inst : floating_point_addsub
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => mult_x_valid,
            s_axis_a_tdata          => mult_x,
            s_axis_b_tvalid         => mult_y_valid,
            s_axis_b_tdata          => mult_y,
            s_axis_operation_tvalid => mult_x_valid,
            s_axis_operation_tdata  => X"00",  -- ADD operation
            m_axis_result_tvalid    => sum_xy_valid,
            m_axis_result_tdata     => sum_xy
        );
    
    -- Delay mult_z to align with sum_xy timing
    process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                mult_z_delay <= (others => (others => '0'));
                mult_z_valid_delay <= (others => '0');
            else
                mult_z_delay(0) <= mult_z;
                mult_z_valid_delay(0) <= mult_z_valid;
                for i in 1 to FP_LATENCY-1 loop
                    mult_z_delay(i) <= mult_z_delay(i-1);
                    mult_z_valid_delay(i) <= mult_z_valid_delay(i-1);
                end loop;
            end if;
        end if;
    end process;
    
    mult_z_delayed <= mult_z_delay(FP_LATENCY-1);
    mult_z_valid_delayed <= mult_z_valid_delay(FP_LATENCY-1);
    
    -- Stage 3: Add third product to the sum (operation=0 for ADD)
    add_final_inst : floating_point_addsub
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => sum_xy_valid,
            s_axis_a_tdata          => sum_xy,
            s_axis_b_tvalid         => mult_z_valid_delayed,
            s_axis_b_tdata          => mult_z_delayed,
            s_axis_operation_tvalid => sum_xy_valid,
            s_axis_operation_tdata  => X"00",  -- ADD operation
            m_axis_result_tvalid    => final_valid,
            m_axis_result_tdata     => result
        );
    
    valid_out <= final_valid;
    
    -- TID pipeline process
    process(clk)
    begin
        if rising_edge(clk) then
            if aresetn = '0' then  -- Active-LOW reset
                tid_pipeline <= (others => (others => '0'));
            else
                -- Shift TID through pipeline
                tid_pipeline(0) <= input_tid;
                for i in 1 to TID_PIPELINE_DEPTH-1 loop
                    tid_pipeline(i) <= tid_pipeline(i-1);
                end loop;
                
                -- Report when new request enters
                if input_valid = '1' then
                    report "DOT_HW: Started computation, TID=" & integer'image(to_integer(unsigned(input_tid)));
                end if;
                
                -- Report mult stage
                if mult_x_valid = '1' or mult_y_valid = '1' or mult_z_valid = '1' then
                    report "DOT_HW: MULT stage - x=" & std_logic'image(mult_x_valid) & 
                           " y=" & std_logic'image(mult_y_valid) & 
                           " z=" & std_logic'image(mult_z_valid);
                end if;
                
                -- Report add stages
                if sum_xy_valid = '1' then
                    report "DOT_HW: First ADD stage complete";
                end if;
                
                -- Report when result exits
                if final_valid = '1' then
                    report "DOT_HW: Result ready, TID=" & integer'image(to_integer(unsigned(tid_pipeline(TID_PIPELINE_DEPTH-1))));
                end if;
            end if;
        end if;
    end process;
    
    -- Output TID from end of pipeline
    output_tid <= tid_pipeline(TID_PIPELINE_DEPTH-1);
    
end architecture behavioral;
