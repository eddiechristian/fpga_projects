library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

-- TRS to Matrix Converter: Creates transformation matrix from Translation, Rotation, Scale
-- 
-- Inputs:
--   - Scale: sx, sy, sz (fp32 each)
--   - Rotation: rx, ry, rz (Euler angles in radians, fp32 each)
--   - Translation: tx, ty, tz (fp32 each)
--
-- Outputs:
--   - Forward transform matrix M = T * Rz * Ry * Rx * S
--   - Inverse transform matrix M^-1
--
-- Order of operations (standard graphics pipeline):
--   1. Scale (S)
--   2. Rotate X (Rx)
--   3. Rotate Y (Ry) 
--   4. Rotate Z (Rz)
--   5. Translate (T)
--
-- The inverse is computed analytically (much faster than Gauss-Jordan):
--   M^-1 = S^-1 * Rx^-1 * Ry^-1 * Rz^-1 * T^-1
--        = S^-1 * Rx^T * Ry^T * Rz^T * T^-1  (rotation inverse = transpose)
--
-- Resource estimate:
--   - Uses mat4_mult_hw for matrix multiplications
--   - 4 matrix multiplies for forward transform
--   - 4 matrix multiplies for inverse transform  
--   - Can compute both in parallel or sequentially
--   - Latency: ~200 cycles (sequential) or ~50 cycles (parallel with 8 multipliers)

entity trs_to_matrix_hw is
    Port (
        clk            : in std_logic;
        reset          : in std_logic;
        
        -- Input: TRS parameters
        scale_x        : in fp32;
        scale_y        : in fp32;
        scale_z        : in fp32;
        
        rotation_x     : in fp32;  -- Radians
        rotation_y     : in fp32;  -- Radians
        rotation_z     : in fp32;  -- Radians
        
        translate_x    : in fp32;
        translate_y    : in fp32;
        translate_z    : in fp32;
        
        valid_in       : in std_logic;
        
        -- Output: Transform matrices
        transform_matrix : out Mat4;    -- Forward transform
        inverse_matrix   : out Mat4;    -- Inverse transform
        valid_out        : out std_logic;
        
        -- Error flag (e.g. scale = 0)
        error          : out std_logic
    );
end trs_to_matrix_hw;

