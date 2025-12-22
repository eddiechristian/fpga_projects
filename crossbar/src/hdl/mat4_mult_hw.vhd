LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.crossbar_pkg.ALL;

-- 4x4 Matrix Multiplication (Parallel): C = A * B
-- Uses 16 Vec4 dot product units to compute all 16 elements in parallel
-- Each element C[i,j] = dot(row_i(A), col_j(B))
--
-- Performance:
--   Latency: 6 cycles (DOT4 latency)
--   Throughput: Can start new matrix every cycle (fully pipelined)
--   Resource usage: 16x DOT4 units
--
-- Resource Estimate per module:
--   - 16 DOT4 units × 14 DSPs = 224 DSPs (~30% of Artix-7 xc7a200t)
--   - LUTs: ~8K (6% of 134K available)

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

    -- Matrix rows and columns as Vec4
    TYPE vec4_array IS ARRAY (0 TO 3) OF Vec4;
    SIGNAL a_rows : vec4_array;  -- Rows of matrix A
    SIGNAL b_cols : vec4_array;  -- Columns of matrix B
    
    -- DOT4 results: result(row, col)
    TYPE fp32_array IS ARRAY (0 TO 3, 0 TO 3) OF fp32;
    TYPE valid_array IS ARRAY (0 TO 3, 0 TO 3) OF STD_LOGIC;
    TYPE tid_array_2d IS ARRAY (0 TO 3, 0 TO 3) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    
    SIGNAL dot_results : fp32_array;
    SIGNAL dot_valids  : valid_array;
    SIGNAL dot_tids    : tid_array_2d;

BEGIN

    -- Extract rows from matrix A
    a_rows(0).x <= a.x1; a_rows(0).y <= a.x2; a_rows(0).z <= a.x3; a_rows(0).w <= a.x4;
    a_rows(1).x <= a.y1; a_rows(1).y <= a.y2; a_rows(1).z <= a.y3; a_rows(1).w <= a.y4;
    a_rows(2).x <= a.z1; a_rows(2).y <= a.z2; a_rows(2).z <= a.z3; a_rows(2).w <= a.z4;
    a_rows(3).x <= a.w1; a_rows(3).y <= a.w2; a_rows(3).z <= a.w3; a_rows(3).w <= a.w4;
    
    -- Extract columns from matrix B
    b_cols(0).x <= b.x1; b_cols(0).y <= b.y1; b_cols(0).z <= b.z1; b_cols(0).w <= b.w1;
    b_cols(1).x <= b.x2; b_cols(1).y <= b.y2; b_cols(1).z <= b.z2; b_cols(1).w <= b.w2;
    b_cols(2).x <= b.x3; b_cols(2).y <= b.y3; b_cols(2).z <= b.z3; b_cols(2).w <= b.w3;
    b_cols(3).x <= b.x4; b_cols(3).y <= b.y4; b_cols(3).z <= b.z4; b_cols(3).w <= b.w4;
    
    -- Generate 16 DOT4 units (one for each matrix element)
    gen_rows: FOR row IN 0 TO 3 GENERATE
        gen_cols: FOR col IN 0 TO 3 GENERATE
            dot_inst: ENTITY work.vec4_dot_hw
                PORT MAP (
                    clk         => clk,
                    aresetn     => NOT reset,
                    input_valid => valid_in,
                    input_tid   => tid_in,
                    a           => a_rows(row),
                    b           => b_cols(col),
                    result      => dot_results(row, col),
                    valid_out   => dot_valids(row, col),
                    output_tid  => dot_tids(row, col)
                );
        END GENERATE gen_cols;
    END GENERATE gen_rows;

    -- Register outputs for proper timing
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                c <= MAT4_IDENTITY;
                valid_out <= '0';
                tid_out <= (OTHERS => '0');
            ELSE
                c.x1 <= dot_results(0, 0);
                c.x2 <= dot_results(0, 1);
                c.x3 <= dot_results(0, 2);
                c.x4 <= dot_results(0, 3);
                
                c.y1 <= dot_results(1, 0);
                c.y2 <= dot_results(1, 1);
                c.y3 <= dot_results(1, 2);
                c.y4 <= dot_results(1, 3);
                
                c.z1 <= dot_results(2, 0);
                c.z2 <= dot_results(2, 1);
                c.z3 <= dot_results(2, 2);
                c.z4 <= dot_results(2, 3);
                
                c.w1 <= dot_results(3, 0);
                c.w2 <= dot_results(3, 1);
                c.w3 <= dot_results(3, 2);
                c.w4 <= dot_results(3, 3);
                
                valid_out <= dot_valids(0, 0);
                tid_out <= dot_tids(0, 0);
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
