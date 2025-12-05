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

    -- CORDIC component for sin/cos
    component cordic_sincos is
        port (
            aclk                    : in std_logic;
            s_axis_phase_tvalid     : in std_logic;
            s_axis_phase_tdata      : in std_logic_vector(31 downto 0);
            m_axis_dout_tvalid      : out std_logic;
            m_axis_dout_tdata       : out std_logic_vector(63 downto 0)  -- cos in [63:32], sin in [31:0]
        );
    end component;
    
    -- Matrix multiplication component
    component mat4_mult_hw is
        port (
            clk       : in std_logic;
            reset     : in std_logic;
            a         : in Mat4;
            b         : in Mat4;
            valid_in  : in std_logic;
            result    : out Mat4;
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
    signal cordic_phase_valid : std_logic;
    signal cordic_phase : fp32;
    signal cordic_result_valid : std_logic;
    signal cordic_result : std_logic_vector(63 downto 0);
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

begin

    -- Main process
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                valid_out <= '0';
                error <= '0';
            else
                valid_out <= '0';
                error <= '0';
                
                case state is
                    when IDLE =>
                        if valid_in = '1' then
                            state <= BUILD_MATRICES;
                        end if;
                    
                    when BUILD_MATRICES =>
                        -- Build scale matrix S
                        -- | sx  0   0   0 |
                        -- | 0   sy  0   0 |
                        -- | 0   0   sz  0 |
                        -- | 0   0   0   1 |
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
                        
                        -- Build scale inverse S^-1 (just reciprocals)
                        -- | 1/sx  0     0     0 |
                        -- | 0     1/sy  0     0 |
                        -- | 0     0     1/sz  0 |
                        -- | 0     0     0     1 |
                        -- TODO: Need FP divide to compute 1/sx, 1/sy, 1/sz
                        
                        -- Build translation matrix T
                        -- | 1  0  0  tx |
                        -- | 0  1  0  ty |
                        -- | 0  0  1  tz |
                        -- | 0  0  0  1  |
                        mat_translate.x1 <= X"3F800000";  -- 1.0
                        mat_translate.y1 <= X"00000000";
                        mat_translate.z1 <= X"00000000";
                        mat_translate.w1 <= X"00000000";
                        
                        mat_translate.x2 <= X"00000000";
                        mat_translate.y2 <= X"3F800000";  -- 1.0
                        mat_translate.z2 <= X"00000000";
                        mat_translate.w2 <= X"00000000";
                        
                        mat_translate.x3 <= X"00000000";
                        mat_translate.y3 <= X"00000000";
                        mat_translate.z3 <= X"3F800000";  -- 1.0
                        mat_translate.w3 <= X"00000000";
                        
                        mat_translate.x4 <= translate_x;
                        mat_translate.y4 <= translate_y;
                        mat_translate.z4 <= translate_z;
                        mat_translate.w4 <= X"3F800000";  -- 1.0
                        
                        -- Build translation inverse T^-1 (negate translation)
                        -- | 1  0  0  -tx |
                        -- | 0  1  0  -ty |
                        -- | 0  0  1  -tz |
                        -- | 0  0  0  1   |
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
                        
                        -- Negate translation (flip sign bit)
                        mat_translate_inv.x4 <= not translate_x(31) & translate_x(30 downto 0);
                        mat_translate_inv.y4 <= not translate_y(31) & translate_y(30 downto 0);
                        mat_translate_inv.z4 <= not translate_z(31) & translate_z(30 downto 0);
                        mat_translate_inv.w4 <= X"3F800000";
                        
                        -- TODO: Build rotation matrices using sin/cos
                        -- For now, default to identity
                        mat_rotate_x <= MAT4_IDENTITY;
                        mat_rotate_y <= MAT4_IDENTITY;
                        mat_rotate_z <= MAT4_IDENTITY;
                        mat_rotate_x_inv <= MAT4_IDENTITY;
                        mat_rotate_y_inv <= MAT4_IDENTITY;
                        mat_rotate_z_inv <= MAT4_IDENTITY;
                        
                        state <= COMPUTE_FORWARD;
                    
                    when COMPUTE_FORWARD =>
                        -- TODO: Chain matrix multiplications
                        -- M = T * Rz * Ry * Rx * S
                        -- For now, just combine scale and translate
                        -- This is a simplified placeholder
                        transform_matrix <= mat_translate;  -- Simplified
                        state <= COMPUTE_INVERSE;
                    
                    when COMPUTE_INVERSE =>
                        -- TODO: Chain inverse matrix multiplications
                        -- M^-1 = S^-1 * Rx^T * Ry^T * Rz^T * T^-1
                        inverse_matrix <= mat_translate_inv;  -- Simplified
                        state <= DONE;
                    
                    when DONE =>
                        valid_out <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
