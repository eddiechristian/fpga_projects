library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

-- 4x4 Matrix Multiplication (Parallel): C = A * B
-- Computes ALL 16 ELEMENTS in parallel
-- Each element requires 4 multiplications + 3 additions
--
-- Performance:
--   Latency: ~30 cycles total (all rows computed together)
--   Throughput: Can start new matrix every cycle (fully pipelined)
--   Resource usage: 64x FP_MULT + 48x FP_ADD
--
-- Resource Estimate per module:
--   - 64 fp_mult × 3 DSPs = 192 DSPs
--   - 48 fp_add × 2 DSPs = 96 DSPs
--   - Total: ~288 DSPs (39% of Artix-7 xc7a200t - can fit 2 modules)
--   - LUTs: ~12K (9% of 134K available)

entity mat4_mult_hw is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Mat4;
        b         : in  Mat4;
        c         : out Mat4;
        valid_out : out std_logic
    );
end entity mat4_mult_hw;

architecture behavioral of mat4_mult_hw is
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
    
    component floating_point_add
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

    -- Array types for generate loops
    type fp32_array is array (0 to 3, 0 to 3) of fp32;
    type valid_array is array (0 to 3, 0 to 3) of std_logic;
    
    -- Intermediate multiplication results: mult_result(row, col)(k) = a(row, k) * b(k, col)
    type mult_result_array is array (0 to 3, 0 to 3, 0 to 3) of fp32;
    type mult_valid_array is array (0 to 3, 0 to 3, 0 to 3) of std_logic;
    
    signal mult_result : mult_result_array;
    signal mult_valid  : mult_valid_array;
    
    -- Addition tree results: add_result(row, col, stage)
    -- stage 0: mult[0] + mult[1]
    -- stage 1: add[0] + mult[2]  
    -- stage 2: add[1] + mult[3] = final result
    type add_result_array is array (0 to 3, 0 to 3, 0 to 2) of fp32;
    type add_valid_array is array (0 to 3, 0 to 3, 0 to 2) of std_logic;
    
    signal add_result : add_result_array;
    signal add_valid  : add_valid_array;
    
    -- Matrix element accessors (row-major indexing)
    type mat4_accessor is array (0 to 3, 0 to 3) of fp32;
    
    -- Convert Mat4 record to array for indexing
    function mat4_to_array(m : Mat4) return mat4_accessor is
        variable result : mat4_accessor;
    begin
        result(0, 0) := m.x1; result(0, 1) := m.x2; result(0, 2) := m.x3; result(0, 3) := m.x4;
        result(1, 0) := m.y1; result(1, 1) := m.y2; result(1, 2) := m.y3; result(1, 3) := m.y4;
        result(2, 0) := m.z1; result(2, 1) := m.z2; result(2, 2) := m.z3; result(2, 3) := m.z4;
        result(3, 0) := m.w1; result(3, 1) := m.w2; result(3, 2) := m.w3; result(3, 3) := m.w4;
        return result;
    end function;
    
    signal a_array, b_array : mat4_accessor;

begin

    -- Convert inputs to arrays
    a_array <= mat4_to_array(a);
    b_array <= mat4_to_array(b);

    -- Generate 4x4 = 16 dot products in parallel
    gen_rows: for row in 0 to 3 generate
        gen_cols: for col in 0 to 3 generate
            
            -- Generate 4 multiplications per element (dot product)
            gen_mults: for k in 0 to 3 generate
                mult_inst : floating_point_mult
                    port map (
                        aclk                 => clk,
                        s_axis_a_tvalid      => valid_in,
                        s_axis_a_tdata       => a_array(row, k),
                        s_axis_b_tvalid      => valid_in,
                        s_axis_b_tdata       => b_array(k, col),
                        m_axis_result_tvalid => mult_valid(row, col, k),
                        m_axis_result_tdata  => mult_result(row, col, k)
                    );
            end generate gen_mults;
            
            -- Addition tree: reduce 4 mult results to 1 sum (3 adds)
            -- Stage 0: mult[0] + mult[1]
            add0_inst : floating_point_add
                port map (
                    aclk                 => clk,
                    s_axis_a_tvalid      => mult_valid(row, col, 0),
                    s_axis_a_tdata       => mult_result(row, col, 0),
                    s_axis_b_tvalid      => mult_valid(row, col, 1),
                    s_axis_b_tdata       => mult_result(row, col, 1),
                    m_axis_result_tvalid => add_valid(row, col, 0),
                    m_axis_result_tdata  => add_result(row, col, 0)
                );
            
            -- Stage 1: add[0] + mult[2]
            add1_inst : floating_point_add
                port map (
                    aclk                 => clk,
                    s_axis_a_tvalid      => add_valid(row, col, 0),
                    s_axis_a_tdata       => add_result(row, col, 0),
                    s_axis_b_tvalid      => mult_valid(row, col, 2),
                    s_axis_b_tdata       => mult_result(row, col, 2),
                    m_axis_result_tvalid => add_valid(row, col, 1),
                    m_axis_result_tdata  => add_result(row, col, 1)
                );
            
            -- Stage 2: add[1] + mult[3] = final result
            add2_inst : floating_point_add
                port map (
                    aclk                 => clk,
                    s_axis_a_tvalid      => add_valid(row, col, 1),
                    s_axis_a_tdata       => add_result(row, col, 1),
                    s_axis_b_tvalid      => mult_valid(row, col, 3),
                    s_axis_b_tdata       => mult_result(row, col, 3),
                    m_axis_result_tvalid => add_valid(row, col, 2),
                    m_axis_result_tdata  => add_result(row, col, 2)
                );
                
        end generate gen_cols;
    end generate gen_rows;

    -- Assign outputs
    c.x1 <= add_result(0, 0, 2);
    c.x2 <= add_result(0, 1, 2);
    c.x3 <= add_result(0, 2, 2);
    c.x4 <= add_result(0, 3, 2);
    
    c.y1 <= add_result(1, 0, 2);
    c.y2 <= add_result(1, 1, 2);
    c.y3 <= add_result(1, 2, 2);
    c.y4 <= add_result(1, 3, 2);
    
    c.z1 <= add_result(2, 0, 2);
    c.z2 <= add_result(2, 1, 2);
    c.z3 <= add_result(2, 2, 2);
    c.z4 <= add_result(2, 3, 2);
    
    c.w1 <= add_result(3, 0, 2);
    c.w2 <= add_result(3, 1, 2);
    c.w3 <= add_result(3, 2, 2);
    c.w4 <= add_result(3, 3, 2);
    
    -- Valid out when last element completes
    valid_out <= add_valid(3, 3, 2);

end architecture behavioral;
