library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
use work.lin_alg_pkg.all;
use work.crossbar_pkg.all;

-- Hardware Vec4 dot product: result = a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w
-- Uses 4 floating-point multipliers and 3 floating-point adders
-- 
-- Pipeline stages:
--   Stage 1: 4 parallel multiplications (FP_LATENCY cycles)
--   Stage 2: Add mult_x + mult_y in parallel with mult_z + mult_w (FP_LATENCY cycles)
--   Stage 3: Add sum_xy + sum_zw (FP_LATENCY cycles)
-- 
-- Performance:
--   Total Latency: 3 * FP_LATENCY clock cycles (currently 6 cycles)
--   Throughput: 1 result per cycle (fully pipelined)
--   Resource usage: 4x FP_MULT + 3x FP_ADDSUB cores
--   
-- Note: Uses balanced tree addition for better performance
entity vec4_dot_hw is
    port (
        clk          : in  std_logic;
        aresetn      : in  std_logic;  -- Active-LOW reset (to match crossbar)
        input_valid  : in  std_logic;
        input_tid    : in  STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
        a            : in  Vec4;
        b            : in  Vec4;
        result       : out fp32;
        valid_out    : out std_logic;
        output_tid   : out STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0)
    );
end entity vec4_dot_hw;

architecture behavioral of vec4_dot_hw is
    
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
    
    -- Stage 1: Multiplication results (4 parallel mults)
    signal mult_x, mult_y, mult_z, mult_w : fp32;
    signal mult_x_valid, mult_y_valid, mult_z_valid, mult_w_valid : std_logic;
    
    -- Stage 2: First level additions (mult_x + mult_y) and (mult_z + mult_w)
    signal sum_xy, sum_zw : fp32;
    signal sum_xy_valid, sum_zw_valid : std_logic;
    
    -- Stage 3: Final addition (sum_xy + sum_zw)
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
    
    -- Stage 1: Multiply corresponding components (4 parallel multiplications)
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
    
    mult_w_inst : floating_point_mult
        port map (
            aclk                 => clk,
            s_axis_a_tvalid      => input_valid,
            s_axis_a_tdata       => a.w,
            s_axis_b_tvalid      => input_valid,
            s_axis_b_tdata       => b.w,
            m_axis_result_tvalid => mult_w_valid,
            m_axis_result_tdata  => mult_w
        );
    
    -- Stage 2: Add pairs in parallel (mult_x + mult_y) and (mult_z + mult_w)
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
    
    add_zw_inst : floating_point_addsub
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => mult_z_valid,
            s_axis_a_tdata          => mult_z,
            s_axis_b_tvalid         => mult_w_valid,
            s_axis_b_tdata          => mult_w,
            s_axis_operation_tvalid => mult_z_valid,
            s_axis_operation_tdata  => X"00",  -- ADD operation
            m_axis_result_tvalid    => sum_zw_valid,
            m_axis_result_tdata     => sum_zw
        );
    
    -- Stage 3: Final addition (sum_xy + sum_zw)
    add_final_inst : floating_point_addsub
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => sum_xy_valid,
            s_axis_a_tdata          => sum_xy,
            s_axis_b_tvalid         => sum_zw_valid,
            s_axis_b_tdata          => sum_zw,
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
                    report "DOT4_HW: Started computation, TID=" & integer'image(to_integer(unsigned(input_tid)));
                end if;
                
                -- Report mult stage
                if mult_x_valid = '1' or mult_y_valid = '1' or mult_z_valid = '1' or mult_w_valid = '1' then
                    report "DOT4_HW: MULT stage - x='" & std_logic'image(mult_x_valid) & 
                           "' y='" & std_logic'image(mult_y_valid) & 
                           "' z='" & std_logic'image(mult_z_valid) &
                           "' w='" & std_logic'image(mult_w_valid) & "'";
                end if;
                
                -- Report first add stage
                if sum_xy_valid = '1' or sum_zw_valid = '1' then
                    report "DOT4_HW: First ADD stage complete";
                end if;
                
                -- Report when result is ready
                if final_valid = '1' then
                    report "DOT4_HW: Result ready, TID=" & integer'image(to_integer(unsigned(tid_pipeline(TID_PIPELINE_DEPTH-1))));
                end if;
            end if;
        end if;
    end process;
    
    -- Output TID from end of pipeline
    output_tid <= tid_pipeline(TID_PIPELINE_DEPTH-1);
    
end architecture behavioral;
