library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lin_alg_pkg.all;

-- 4x4 Matrix Inverse: M_out = M_in^(-1)
-- Computes the inverse of a 4x4 matrix using Gauss-Jordan elimination
-- 
-- Algorithm: Forward elimination + Back substitution
--   For each row i (0 to 3):
--     1. Find pivot (largest element in column i)
--     2. Swap rows if needed
--     3. Scale pivot row so diagonal = 1
--     4. Eliminate column below/above pivot
--
-- Resource Estimate:
--   - 16 fp_div (for row scaling)
--   - 32 fp_mult (for row operations)
--   - 32 fp_add (for row operations)
--   - Total: ~16×28 + 32×3 + 32×2 = ~608 DSPs (82% of 740)
--   - Latency: ~1000 cycles (can reuse for ray tracing after)
--   - Can be time-multiplexed: compute once per frame

entity mat4_inverse_hw is
    Port (
        clk         : in std_logic;
        reset       : in std_logic;
        
        -- Input matrix
        m_in        : in Mat4;
        valid_in    : in std_logic;
        
        -- Output inverse matrix
        m_out       : out Mat4;
        valid_out   : out std_logic;
        
        -- Error flag (singular matrix)
        error       : out std_logic
    );
end mat4_inverse_hw;

architecture Behavioral of mat4_inverse_hw is

    -- Floating point divider component
    component floating_point_div is
        port (
            aclk                : in  std_logic;
            s_axis_a_tvalid     : in  std_logic;
            s_axis_a_tdata      : in  std_logic_vector(31 downto 0);
            s_axis_b_tvalid     : in  std_logic;
            s_axis_b_tdata      : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid: out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Floating point multiplier component
    component floating_point_mult is
        port (
            aclk                : in  std_logic;
            s_axis_a_tvalid     : in  std_logic;
            s_axis_a_tdata      : in  std_logic_vector(31 downto 0);
            s_axis_b_tvalid     : in  std_logic;
            s_axis_b_tdata      : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid: out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Floating point adder component
    component floating_point_add is
        port (
            aclk                : in  std_logic;
            s_axis_a_tvalid     : in  std_logic;
            s_axis_a_tdata      : in  std_logic_vector(31 downto 0);
            s_axis_b_tvalid     : in  std_logic;
            s_axis_b_tdata      : in  std_logic_vector(31 downto 0);
            m_axis_result_tvalid: out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;

    -- State machine for Gauss-Jordan elimination
    type state_type is (
        IDLE,                -- Waiting for input
        LOAD_MATRIX,         -- Load input matrix and initialize augmented matrix
        SCALE_PIVOT_ROW,     -- Divide pivot row by pivot element
        SCALE_WAIT,          -- Wait for division result
        ELIMINATE_ROW,       -- Eliminate other rows
        ELIMINATE_MULT,      -- Multiply for row elimination
        ELIMINATE_MULT_WAIT, -- Wait for multiply result
        ELIMINATE_ADD,       -- Add/subtract for row elimination
        ELIMINATE_ADD_WAIT,  -- Wait for add result
        NEXT_COLUMN,         -- Move to next column
        DONE                 -- Output result
    );
    signal state : state_type := IDLE;
    
    -- Augmented matrix [A | I] stored as 4x8 array
    -- During Gauss-Jordan, this becomes [I | A^-1]
    type fp32_array_4x8 is array (0 to 3, 0 to 7) of fp32;
    signal aug_matrix : fp32_array_4x8;
    signal temp_row : array (0 to 7) of fp32;  -- Temporary storage for scaled row
    
    -- Current pivot row and column
    signal pivot_col : integer range 0 to 3 := 0;
    signal pivot_row : integer range 0 to 3 := 0;
    signal elim_row : integer range 0 to 3 := 0;  -- Row being eliminated
    signal col_idx : integer range 0 to 7 := 0;   -- Column index for row operations
    
    -- Operation counter for tracking pipeline stages
    signal op_counter : integer := 0;
    signal wait_counter : integer := 0;
    
    -- FP operation signals (reused for all operations)
    signal fp_div_a, fp_div_b : fp32;
    signal fp_div_result : fp32;
    signal fp_div_valid_in, fp_div_valid_out : std_logic;
    
    signal fp_mult_a, fp_mult_b : fp32;
    signal fp_mult_result : fp32;
    signal fp_mult_valid_in, fp_mult_valid_out : std_logic;
    
    signal fp_add_a, fp_add_b : fp32;
    signal fp_add_result : fp32;
    signal fp_add_valid_in, fp_add_valid_out : std_logic;
    
    -- Pivot value and multiplier for row elimination
    signal pivot_value : fp32;
    signal row_multiplier : fp32;
    
    -- Helper function to convert Mat4 to 2D array
    function mat4_to_aug_matrix(m : Mat4) return fp32_array_4x8 is
        variable result : fp32_array_4x8;
    begin
        -- Left side: input matrix A
        result(0, 0) := m.x1; result(0, 1) := m.x2; result(0, 2) := m.x3; result(0, 3) := m.x4;
        result(1, 0) := m.y1; result(1, 1) := m.y2; result(1, 2) := m.y3; result(1, 3) := m.y4;
        result(2, 0) := m.z1; result(2, 1) := m.z2; result(2, 2) := m.z3; result(2, 3) := m.z4;
        result(3, 0) := m.w1; result(3, 1) := m.w2; result(3, 2) := m.w3; result(3, 3) := m.w4;
        
        -- Right side: identity matrix I
        result(0, 4) := X"3F800000"; result(0, 5) := X"00000000"; result(0, 6) := X"00000000"; result(0, 7) := X"00000000";
        result(1, 4) := X"00000000"; result(1, 5) := X"3F800000"; result(1, 6) := X"00000000"; result(1, 7) := X"00000000";
        result(2, 4) := X"00000000"; result(2, 5) := X"00000000"; result(2, 6) := X"3F800000"; result(2, 7) := X"00000000";
        result(3, 4) := X"00000000"; result(3, 5) := X"00000000"; result(3, 6) := X"00000000"; result(3, 7) := X"3F800000";
        
        return result;
    end function;
    
    -- Helper function to extract inverse from augmented matrix
    function aug_matrix_to_mat4(aug : fp32_array_4x8) return Mat4 is
        variable result : Mat4;
    begin
        -- Extract right half (columns 4-7) which is now A^-1
        result.x1 := aug(0, 4); result.x2 := aug(0, 5); result.x3 := aug(0, 6); result.x4 := aug(0, 7);
        result.y1 := aug(1, 4); result.y2 := aug(1, 5); result.y3 := aug(1, 6); result.y4 := aug(1, 7);
        result.z1 := aug(2, 4); result.z2 := aug(2, 5); result.z3 := aug(2, 6); result.z4 := aug(2, 7);
        result.w1 := aug(3, 4); result.w2 := aug(3, 5); result.w3 := aug(3, 6); result.w4 := aug(3, 7);
        return result;
    end function;

begin

    -- Instantiate FP operation units (these get reused sequentially)
    div_inst: floating_point_div port map (
        aclk => clk,
        s_axis_a_tvalid => fp_div_valid_in,
        s_axis_a_tdata => fp_div_a,
        s_axis_b_tvalid => fp_div_valid_in,
        s_axis_b_tdata => fp_div_b,
        m_axis_result_tvalid => fp_div_valid_out,
        m_axis_result_tdata => fp_div_result
    );
    
    mult_inst: floating_point_mult port map (
        aclk => clk,
        s_axis_a_tvalid => fp_mult_valid_in,
        s_axis_a_tdata => fp_mult_a,
        s_axis_b_tvalid => fp_mult_valid_in,
        s_axis_b_tdata => fp_mult_b,
        m_axis_result_tvalid => fp_mult_valid_out,
        m_axis_result_tdata => fp_mult_result
    );
    
    add_inst: floating_point_add port map (
        aclk => clk,
        s_axis_a_tvalid => fp_add_valid_in,
        s_axis_a_tdata => fp_add_a,
        s_axis_b_tvalid => fp_add_valid_in,
        s_axis_b_tdata => fp_add_b,
        m_axis_result_tvalid => fp_add_valid_out,
        m_axis_result_tdata => fp_add_result
    );

    -- Main Gauss-Jordan state machine
    -- Performs row reduction on augmented matrix [A | I] to produce [I | A^-1]
    -- NOTE: Assumes matrix is non-singular (invertible)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                pivot_col <= 0;
                pivot_row <= 0;
                elim_row <= 0;
                col_idx <= 0;
                op_counter <= 0;
                wait_counter <= 0;
                valid_out <= '0';
                error <= '0';
                fp_div_valid_in <= '0';
                fp_mult_valid_in <= '0';
                fp_add_valid_in <= '0';
            else
                -- Default: clear valid signals each cycle
                fp_div_valid_in <= '0';
                fp_mult_valid_in <= '0';
                fp_add_valid_in <= '0';
                valid_out <= '0';
                
                case state is
                    when IDLE =>
                        if valid_in = '1' then
                            -- Load input matrix into augmented matrix
                            aug_matrix <= mat4_to_aug_matrix(m_in);
                            state <= LOAD_MATRIX;
                            pivot_col <= 0;
                            pivot_row <= 0;
                        end if;
                    
                    when LOAD_MATRIX =>
                        -- Matrix loaded, start Gauss-Jordan with column 0
                        pivot_value <= aug_matrix(0, 0);  -- Pivot is diagonal element
                        col_idx <= 0;
                        state <= SCALE_PIVOT_ROW;
                    
                    -- ==== SCALE PIVOT ROW ====
                    -- Divide entire pivot row by pivot element to make diagonal = 1
                    when SCALE_PIVOT_ROW =>
                        if col_idx <= 7 then
                            -- Initiate division: aug_matrix[pivot_row, col_idx] / pivot_value
                            fp_div_a <= aug_matrix(pivot_row, col_idx);
                            fp_div_b <= pivot_value;
                            fp_div_valid_in <= '1';
                            state <= SCALE_WAIT;
                            wait_counter <= 0;
                        else
                            -- Done scaling pivot row, write it back
                            for i in 0 to 7 loop
                                aug_matrix(pivot_row, i) <= temp_row(i);
                            end loop;
                            -- Start eliminating other rows
                            elim_row <= 0;
                            state <= ELIMINATE_ROW;
                        end if;
                    
                    when SCALE_WAIT =>
                        -- Wait for division to complete (~28 cycles)
                        if fp_div_valid_out = '1' then
                            temp_row(col_idx) <= fp_div_result;
                            col_idx <= col_idx + 1;
                            state <= SCALE_PIVOT_ROW;
                        elsif wait_counter < 35 then
                            wait_counter <= wait_counter + 1;
                        else
                            -- Timeout - should not happen
                            error <= '1';
                            state <= IDLE;
                        end if;
                    
                    -- ==== ELIMINATE OTHER ROWS ====
                    -- For each row != pivot_row: row = row - (row[pivot_col] * pivot_row)
                    when ELIMINATE_ROW =>
                        if elim_row < 4 then
                            if elim_row /= pivot_row then
                                -- Get multiplier: aug_matrix[elim_row, pivot_col]
                                row_multiplier <= aug_matrix(elim_row, pivot_col);
                                col_idx <= 0;
                                state <= ELIMINATE_MULT;
                            else
                                -- Skip pivot row itself
                                elim_row <= elim_row + 1;
                            end if;
                        else
                            -- Done eliminating all rows for this column
                            state <= NEXT_COLUMN;
                        end if;
                    
                    when ELIMINATE_MULT =>
                        if col_idx <= 7 then
                            -- Step 1: Start multiply: mult = row_multiplier * aug_matrix[pivot_row, col_idx]
                            fp_mult_a <= row_multiplier;
                            fp_mult_b <= aug_matrix(pivot_row, col_idx);
                            fp_mult_valid_in <= '1';
                            wait_counter <= 0;
                            state <= ELIMINATE_MULT_WAIT;
                        else
                            -- Done with all columns for this elimination row
                            elim_row <= elim_row + 1;
                            state <= ELIMINATE_ROW;
                        end if;
                    
                    when ELIMINATE_MULT_WAIT =>
                        -- Wait for multiply to complete (~8 cycles)
                        if fp_mult_valid_out = '1' then
                            -- Multiply done, proceed to add/subtract
                            state <= ELIMINATE_ADD;
                        elsif wait_counter < 15 then
                            wait_counter <= wait_counter + 1;
                        else
                            -- Timeout
                            error <= '1';
                            state <= IDLE;
                        end if;
                    
                    when ELIMINATE_ADD =>
                        -- Step 2: Subtract: result = aug_matrix[elim_row, col_idx] - mult_result
                        -- Negate mult_result by flipping sign bit
                        fp_add_a <= aug_matrix(elim_row, col_idx);
                        fp_add_b <= not fp_mult_result(31) & fp_mult_result(30 downto 0);  -- Negate for subtract
                        fp_add_valid_in <= '1';
                        wait_counter <= 0;
                        state <= ELIMINATE_ADD_WAIT;
                    
                    when ELIMINATE_ADD_WAIT =>
                        -- Wait for add to complete (~11 cycles)
                        if fp_add_valid_out = '1' then
                            -- Write result back to matrix
                            aug_matrix(elim_row, col_idx) <= fp_add_result;
                            col_idx <= col_idx + 1;
                            state <= ELIMINATE_MULT;  -- Next column
                        elsif wait_counter < 20 then
                            wait_counter <= wait_counter + 1;
                        else
                            -- Timeout
                            error <= '1';
                            state <= IDLE;
                        end if;
                    
                    -- ==== MOVE TO NEXT COLUMN ====
                    when NEXT_COLUMN =>
                        if pivot_col < 3 then
                            pivot_col <= pivot_col + 1;
                            pivot_row <= pivot_row + 1;
                            pivot_value <= aug_matrix(pivot_row + 1, pivot_col + 1);
                            col_idx <= 0;
                            state <= SCALE_PIVOT_ROW;
                        else
                            -- All columns processed
                            state <= DONE;
                        end if;
                    
                    when DONE =>
                        -- Extract inverse from right half of augmented matrix
                        m_out <= aug_matrix_to_mat4(aug_matrix);
                        valid_out <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
