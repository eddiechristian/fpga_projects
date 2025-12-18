LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;

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

ENTITY mat4_mult_hw IS
    PORT (
        clk       : IN STD_LOGIC;
        reset     : IN STD_LOGIC;
        valid_in  : IN STD_LOGIC;
        a         : IN Mat4;
        b         : IN Mat4;
        tid_in    : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        c         : OUT Mat4;
        tid_out   : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        valid_out : OUT STD_LOGIC
    );
END ENTITY mat4_mult_hw;

ARCHITECTURE behavioral OF mat4_mult_hw IS
    COMPONENT floating_point_mult
        PORT (
            aclk                    : IN STD_LOGIC;
            s_axis_a_tvalid         : IN STD_LOGIC;
            s_axis_a_tdata          : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_b_tvalid         : IN STD_LOGIC;
            s_axis_b_tdata          : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_result_tvalid    : OUT STD_LOGIC;
            m_axis_result_tdata     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;
    
    COMPONENT floating_point_addsub
        PORT (
            aclk                    : IN STD_LOGIC;
            s_axis_a_tvalid         : IN STD_LOGIC;
            s_axis_a_tdata          : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_b_tvalid         : IN STD_LOGIC;
            s_axis_b_tdata          : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_operation_tvalid : IN STD_LOGIC;
            s_axis_operation_tdata  : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            m_axis_result_tvalid    : OUT STD_LOGIC;
            m_axis_result_tdata     : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;
    
    CONSTANT OP_ADD : STD_LOGIC_VECTOR(7 DOWNTO 0) := X"00";

    -- Array types for generate loops
    TYPE fp32_array IS ARRAY (0 TO 3, 0 TO 3) OF fp32;
    TYPE valid_array IS ARRAY (0 TO 3, 0 TO 3) OF STD_LOGIC;
    
    -- TID pipeline (depth matches FP pipeline latency)
    TYPE tid_array IS ARRAY (0 TO 15) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL tid_pipe : tid_array;
    
    -- Intermediate multiplication results: mult_result(row, col)(k) = a(row, k) * b(k, col)
    TYPE mult_result_array IS ARRAY (0 TO 3, 0 TO 3, 0 TO 3) OF fp32;
    TYPE mult_valid_array IS ARRAY (0 TO 3, 0 TO 3, 0 TO 3) OF STD_LOGIC;
    
    SIGNAL mult_result : mult_result_array;
    SIGNAL mult_valid  : mult_valid_array;
    
    -- Addition tree results: add_result(row, col, stage)
    -- stage 0: mult[0] + mult[1]
    -- stage 1: add[0] + mult[2]  
    -- stage 2: add[1] + mult[3] = final result
    TYPE add_result_array IS ARRAY (0 TO 3, 0 TO 3, 0 TO 2) OF fp32;
    TYPE add_valid_array IS ARRAY (0 TO 3, 0 TO 3, 0 TO 2) OF STD_LOGIC;
    
    SIGNAL add_result : add_result_array;
    SIGNAL add_valid  : add_valid_array;
    
    -- Matrix element accessors (row-major indexing)
    TYPE mat4_accessor IS ARRAY (0 TO 3, 0 TO 3) OF fp32;
    
    -- Convert Mat4 record to array for indexing
    FUNCTION mat4_to_array(m : Mat4) RETURN mat4_accessor IS
        VARIABLE result : mat4_accessor;
    BEGIN
        result(0, 0) := m.x1; result(0, 1) := m.x2; result(0, 2) := m.x3; result(0, 3) := m.x4;
        result(1, 0) := m.y1; result(1, 1) := m.y2; result(1, 2) := m.y3; result(1, 3) := m.y4;
        result(2, 0) := m.z1; result(2, 1) := m.z2; result(2, 2) := m.z3; result(2, 3) := m.z4;
        result(3, 0) := m.w1; result(3, 1) := m.w2; result(3, 2) := m.w3; result(3, 3) := m.w4;
        RETURN result;
    END FUNCTION;
    
    SIGNAL a_array, b_array : mat4_accessor;

BEGIN

    -- TID pipeline to track transaction IDs through computation
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                tid_pipe <= (OTHERS => (OTHERS => '0'));
            ELSE
                tid_pipe(0) <= tid_in;
                FOR i IN 1 TO 15 LOOP
                    tid_pipe(i) <= tid_pipe(i-1);
                END LOOP;
            END IF;
        END IF;
    END PROCESS;

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
            add0_inst : floating_point_addsub
                PORT MAP (
                    aclk                    => clk,
                    s_axis_a_tvalid         => mult_valid(row, col, 0),
                    s_axis_a_tdata          => mult_result(row, col, 0),
                    s_axis_b_tvalid         => mult_valid(row, col, 1),
                    s_axis_b_tdata          => mult_result(row, col, 1),
                    s_axis_operation_tvalid => mult_valid(row, col, 0),
                    s_axis_operation_tdata  => OP_ADD,
                    m_axis_result_tvalid    => add_valid(row, col, 0),
                    m_axis_result_tdata     => add_result(row, col, 0)
                );
            
            -- Stage 1: mult[2] + mult[3]
            add1_inst : floating_point_addsub
                PORT MAP (
                    aclk                    => clk,
                    s_axis_a_tvalid         => mult_valid(row, col, 2),
                    s_axis_a_tdata          => mult_result(row, col, 2),
                    s_axis_b_tvalid         => mult_valid(row, col, 3),
                    s_axis_b_tdata          => mult_result(row, col, 3),
                    s_axis_operation_tvalid => mult_valid(row, col, 2),
                    s_axis_operation_tdata  => OP_ADD,
                    m_axis_result_tvalid    => add_valid(row, col, 1),
                    m_axis_result_tdata     => add_result(row, col, 1)
                );
            
            -- Stage 2: add[0] + add[1] = final result
            add2_inst : floating_point_addsub
                PORT MAP (
                    aclk                    => clk,
                    s_axis_a_tvalid         => add_valid(row, col, 0),
                    s_axis_a_tdata          => add_result(row, col, 0),
                    s_axis_b_tvalid         => add_valid(row, col, 1),
                    s_axis_b_tdata          => add_result(row, col, 1),
                    s_axis_operation_tvalid => add_valid(row, col, 0),
                    s_axis_operation_tdata  => OP_ADD,
                    m_axis_result_tvalid    => add_valid(row, col, 2),
                    m_axis_result_tdata     => add_result(row, col, 2)
                );
                
        END GENERATE gen_cols;
    END GENERATE gen_rows;

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
    
    -- TID output (pipeline depth ~14 cycles: 2 mult + 3*2 add)
    tid_out <= tid_pipe(13);

END ARCHITECTURE behavioral;