architecture Behavioral of trs_to_matrix_hw is

    -- Simple sin/cos LUT component (45° increments)
    component sincos_lut_simple is
        port (
            clk                     : in std_logic;
            reset                   : in std_logic;
            angle_valid             : in std_logic;
            angle                   : in std_logic_vector(31 downto 0);
            result_valid            : out std_logic;
            sin_out                 : out std_logic_vector(31 downto 0);
            cos_out                 : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Matrix multiplication component
    component mat4_mult_hw is
        port (
            clk       : in std_logic;
            reset     : in std_logic;
            valid_in  : in std_logic;
            a         : in Mat4;
            b         : in Mat4;
            tid_in    : in std_logic_vector(15 downto 0);
            c         : out Mat4;
            tid_out   : out std_logic_vector(15 downto 0);
            valid_out : out std_logic
        );
    end component;
    
    -- FP Divider for scale inverse
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

    -- State machine
    type state_type is (
        IDLE,
        COMPUTE_SINCOS_X,       -- Compute sin/cos for X rotation
        COMPUTE_SINCOS_Y,       -- Compute sin/cos for Y rotation  
        COMPUTE_SINCOS_Z,       -- Compute sin/cos for Z rotation
        WAIT_SINCOS,            -- Wait for CORDIC results
        COMPUTE_SCALE_INV,      -- Compute 1/sx, 1/sy, 1/sz
        WAIT_SCALE_INV,         -- Wait for divisions
        BUILD_MATRICES,         -- Build individual S, R, T matrices
        MULT_FORWARD_1,         -- S * Rx
        MULT_FORWARD_2,         -- (S*Rx) * Ry
        MULT_FORWARD_3,         -- (S*Rx*Ry) * Rz
        MULT_FORWARD_4,         -- (S*Rx*Ry*Rz) * T
        MULT_INVERSE_1,         -- S^-1 * Rx^T
        MULT_INVERSE_2,         -- (S^-1*Rx^T) * Ry^T
        MULT_INVERSE_3,         -- (S^-1*Rx^T*Ry^T) * Rz^T
        MULT_INVERSE_4,         -- (S^-1*Rx^T*Ry^T*Rz^T) * T^-1
        WAIT_MULT,              -- Wait for matrix mult
        DONE
    );
    signal state : state_type := IDLE;
    signal next_state : state_type;
    
    -- Sin/Cos values
    signal sin_x, cos_x : fp32;
    signal sin_y, cos_y : fp32;
    signal sin_z, cos_z : fp32;
    signal lut_angle_valid : std_logic;
    signal lut_angle : fp32;
    signal lut_result_valid : std_logic;
    signal lut_sin_out, lut_cos_out : fp32;
    signal sincos_counter : integer range 0 to 2 := 0;
    
    -- Scale inverse values
    signal scale_x_inv, scale_y_inv, scale_z_inv : fp32;
    signal div_valid_in, div_valid_out : std_logic;
    signal div_a, div_b, div_result : fp32;
    signal div_counter : integer range 0 to 2 := 0;
    
    -- Individual transformation matrices
    signal mat_scale : Mat4;
    signal mat_rotate_x : Mat4;
    signal mat_rotate_y : Mat4;
    signal mat_rotate_z : Mat4;
    signal mat_translate : Mat4;
    
    -- Inverse matrices
    signal mat_scale_inv : Mat4;
    signal mat_rotate_x_inv : Mat4;  -- Transpose of rotation
    signal mat_rotate_y_inv : Mat4;
    signal mat_rotate_z_inv : Mat4;
    signal mat_translate_inv : Mat4;
    
    -- Matrix multiplication signals
    signal mult_a, mult_b, mult_result : Mat4;
    signal mult_valid_in, mult_valid_out : std_logic;
    signal mult_reset : std_logic;
    
    -- Intermediate results for chained multiplications
    signal temp_mat1, temp_mat2, temp_mat3 : Mat4;
    
    signal wait_counter : integer := 0;
    
    -- Debug/Preserve attributes
    attribute MARK_DEBUG : string;
    attribute KEEP       : string;
    attribute DONT_TOUCH : string;

    attribute MARK_DEBUG of state           : signal is "TRUE";
    attribute MARK_DEBUG of wait_counter    : signal is "TRUE";
    attribute MARK_DEBUG of lut_result_valid : signal is "TRUE";
    attribute MARK_DEBUG of div_valid_out   : signal is "TRUE";
    attribute MARK_DEBUG of mult_valid_in   : signal is "TRUE";
    attribute MARK_DEBUG of mult_valid_out  : signal is "TRUE";

    attribute KEEP       of mult_valid_in   : signal is "TRUE";
    attribute DONT_TOUCH of mult_valid_in   : signal is "TRUE";
    attribute KEEP       of mult_valid_out  : signal is "TRUE";
    attribute DONT_TOUCH of mult_valid_out  : signal is "TRUE";

begin

    -- Instantiate simple sin/cos LUT
    lut_inst: sincos_lut_simple port map (
        clk => clk,
        reset => reset,
        angle_valid => lut_angle_valid,
        angle => lut_angle,
        result_valid => lut_result_valid,
        sin_out => lut_sin_out,
        cos_out => lut_cos_out
    );
    
    -- Instantiate divider for scale inverse
    div_inst: floating_point_div port map (
        aclk => clk,
        s_axis_a_tvalid => div_valid_in,
        s_axis_a_tdata => div_a,
        s_axis_b_tvalid => div_valid_in,
        s_axis_b_tdata => div_b,
        m_axis_result_tvalid => div_valid_out,
        m_axis_result_tdata => div_result
    );
    
    -- Instantiate matrix multiplier
    mult_inst: mat4_mult_hw port map (
        clk => clk,
        reset => mult_reset,
        valid_in => mult_valid_in,
        a => mult_a,
        b => mult_b,
        tid_in => (others => '0'),
        c => mult_result,
        tid_out => open,
        valid_out => mult_valid_out
    );

    -- Main state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                next_state <= IDLE;
                valid_out <= '0';
                error <= '0';
                lut_angle_valid <= '0';
                div_valid_in <= '0';
                mult_valid_in <= '0';
                mult_reset <= '0';
                sincos_counter <= 0;
                div_counter <= 0;
                wait_counter <= 0;
            else
                -- Default: clear valid signals
                valid_out <= '0';
                lut_angle_valid <= '0';
                div_valid_in <= '0';
                mult_valid_in <= '0';
                mult_reset <= '0';
                
                case state is
                    when IDLE =>
                        if valid_in = '1' then
                            report "TRS: Starting computation" severity note;
                            error <= '0';  -- Clear error on new computation
                            sincos_counter <= 0;
                            wait_counter <= 0;
                            state <= COMPUTE_SINCOS_X;
                        end if;
                    
                    -- ==== COMPUTE SIN/COS FOR ROTATIONS ====
                    when COMPUTE_SINCOS_X =>
                        report "TRS: COMPUTE_SINCOS_X" severity note;
                        lut_angle <= rotation_x;
                        lut_angle_valid <= '1';
                        next_state <= COMPUTE_SINCOS_Y;
                        state <= WAIT_SINCOS;
                        wait_counter <= 0;
                    
                    when COMPUTE_SINCOS_Y =>
                        lut_angle <= rotation_y;
                        lut_angle_valid <= '1';
                        next_state <= COMPUTE_SINCOS_Z;
                        state <= WAIT_SINCOS;
                        wait_counter <= 0;
                    
                    when COMPUTE_SINCOS_Z =>
                        lut_angle <= rotation_z;
                        lut_angle_valid <= '1';
                        next_state <= COMPUTE_SCALE_INV;
                        state <= WAIT_SINCOS;
                        wait_counter <= 0;
                    
                    when WAIT_SINCOS =>
                        if lut_result_valid = '1' then
                            report "TRS: WAIT_SINCOS got result, counter=" & integer'image(sincos_counter) severity note;
                            -- LUT output: sin and cos directly as FP32
                            case sincos_counter is
                                when 0 =>
                                    sin_x <= lut_sin_out;
                                    cos_x <= lut_cos_out;
                                when 1 =>
                                    sin_y <= lut_sin_out;
                                    cos_y <= lut_cos_out;
                                when 2 =>
                                    sin_z <= lut_sin_out;
                                    cos_z <= lut_cos_out;
                            end case;
                            sincos_counter <= sincos_counter + 1;
                            state <= next_state;
                        elsif wait_counter < 1000 then
                            wait_counter <= wait_counter + 1;
                        else
                            -- Timeout
                            report "TRS: WAIT_SINCOS timeout!" severity failure;
                            error <= '1';
                            state <= IDLE;
                        end if;
                    
                    -- ==== COMPUTE SCALE INVERSE ====
                    when COMPUTE_SCALE_INV =>
                        report "TRS: COMPUTE_SCALE_INV, counter=" & integer'image(div_counter) severity note;
                        case div_counter is
                            when 0 =>
                                div_a <= X"3F800000";  -- 1.0
                                div_b <= scale_x;
                            when 1 =>
                                div_a <= X"3F800000";
                                div_b <= scale_y;
                            when 2 =>
                                div_a <= X"3F800000";
                                div_b <= scale_z;
                        end case;
                        div_valid_in <= '1';
                        state <= WAIT_SCALE_INV;
                        wait_counter <= 0;
                    
                    when WAIT_SCALE_INV =>
                        if div_valid_out = '1' then
                            report "TRS: WAIT_SCALE_INV got result, counter=" & integer'image(div_counter) severity note;
                            case div_counter is
                                when 0 => scale_x_inv <= div_result;
                                when 1 => scale_y_inv <= div_result;
                                when 2 => scale_z_inv <= div_result;
                            end case;
                            
                            if div_counter < 2 then
                                div_counter <= div_counter + 1;
                                state <= COMPUTE_SCALE_INV;
                            else
                                state <= BUILD_MATRICES;
                            end if;
                        elsif wait_counter < 1000 then
                            wait_counter <= wait_counter + 1;
                        else
                            report "TRS: WAIT_SCALE_INV timeout!" severity failure;
                            error <= '1';
                            state <= IDLE;
                        end if;
                    
                    when BUILD_MATRICES =>
                        report "TRS: BUILD_MATRICES" severity note;
                        -- Build scale matrix S
                        mat_scale.x1 <= scale_x;
                        mat_scale.y1 <= X"00000000";
                        mat_scale.z1 <= X"00000000";
                        mat_scale.w1 <= X"00000000";
                        mat_scale.x2 <= X"00000000";
                        mat_scale.y2 <= scale_y;
                        mat_scale.z2 <= X"00000000";
                        mat_scale.w2 <= X"00000000";
                        mat_scale.x3 <= X"00000000";
                        mat_scale.y3 <= X"00000000";
                        mat_scale.z3 <= scale_z;
                        mat_scale.w3 <= X"00000000";
                        mat_scale.x4 <= X"00000000";
                        mat_scale.y4 <= X"00000000";
                        mat_scale.z4 <= X"00000000";
                        mat_scale.w4 <= X"3F800000";  -- 1.0
                        
                        -- Build scale inverse S^-1
                        mat_scale_inv.x1 <= scale_x_inv;
                        mat_scale_inv.y1 <= X"00000000";
                        mat_scale_inv.z1 <= X"00000000";
                        mat_scale_inv.w1 <= X"00000000";
                        mat_scale_inv.x2 <= X"00000000";
                        mat_scale_inv.y2 <= scale_y_inv;
                        mat_scale_inv.z2 <= X"00000000";
                        mat_scale_inv.w2 <= X"00000000";
                        mat_scale_inv.x3 <= X"00000000";
                        mat_scale_inv.y3 <= X"00000000";
                        mat_scale_inv.z3 <= scale_z_inv;
                        mat_scale_inv.w3 <= X"00000000";
                        mat_scale_inv.x4 <= X"00000000";
                        mat_scale_inv.y4 <= X"00000000";
                        mat_scale_inv.z4 <= X"00000000";
                        mat_scale_inv.w4 <= X"3F800000";
                        
                        -- Build rotation X matrix: Rx
                        -- | 1   0      0     0 |
                        -- | 0  cos  -sin    0 |
                        -- | 0  sin   cos    0 |
                        -- | 0   0      0     1 |
                        mat_rotate_x.x1 <= X"3F800000";  -- 1.0
                        mat_rotate_x.y1 <= X"00000000";
                        mat_rotate_x.z1 <= X"00000000";
                        mat_rotate_x.w1 <= X"00000000";
                        mat_rotate_x.x2 <= X"00000000";
                        mat_rotate_x.y2 <= cos_x;
                        mat_rotate_x.z2 <= sin_x;
                        mat_rotate_x.w2 <= X"00000000";
                        mat_rotate_x.x3 <= X"00000000";
                        mat_rotate_x.y3 <= not sin_x(31) & sin_x(30 downto 0);  -- -sin
                        mat_rotate_x.z3 <= cos_x;
                        mat_rotate_x.w3 <= X"00000000";
                        mat_rotate_x.x4 <= X"00000000";
                        mat_rotate_x.y4 <= X"00000000";
                        mat_rotate_x.z4 <= X"00000000";
                        mat_rotate_x.w4 <= X"3F800000";
                        
                        -- Rx inverse = Rx transpose
                        mat_rotate_x_inv.x1 <= X"3F800000";
                        mat_rotate_x_inv.y1 <= X"00000000";
                        mat_rotate_x_inv.z1 <= X"00000000";
                        mat_rotate_x_inv.w1 <= X"00000000";
                        mat_rotate_x_inv.x2 <= X"00000000";
                        mat_rotate_x_inv.y2 <= cos_x;
                        mat_rotate_x_inv.z2 <= not sin_x(31) & sin_x(30 downto 0);  -- Transposed: -sin moves
                        mat_rotate_x_inv.w2 <= X"00000000";
                        mat_rotate_x_inv.x3 <= X"00000000";
                        mat_rotate_x_inv.y3 <= sin_x;  -- Transposed
                        mat_rotate_x_inv.z3 <= cos_x;
                        mat_rotate_x_inv.w3 <= X"00000000";
                        mat_rotate_x_inv.x4 <= X"00000000";
                        mat_rotate_x_inv.y4 <= X"00000000";
                        mat_rotate_x_inv.z4 <= X"00000000";
                        mat_rotate_x_inv.w4 <= X"3F800000";
                        
                        -- Build rotation Y matrix: Ry
                        -- | cos   0  sin  0 |
                        -- |  0    1   0   0 |
                        -- |-sin   0  cos  0 |
                        -- |  0    0   0   1 |
                        mat_rotate_y.x1 <= cos_y;
                        mat_rotate_y.y1 <= X"00000000";
                        mat_rotate_y.z1 <= not sin_y(31) & sin_y(30 downto 0);  -- -sin
                        mat_rotate_y.w1 <= X"00000000";
                        mat_rotate_y.x2 <= X"00000000";
                        mat_rotate_y.y2 <= X"3F800000";
                        mat_rotate_y.z2 <= X"00000000";
                        mat_rotate_y.w2 <= X"00000000";
                        mat_rotate_y.x3 <= sin_y;
                        mat_rotate_y.y3 <= X"00000000";
                        mat_rotate_y.z3 <= cos_y;
                        mat_rotate_y.w3 <= X"00000000";
                        mat_rotate_y.x4 <= X"00000000";
                        mat_rotate_y.y4 <= X"00000000";
                        mat_rotate_y.z4 <= X"00000000";
                        mat_rotate_y.w4 <= X"3F800000";
                        
                        -- Ry inverse = Ry transpose
                        mat_rotate_y_inv.x1 <= cos_y;
                        mat_rotate_y_inv.y1 <= X"00000000";
                        mat_rotate_y_inv.z1 <= sin_y;  -- Transposed
                        mat_rotate_y_inv.w1 <= X"00000000";
                        mat_rotate_y_inv.x2 <= X"00000000";
                        mat_rotate_y_inv.y2 <= X"3F800000";
                        mat_rotate_y_inv.z2 <= X"00000000";
                        mat_rotate_y_inv.w2 <= X"00000000";
                        mat_rotate_y_inv.x3 <= not sin_y(31) & sin_y(30 downto 0);  -- Transposed: -sin
                        mat_rotate_y_inv.y3 <= X"00000000";
                        mat_rotate_y_inv.z3 <= cos_y;
                        mat_rotate_y_inv.w3 <= X"00000000";
                        mat_rotate_y_inv.x4 <= X"00000000";
                        mat_rotate_y_inv.y4 <= X"00000000";
                        mat_rotate_y_inv.z4 <= X"00000000";
                        mat_rotate_y_inv.w4 <= X"3F800000";
                        
                        -- Build rotation Z matrix: Rz
                        -- | cos -sin  0  0 |
                        -- | sin  cos  0  0 |
                        -- |  0    0   1  0 |
                        -- |  0    0   0  1 |
                        mat_rotate_z.x1 <= cos_z;
                        mat_rotate_z.y1 <= sin_z;
                        mat_rotate_z.z1 <= X"00000000";
                        mat_rotate_z.w1 <= X"00000000";
                        mat_rotate_z.x2 <= not sin_z(31) & sin_z(30 downto 0);  -- -sin
                        mat_rotate_z.y2 <= cos_z;
                        mat_rotate_z.z2 <= X"00000000";
                        mat_rotate_z.w2 <= X"00000000";
                        mat_rotate_z.x3 <= X"00000000";
                        mat_rotate_z.y3 <= X"00000000";
                        mat_rotate_z.z3 <= X"3F800000";
                        mat_rotate_z.w3 <= X"00000000";
                        mat_rotate_z.x4 <= X"00000000";
                        mat_rotate_z.y4 <= X"00000000";
                        mat_rotate_z.z4 <= X"00000000";
                        mat_rotate_z.w4 <= X"3F800000";
                        
                        -- Rz inverse = Rz transpose
                        mat_rotate_z_inv.x1 <= cos_z;
                        mat_rotate_z_inv.y1 <= not sin_z(31) & sin_z(30 downto 0);  -- Transposed: -sin
                        mat_rotate_z_inv.z1 <= X"00000000";
                        mat_rotate_z_inv.w1 <= X"00000000";
                        mat_rotate_z_inv.x2 <= sin_z;  -- Transposed
                        mat_rotate_z_inv.y2 <= cos_z;
                        mat_rotate_z_inv.z2 <= X"00000000";
                        mat_rotate_z_inv.w2 <= X"00000000";
                        mat_rotate_z_inv.x3 <= X"00000000";
                        mat_rotate_z_inv.y3 <= X"00000000";
                        mat_rotate_z_inv.z3 <= X"3F800000";
                        mat_rotate_z_inv.w3 <= X"00000000";
                        mat_rotate_z_inv.x4 <= X"00000000";
                        mat_rotate_z_inv.y4 <= X"00000000";
                        mat_rotate_z_inv.z4 <= X"00000000";
                        mat_rotate_z_inv.w4 <= X"3F800000";
                        
                        -- Build translation matrix T
                        mat_translate.x1 <= X"3F800000";
                        mat_translate.y1 <= X"00000000";
                        mat_translate.z1 <= X"00000000";
                        mat_translate.w1 <= X"00000000";
                        mat_translate.x2 <= X"00000000";
                        mat_translate.y2 <= X"3F800000";
                        mat_translate.z2 <= X"00000000";
                        mat_translate.w2 <= X"00000000";
                        mat_translate.x3 <= X"00000000";
                        mat_translate.y3 <= X"00000000";
                        mat_translate.z3 <= X"3F800000";
                        mat_translate.w3 <= X"00000000";
                        mat_translate.x4 <= translate_x;
                        mat_translate.y4 <= translate_y;
                        mat_translate.z4 <= translate_z;
                        mat_translate.w4 <= X"3F800000";
                        
                        -- Build translation inverse T^-1
                        mat_translate_inv.x1 <= X"3F800000";
                        mat_translate_inv.y1 <= X"00000000";
                        mat_translate_inv.z1 <= X"00000000";
                        mat_translate_inv.w1 <= X"00000000";
                        mat_translate_inv.x2 <= X"00000000";
                        mat_translate_inv.y2 <= X"3F800000";
                        mat_translate_inv.z2 <= X"00000000";
                        mat_translate_inv.w2 <= X"00000000";
                        mat_translate_inv.x3 <= X"00000000";
                        mat_translate_inv.y3 <= X"00000000";
                        mat_translate_inv.z3 <= X"3F800000";
                        mat_translate_inv.w3 <= X"00000000";
                        mat_translate_inv.x4 <= not translate_x(31) & translate_x(30 downto 0);
                        mat_translate_inv.y4 <= not translate_y(31) & translate_y(30 downto 0);
                        mat_translate_inv.z4 <= not translate_z(31) & translate_z(30 downto 0);
                        mat_translate_inv.w4 <= X"3F800000";
                        
                        -- Start forward multiplication chain
                        state <= MULT_FORWARD_1;
                    
                    -- ==== FORWARD TRANSFORM: M = T * Rz * Ry * Rx * S ====
                    when MULT_FORWARD_1 =>
                        -- Compute: temp_mat1 = Rx * S (rightmost S applied first)
                        mult_a <= mat_rotate_x;
                        mult_b <= mat_scale;
                        mult_valid_in <= '1';
                        next_state <= MULT_FORWARD_2;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when MULT_FORWARD_2 =>
                        -- Compute: temp_mat2 = Ry * (Rx*S)
                        mult_a <= mat_rotate_y;
                        mult_b <= temp_mat1;
                        mult_valid_in <= '1';
                        next_state <= MULT_FORWARD_3;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when MULT_FORWARD_3 =>
                        -- Compute: temp_mat3 = Rz * (Ry*Rx*S)
                        mult_a <= mat_rotate_z;
                        mult_b <= temp_mat2;
                        mult_valid_in <= '1';
                        next_state <= MULT_FORWARD_4;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when MULT_FORWARD_4 =>
                        -- Compute: transform_matrix = T * (Rz*Ry*Rx*S)
                        mult_a <= mat_translate;
                        mult_b <= temp_mat3;
                        mult_valid_in <= '1';
                        next_state <= MULT_INVERSE_1;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    -- ==== INVERSE TRANSFORM: M^-1 = S^-1 * Rx^T * Ry^T * Rz^T * T^-1 ====
                    when MULT_INVERSE_1 =>
                        -- Compute: temp_mat1 = S^-1 * Rx^T
                        mult_a <= mat_scale_inv;
                        mult_b <= mat_rotate_x_inv;
                        mult_valid_in <= '1';
                        next_state <= MULT_INVERSE_2;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when MULT_INVERSE_2 =>
                        -- Compute: temp_mat2 = temp_mat1 * Ry^T
                        mult_a <= temp_mat1;
                        mult_b <= mat_rotate_y_inv;
                        mult_valid_in <= '1';
                        next_state <= MULT_INVERSE_3;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when MULT_INVERSE_3 =>
                        -- Compute: temp_mat3 = temp_mat2 * Rz^T
                        mult_a <= temp_mat2;
                        mult_b <= mat_rotate_z_inv;
                        mult_valid_in <= '1';
                        next_state <= MULT_INVERSE_4;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when MULT_INVERSE_4 =>
                        -- Compute: inverse_matrix = temp_mat3 * T^-1
                        mult_a <= temp_mat3;
                        mult_b <= mat_translate_inv;
                        mult_valid_in <= '1';
                        next_state <= DONE;
                        state <= WAIT_MULT;
                        wait_counter <= 0;
                    
                    when WAIT_MULT =>
                        if mult_valid_out = '1' then
                            -- Store result based on which multiplication we just did
                            case next_state is
                                when MULT_FORWARD_2 | MULT_INVERSE_2 =>
                                    temp_mat1 <= mult_result;
                                when MULT_FORWARD_3 | MULT_INVERSE_3 =>
                                    temp_mat2 <= mult_result;
                                when MULT_FORWARD_4 | MULT_INVERSE_4 =>
                                    temp_mat3 <= mult_result;
                                when MULT_INVERSE_1 =>
                                    transform_matrix <= mult_result;  -- Forward complete
                                when DONE =>
                                    inverse_matrix <= mult_result;     -- Inverse complete
                                when others =>
                                    null;
                            end case;
                            state <= next_state;
                        elsif wait_counter < 1000 then
                            wait_counter <= wait_counter + 1;
                        else
                            error <= '1';
                            state <= IDLE;
                        end if;
                    
                    when DONE =>
                        report "TRS: DONE" severity note;
                        valid_out <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
