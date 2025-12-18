LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;

-- Matrix-Vector Multiplication: v_out = M * v_in
-- Transforms a Vec4 by a Mat4 (4x4 matrix × 4x1 vector)
-- Result is a Vec4 with 4 elements, each requiring 4 multiplications + 3 additions
--
-- Performance:
--   Latency: ~30 cycles total (all 4 elements computed in parallel)
--   Throughput: Can start new transform every cycle (fully pipelined)
--   Resource usage: 16x FP_MULT + 12x FP_ADD
--
-- Resource Estimate per module:
--   - 16 fp_mult × 3 DSPs = 48 DSPs
--   - 12 fp_add × 2 DSPs = 24 DSPs
--   - Total: ~72 DSPs (~10% of Artix-7 xc7a200t - can fit 10+ modules)
--   - LUTs: ~3K (2% of 134K available)

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

    -- Floating point multiplier component
    COMPONENT floating_point_mult IS
        PORT (
            aclk                : IN STD_LOGIC;
            s_axis_a_tvalid     : IN STD_LOGIC;
            s_axis_a_tdata      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_b_tvalid     : IN STD_LOGIC;
            s_axis_b_tdata      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_result_tvalid: OUT STD_LOGIC;
            m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT;
    
    -- Floating point adder/subtractor component
    COMPONENT floating_point_addsub IS
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
    
    -- TID pipeline (depth matches FP pipeline latency)
    TYPE tid_array IS ARRAY (0 TO 15) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL tid_pipe : tid_array;

    -- Intermediate signals for x component: x_out = m.x1*v.x + m.x2*v.y + m.x3*v.z + m.x4*v.w
    SIGNAL mult_x1, mult_x2, mult_x3, mult_x4 : fp32;
    SIGNAL mult_x_valid : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL add_x12, add_x34, add_x1234 : fp32;
    SIGNAL add_x12_valid, add_x34_valid, add_x1234_valid : STD_LOGIC;
    
    -- Intermediate signals for y component: y_out = m.y1*v.x + m.y2*v.y + m.y3*v.z + m.y4*v.w
    SIGNAL mult_y1, mult_y2, mult_y3, mult_y4 : fp32;
    SIGNAL mult_y_valid : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL add_y12, add_y34, add_y1234 : fp32;
    SIGNAL add_y12_valid, add_y34_valid, add_y1234_valid : STD_LOGIC;
    
    -- Intermediate signals for z component: z_out = m.z1*v.x + m.z2*v.y + m.z3*v.z + m.z4*v.w
    SIGNAL mult_z1, mult_z2, mult_z3, mult_z4 : fp32;
    SIGNAL mult_z_valid : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL add_z12, add_z34, add_z1234 : fp32;
    SIGNAL add_z12_valid, add_z34_valid, add_z1234_valid : STD_LOGIC;
    
    -- Intermediate signals for w component: w_out = m.w1*v.x + m.w2*v.y + m.w3*v.z + m.w4*v.w
    SIGNAL mult_w1, mult_w2, mult_w3, mult_w4 : fp32;
    SIGNAL mult_w_valid : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL add_w12, add_w34, add_w1234 : fp32;
    SIGNAL add_w12_valid, add_w34_valid, add_w1234_valid : STD_LOGIC;

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

    -- ========== X COMPONENT ==========
    -- mult_x1 = m.x1 * v.x
    mult_x1_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.x1,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.x,
        m_axis_result_tvalid => mult_x_valid(0), m_axis_result_tdata => mult_x1
    );
    
    -- mult_x2 = m.x2 * v.y
    mult_x2_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.x2,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.y,
        m_axis_result_tvalid => mult_x_valid(1), m_axis_result_tdata => mult_x2
    );
    
    -- mult_x3 = m.x3 * v.z
    mult_x3_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.x3,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.z,
        m_axis_result_tvalid => mult_x_valid(2), m_axis_result_tdata => mult_x3
    );
    
    -- mult_x4 = m.x4 * v.w
    mult_x4_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.x4,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.w,
        m_axis_result_tvalid => mult_x_valid(3), m_axis_result_tdata => mult_x4
    );
    
    -- add_x12 = mult_x1 + mult_x2
    add_x12_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_x_valid(0), s_axis_a_tdata => mult_x1,
        s_axis_b_tvalid => mult_x_valid(1), s_axis_b_tdata => mult_x2,
        s_axis_operation_tvalid => mult_x_valid(0), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_x12_valid, m_axis_result_tdata => add_x12
    );
    
    -- add_x34 = mult_x3 + mult_x4
    add_x34_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_x_valid(2), s_axis_a_tdata => mult_x3,
        s_axis_b_tvalid => mult_x_valid(3), s_axis_b_tdata => mult_x4,
        s_axis_operation_tvalid => mult_x_valid(2), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_x34_valid, m_axis_result_tdata => add_x34
    );
    
    -- add_x1234 = add_x12 + add_x34
    add_x1234_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => add_x12_valid, s_axis_a_tdata => add_x12,
        s_axis_b_tvalid => add_x34_valid, s_axis_b_tdata => add_x34,
        s_axis_operation_tvalid => add_x12_valid, s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_x1234_valid, m_axis_result_tdata => add_x1234
    );

    -- ========== Y COMPONENT ==========
    mult_y1_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.y1,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.x,
        m_axis_result_tvalid => mult_y_valid(0), m_axis_result_tdata => mult_y1
    );
    
    mult_y2_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.y2,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.y,
        m_axis_result_tvalid => mult_y_valid(1), m_axis_result_tdata => mult_y2
    );
    
    mult_y3_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.y3,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.z,
        m_axis_result_tvalid => mult_y_valid(2), m_axis_result_tdata => mult_y3
    );
    
    mult_y4_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.y4,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.w,
        m_axis_result_tvalid => mult_y_valid(3), m_axis_result_tdata => mult_y4
    );
    
    add_y12_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_y_valid(0), s_axis_a_tdata => mult_y1,
        s_axis_b_tvalid => mult_y_valid(1), s_axis_b_tdata => mult_y2,
        s_axis_operation_tvalid => mult_y_valid(0), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_y12_valid, m_axis_result_tdata => add_y12
    );
    
    add_y34_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_y_valid(2), s_axis_a_tdata => mult_y3,
        s_axis_b_tvalid => mult_y_valid(3), s_axis_b_tdata => mult_y4,
        s_axis_operation_tvalid => mult_y_valid(2), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_y34_valid, m_axis_result_tdata => add_y34
    );
    
    add_y1234_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => add_y12_valid, s_axis_a_tdata => add_y12,
        s_axis_b_tvalid => add_y34_valid, s_axis_b_tdata => add_y34,
        s_axis_operation_tvalid => add_y12_valid, s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_y1234_valid, m_axis_result_tdata => add_y1234
    );

    -- ========== Z COMPONENT ==========
    mult_z1_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.z1,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.x,
        m_axis_result_tvalid => mult_z_valid(0), m_axis_result_tdata => mult_z1
    );
    
    mult_z2_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.z2,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.y,
        m_axis_result_tvalid => mult_z_valid(1), m_axis_result_tdata => mult_z2
    );
    
    mult_z3_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.z3,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.z,
        m_axis_result_tvalid => mult_z_valid(2), m_axis_result_tdata => mult_z3
    );
    
    mult_z4_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.z4,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.w,
        m_axis_result_tvalid => mult_z_valid(3), m_axis_result_tdata => mult_z4
    );
    
    add_z12_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_z_valid(0), s_axis_a_tdata => mult_z1,
        s_axis_b_tvalid => mult_z_valid(1), s_axis_b_tdata => mult_z2,
        s_axis_operation_tvalid => mult_z_valid(0), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_z12_valid, m_axis_result_tdata => add_z12
    );
    
    add_z34_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_z_valid(2), s_axis_a_tdata => mult_z3,
        s_axis_b_tvalid => mult_z_valid(3), s_axis_b_tdata => mult_z4,
        s_axis_operation_tvalid => mult_z_valid(2), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_z34_valid, m_axis_result_tdata => add_z34
    );
    
    add_z1234_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => add_z12_valid, s_axis_a_tdata => add_z12,
        s_axis_b_tvalid => add_z34_valid, s_axis_b_tdata => add_z34,
        s_axis_operation_tvalid => add_z12_valid, s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_z1234_valid, m_axis_result_tdata => add_z1234
    );

    -- ========== W COMPONENT ==========
    mult_w1_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.w1,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.x,
        m_axis_result_tvalid => mult_w_valid(0), m_axis_result_tdata => mult_w1
    );
    
    mult_w2_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.w2,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.y,
        m_axis_result_tvalid => mult_w_valid(1), m_axis_result_tdata => mult_w2
    );
    
    mult_w3_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.w3,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.z,
        m_axis_result_tvalid => mult_w_valid(2), m_axis_result_tdata => mult_w3
    );
    
    mult_w4_inst: floating_point_mult port map (
        aclk => clk, s_axis_a_tvalid => valid_in, s_axis_a_tdata => m_in.w4,
        s_axis_b_tvalid => valid_in, s_axis_b_tdata => v_in.w,
        m_axis_result_tvalid => mult_w_valid(3), m_axis_result_tdata => mult_w4
    );
    
    add_w12_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_w_valid(0), s_axis_a_tdata => mult_w1,
        s_axis_b_tvalid => mult_w_valid(1), s_axis_b_tdata => mult_w2,
        s_axis_operation_tvalid => mult_w_valid(0), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_w12_valid, m_axis_result_tdata => add_w12
    );
    
    add_w34_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => mult_w_valid(2), s_axis_a_tdata => mult_w3,
        s_axis_b_tvalid => mult_w_valid(3), s_axis_b_tdata => mult_w4,
        s_axis_operation_tvalid => mult_w_valid(2), s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_w34_valid, m_axis_result_tdata => add_w34
    );
    
    add_w1234_inst: floating_point_addsub PORT MAP (
        aclk => clk, s_axis_a_tvalid => add_w12_valid, s_axis_a_tdata => add_w12,
        s_axis_b_tvalid => add_w34_valid, s_axis_b_tdata => add_w34,
        s_axis_operation_tvalid => add_w12_valid, s_axis_operation_tdata => OP_ADD,
        m_axis_result_tvalid => add_w1234_valid, m_axis_result_tdata => add_w1234
    );

    -- Output assignment
    v_out.x <= add_x1234;
    v_out.y <= add_y1234;
    v_out.z <= add_z1234;
    v_out.w <= add_w1234;
    
    -- Use the valid from x component (all should be aligned)
    valid_out <= add_x1234_valid;
    
    -- TID output (pipeline depth ~14 cycles: 2 mult + 3*2 add)
    tid_out <= tid_pipe(13);

END ARCHITECTURE Behavioral;
