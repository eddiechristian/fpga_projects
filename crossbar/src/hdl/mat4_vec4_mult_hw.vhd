LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.crossbar_pkg.ALL;

-- Matrix-Vector Multiplication: v_out = M * v_in
-- Transforms a Vec4 by a Mat4 (4x4 matrix × 4x1 vector)
-- Uses 4 Vec4 dot product units to compute result in parallel
-- Each output component is a dot product of a matrix row with the input vector
--
-- Performance:
--   Latency: 6 cycles (DOT4 latency)
--   Throughput: Can start new transform every cycle (fully pipelined)
--   Resource usage: 4x DOT4 units
--
-- Resource Estimate per module:
--   - 4 DOT4 units × 14 DSPs = 56 DSPs (~8% of Artix-7 xc7a200t)
--   - LUTs: ~2K (1% of 134K available)

ENTITY mat4_vec4_mult_hw IS
    PORT (
        clk         : IN STD_LOGIC;
        reset       : IN STD_LOGIC;
        
        -- Input matrix and vector
        m_in        : IN Mat4;
        v_in        : IN Vec4;
        tid_in      : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        valid_in    : IN STD_LOGIC;
        
        -- Output vector
        v_out       : OUT Vec4;
        tid_out     : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        valid_out   : OUT STD_LOGIC
    );
END ENTITY mat4_vec4_mult_hw;

ARCHITECTURE Behavioral OF mat4_vec4_mult_hw IS

    -- Matrix rows as Vec4
    SIGNAL row_x, row_y, row_z, row_w : Vec4;
    
    -- DOT4 unit outputs
    SIGNAL dot_x_result, dot_y_result, dot_z_result, dot_w_result : fp32;
    SIGNAL dot_x_valid, dot_y_valid, dot_z_valid, dot_w_valid : STD_LOGIC;
    SIGNAL dot_x_tid, dot_y_tid, dot_z_tid, dot_w_tid : STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN

    -- Extract matrix rows as Vec4
    row_x.x <= m_in.x1;
    row_x.y <= m_in.x2;
    row_x.z <= m_in.x3;
    row_x.w <= m_in.x4;
    
    row_y.x <= m_in.y1;
    row_y.y <= m_in.y2;
    row_y.z <= m_in.y3;
    row_y.w <= m_in.y4;
    
    row_z.x <= m_in.z1;
    row_z.y <= m_in.z2;
    row_z.z <= m_in.z3;
    row_z.w <= m_in.z4;
    
    row_w.x <= m_in.w1;
    row_w.y <= m_in.w2;
    row_w.z <= m_in.w3;
    row_w.w <= m_in.w4;

    -- X component: dot product of row_x with v_in
    dot_x_inst: ENTITY work.vec4_dot_hw
        PORT MAP (
            clk         => clk,
            aresetn     => NOT reset,
            input_valid => valid_in,
            input_tid   => tid_in,
            a           => row_x,
            b           => v_in,
            result      => dot_x_result,
            valid_out   => dot_x_valid,
            output_tid  => dot_x_tid
        );

    -- Y component: dot product of row_y with v_in
    dot_y_inst: ENTITY work.vec4_dot_hw
        PORT MAP (
            clk         => clk,
            aresetn     => NOT reset,
            input_valid => valid_in,
            input_tid   => tid_in,
            a           => row_y,
            b           => v_in,
            result      => dot_y_result,
            valid_out   => dot_y_valid,
            output_tid  => dot_y_tid
        );

    -- Z component: dot product of row_z with v_in
    dot_z_inst: ENTITY work.vec4_dot_hw
        PORT MAP (
            clk         => clk,
            aresetn     => NOT reset,
            input_valid => valid_in,
            input_tid   => tid_in,
            a           => row_z,
            b           => v_in,
            result      => dot_z_result,
            valid_out   => dot_z_valid,
            output_tid  => dot_z_tid
        );

    -- W component: dot product of row_w with v_in
    dot_w_inst: ENTITY work.vec4_dot_hw
        PORT MAP (
            clk         => clk,
            aresetn     => NOT reset,
            input_valid => valid_in,
            input_tid   => tid_in,
            a           => row_w,
            b           => v_in,
            result      => dot_w_result,
            valid_out   => dot_w_valid,
            output_tid  => dot_w_tid
        );

    -- Register outputs for proper timing
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
                v_out.x <= (OTHERS => '0');
                v_out.y <= (OTHERS => '0');
                v_out.z <= (OTHERS => '0');
                v_out.w <= (OTHERS => '0');
                valid_out <= '0';
                tid_out <= (OTHERS => '0');
            ELSE
                v_out.x <= dot_x_result;
                v_out.y <= dot_y_result;
                v_out.z <= dot_z_result;
                v_out.w <= dot_w_result;
                valid_out <= dot_x_valid;
                tid_out <= dot_x_tid;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE Behavioral;
