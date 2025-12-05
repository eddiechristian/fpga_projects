library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

-- 4x4 Matrix Multiplication (Sequential): C = A * B
-- Computes ONE ROW at a time (4 elements per cycle)
-- Each element requires 4 multiplications + 3 additions
-- 
-- Performance:
--   Latency: ~30 cycles per row (4 rows = 120 cycles total)
--   Throughput: Can pipeline - start new matrix every 30 cycles
--   Resource usage: 16x FP_MULT + 12x FP_ADD (4× less than parallel version)
--
-- Resource Estimate per module:
--   - 16 fp_mult × 3 DSPs = 48 DSPs
--   - 12 fp_add × 2 DSPs = 24 DSPs
--   - Total: ~72 DSPs (10% of Artix-7 xc7a200t)
--   - LUTs: ~3K (2% of 134K available)

entity mat4_mult_hw_sequential is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Mat4;
        b         : in  Mat4;
        c         : out Mat4;
        valid_out : out std_logic
    );
end entity mat4_mult_hw_sequential;

architecture behavioral of mat4_mult_hw_sequential is
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

    -- State machine to process one row at a time
    type state_type is (IDLE, ROW_X, ROW_Y, ROW_Z, ROW_W);
    signal state : state_type := IDLE;
    
    -- Array types for current row computation
    type fp32_array_4 is array (0 to 3) of fp32;
    type valid_array_4 is array (0 to 3) of std_logic;
    
    -- Current row being processed (0=x, 1=y, 2=z, 3=w)
    signal current_row : integer range 0 to 3 := 0;
    
    -- Multiplication results for current row: mult_result(col)(k)
    type mult_result_array is array (0 to 3, 0 to 3) of fp32;
    type mult_valid_array is array (0 to 3, 0 to 3) of std_logic;
    
    signal mult_result : mult_result_array;
    signal mult_valid  : mult_valid_array;
    
    -- Addition tree results: add_result(col, stage)
    type add_result_array is array (0 to 3, 0 to 2) of fp32;
    type add_valid_array is array (0 to 3, 0 to 2) of std_logic;
    
    signal add_result : add_result_array;
    signal add_valid  : add_valid_array;
    
    -- Matrix element accessors
    type mat4_accessor is array (0 to 3, 0 to 3) of fp32;
    
    -- Convert Mat4 to array for indexing
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
    
    -- Output registers to accumulate results
    signal c_x1, c_x2, c_x3, c_x4 : fp32;
    signal c_y1, c_y2, c_y3, c_y4 : fp32;
    signal c_z1, c_z2, c_z3, c_z4 : fp32;
    signal c_w1, c_w2, c_w3, c_w4 : fp32;

begin

    a_array <= mat4_to_array(a);
    b_array <= mat4_to_array(b);

    -- State machine to sequence through rows
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                current_row <= 0;
                valid_out <= '0';
            else
                case state is
                    when IDLE =>
                        valid_out <= '0';
                        if valid_in = '1' then
                            state <= ROW_X;
                            current_row <= 0;
                        end if;
                    
                    when ROW_X =>
                        if add_valid(3, 2) = '1' then  -- Last element of row complete
                            c_x1 <= add_result(0, 2);
                            c_x2 <= add_result(1, 2);
                            c_x3 <= add_result(2, 2);
                            c_x4 <= add_result(3, 2);
                            state <= ROW_Y;
                            current_row <= 1;
                        end if;
                    
                    when ROW_Y =>
                        if add_valid(3, 2) = '1' then
                            c_y1 <= add_result(0, 2);
                            c_y2 <= add_result(1, 2);
                            c_y3 <= add_result(2, 2);
                            c_y4 <= add_result(3, 2);
                            state <= ROW_Z;
                            current_row <= 2;
                        end if;
                    
                    when ROW_Z =>
                        if add_valid(3, 2) = '1' then
                            c_z1 <= add_result(0, 2);
                            c_z2 <= add_result(1, 2);
                            c_z3 <= add_result(2, 2);
                            c_z4 <= add_result(3, 2);
                            state <= ROW_W;
                            current_row <= 3;
                        end if;
                    
                    when ROW_W =>
                        if add_valid(3, 2) = '1' then
                            c_w1 <= add_result(0, 2);
                            c_w2 <= add_result(1, 2);
                            c_w3 <= add_result(2, 2);
                            c_w4 <= add_result(3, 2);
                            valid_out <= '1';  -- All rows complete
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Generate hardware for ONE ROW (4 columns) at a time
    gen_cols: for col in 0 to 3 generate
        
        -- Generate 4 multiplications per element (dot product)
        gen_mults: for k in 0 to 3 generate
            mult_inst : floating_point_mult
                port map (
                    aclk                 => clk,
                    s_axis_a_tvalid      => valid_in,
                    s_axis_a_tdata       => a_array(current_row, k),
                    s_axis_b_tvalid      => valid_in,
                    s_axis_b_tdata       => b_array(k, col),
                    m_axis_result_tvalid => mult_valid(col, k),
                    m_axis_result_tdata  => mult_result(col, k)
                );
        end generate gen_mults;
        
        -- Addition tree: reduce 4 mult results to 1 sum (3 adds)
        -- Stage 0: mult[0] + mult[1]
        add0_inst : floating_point_add
            port map (
                aclk                 => clk,
                s_axis_a_tvalid      => mult_valid(col, 0),
                s_axis_a_tdata       => mult_result(col, 0),
                s_axis_b_tvalid      => mult_valid(col, 1),
                s_axis_b_tdata       => mult_result(col, 1),
                m_axis_result_tvalid => add_valid(col, 0),
                m_axis_result_tdata  => add_result(col, 0)
            );
        
        -- Stage 1: add[0] + mult[2]
        add1_inst : floating_point_add
            port map (
                aclk                 => clk,
                s_axis_a_tvalid      => add_valid(col, 0),
                s_axis_a_tdata       => add_result(col, 0),
                s_axis_b_tvalid      => mult_valid(col, 2),
                s_axis_b_tdata       => mult_result(col, 2),
                m_axis_result_tvalid => add_valid(col, 1),
                m_axis_result_tdata  => add_result(col, 1)
            );
        
        -- Stage 2: add[1] + mult[3] = final result
        add2_inst : floating_point_add
            port map (
                aclk                 => clk,
                s_axis_a_tvalid      => add_valid(col, 1),
                s_axis_a_tdata       => add_result(col, 1),
                s_axis_b_tvalid      => mult_valid(col, 3),
                s_axis_b_tdata       => mult_result(col, 3),
                m_axis_result_tvalid => add_valid(col, 2),
                m_axis_result_tdata  => add_result(col, 2)
            );
            
    end generate gen_cols;

    -- Assign accumulated outputs
    c.x1 <= c_x1;
    c.x2 <= c_x2;
    c.x3 <= c_x3;
    c.x4 <= c_x4;
    
    c.y1 <= c_y1;
    c.y2 <= c_y2;
    c.y3 <= c_y3;
    c.y4 <= c_y4;
    
    c.z1 <= c_z1;
    c.z2 <= c_z2;
    c.z3 <= c_z3;
    c.z4 <= c_z4;
    
    c.w1 <= c_w1;
    c.w2 <= c_w2;
    c.w3 <= c_w3;
    c.w4 <= c_w4;

end architecture behavioral;
