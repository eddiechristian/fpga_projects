library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lin_alg_pkg.all;

entity top_module is
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        heartbeat : out STD_LOGIC
    );
end top_module;

architecture Behavioral of top_module is

     constant DEFAULT_POSITION : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"C1200000",  -- -10.0
        z => X"00000000"   -- 0.0
    );
    
    -- Precomputed camera geometry constants
    -- Based on UpdateCameraGeometry() with scene.cpp parameters
    
    -- alignmentVector = (0, 1, 0) - normalized direction from camera to lookAt
    constant ALIGNMENT_VECTOR : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"3F800000",  -- 1.0
        z => X"00000000"   -- 0.0
    );
    
    -- projectionScreenU = (0.25, 0, 0) - horizontal screen vector scaled by horzSize
    constant SCREEN_U : Vec3 := (
        x => X"3E800000",  -- 0.25
        y => X"00000000",  -- 0.0
        z => X"00000000"   -- 0.0
    );
    
    -- projectionScreenV = (0, 0, 0.140625) - vertical screen vector scaled by horzSize/aspect
    constant SCREEN_V : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"00000000",  -- 0.0
        z => X"3E100000"   -- 0.140625 (approx, actual is 0.25/1.777)
    );
    
    -- projectionScreenCentre = (0, -9, 0) - center of projection screen
    constant SCREEN_CENTRE : Vec3 := (
        x => X"00000000",  -- 0.0
        y => X"C1100000",  -- -9.0
        z => X"00000000"   -- 0.0
    );

    -- Component declaration for vec3_normalize
    component vec3_normalize_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            v         : in  Vec3;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    -- Component declaration for vec3_add
    component vec3_add_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            a         : in  Vec3;
            b         : in  Vec3;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    -- Component declaration for vec3_sub
    component vec3_sub_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            a         : in  Vec3;
            b         : in  Vec3;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    -- Component declaration for vec3_dot
    component vec3_dot_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            a         : in  Vec3;
            b         : in  Vec3;
            result    : out fp32;
            valid_out : out std_logic
        );
    end component;
    
    -- Component declaration for vec3_cross
    component vec3_cross_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            a         : in  Vec3;
            b         : in  Vec3;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    -- Component declaration for vec3_scale
    component vec3_scale_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            valid_in  : in  std_logic;
            v         : in  Vec3;
            scalar    : in  fp32;
            result    : out Vec3;
            valid_out : out std_logic
        );
    end component;
    
    -- Component declaration for Clocking Wizard
    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;  -- 100 MHz input
            clk_out1 : out std_logic;  -- 200 MHz output
            reset    : in  std_logic;  -- Active high reset
            locked   : out std_logic   -- PLL locked indicator
        );
    end component;
    
    -- Component declaration for mat4_vec4_mult
    component mat4_vec4_mult_hw
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            m_in      : in  Mat4;
            v_in      : in  Vec4;
            valid_in  : in  std_logic;
            v_out     : out Vec4;
            valid_out : out std_logic
        );
    end component;

    -- Clock signals
    signal clk_200mhz   : STD_LOGIC;  -- 200 MHz clock from Clocking Wizard
    signal clk_locked   : STD_LOGIC;  -- PLL locked indicator
    signal reset_sync   : STD_LOGIC;  -- Synchronized reset for 200 MHz domain
    
    -- Valid signal for all operations
    signal valid_test   : STD_LOGIC := '1';
    
    -------------------------------------------------------------------------------
    -- CAMERA GEOMETRY COMPUTATION PIPELINE
    -------------------------------------------------------------------------------
    -- This module computes all camera geometry vectors needed for ray tracing,
    -- implementing the UpdateCameraGeometry() function from camera.cpp
    --
    -- Given:
    --   cameraPosition = (0, -10, 0)  [DEFAULT_POSITION]
    --   lookAt = (0, 0, 0)            [VEC3_ZERO]
    --   cameraUp = (0, 0, 1)          [VEC3_UNIT_Z]
    --   cameraLength = 1.0
    --   cameraHorzSize = 0.25
    --   cameraAspectRatio = 1.777 (16:9)
    --
    -- STEP 1: Compute Alignment Vector (camera direction)
    --   a) Subtract: lookAt - position = (0,0,0) - (0,-10,0) = (0,10,0)
    --   b) Normalize: (0,10,0) → (0,1,0)
    --   Result: alignmentVector = (0,1,0)
    --
    -- STEP 2: Compute U Vector (horizontal screen direction)
    --   a) Cross: alignmentVector × cameraUp = (0,1,0) × (0,0,1) = (1,0,0)
    --   b) Normalize: (1,0,0) → (1,0,0)  [already unit length]                    << EDDIE YOU MAY BE ABLE TO GET RID OF THIS!!!!
    --   c) Scale: (1,0,0) * 0.25 = (0.25,0,0)
    --   Result: projectionScreenU = (0.25,0,0)
    --
    -- STEP 3: Compute V Vector (vertical screen direction)
    --   a) Cross: projectionScreenU × alignmentVector = (1,0,0) × (0,1,0) = (0,0,1)
    --   b) Normalize: (0,0,1) → (0,0,1)  [already unit length]
    --   c) Scale: (0,0,1) * (0.25/1.777) = (0,0,1) * 0.140625 = (0,0,0.140625)
    --   Result: projectionScreenV = (0,0,0.140625)
    --
    -- STEP 4: Compute Screen Center (center point of projection screen)
    --   a) Scale: alignmentVector * cameraLength = (0,1,0) * 1.0 = (0,1,0)
    --   b) Add: position + scaled_alignment = (0,-10,0) + (0,1,0) = (0,-9,0)
    --   Result: projectionScreenCentre = (0,-9,0)
    --
    -- All operations are pipelined and chained through valid signals.
    -------------------------------------------------------------------------------



    -- Internal test signals for vec3 operations
    -- Subtract inputs: compute lookAt (VEC3_ZERO) - position (DEFAULT_POSITION)
    -- This gives the camera direction vector before normalization
    signal sub_a        : Vec3 := VEC3_ZERO;           -- lookAt = (0, 0, 0)
    signal sub_b        : Vec3 := DEFAULT_POSITION;    -- position = (0, -10, 0)
    -- Expected result: (0, 0, 0) - (0, -10, 0) = (0, 10, 0)
    
    -- Normalize input: will be set to the subtraction result
    -- This will normalize (0, 10, 0) to (0, 1, 0) - the alignment vector
    signal norm_in      : Vec3 := VEC3_ZERO;  -- Will be updated from vec_sub_result
    
    -- Add inputs: repurposed for screen center computation
    -- These will be updated from the chaining processes above
    signal add_a        : Vec3 := VEC3_ZERO;  -- Will be cameraPosition
    signal add_b        : Vec3 := VEC3_ZERO;  -- Will be alignment * cameraLength
    
    -- Dot product inputs
    signal dot_a        : Vec3 := (x => X"40000000",  -- 2.0
                                    y => X"40400000",  -- 3.0
                                    z => X"40800000"); -- 4.0
    signal dot_b        : Vec3 := (x => X"40A00000",  -- 5.0
                                    y => X"40C00000",  -- 6.0
                                    z => X"40E00000"); -- 7.0
    
    -- Cross product inputs: compute projectionScreenU (step 2)
    -- cross_a = alignmentVector (will be updated from vec_norm_result)
    -- cross_b = cameraUp = VEC3_UNIT_Z = (0, 0, 1)
    signal cross_a      : Vec3 := VEC3_ZERO;  -- Will be updated from vec_norm_result (alignment vector)
    signal cross_b      : Vec3 := VEC3_UNIT_Z;  -- cameraUp = (0, 0, 1)
    -- Expected: cross((0,1,0), (0,0,1)) = (1,0,0) - the U vector before normalization
    
    -- Camera parameters
    constant m_camera_length      : fp32 := X"3F800000";  -- 1.0
    constant m_camera_horz_size   : fp32 := X"3E800000";  -- 0.25
    constant m_camera_aspect_ratio : fp32 := X"3FE38E39";  -- 1.777... (16:9)
    -- horzSize / aspectRatio = 0.25 / 1.777 = 0.140625
    constant m_camera_vert_size   : fp32 := X"3E100000";  -- 0.140625
    
    -- Operation results
    signal vec_norm_result : Vec3;  -- Step 1: alignment vector normalized
    signal vec_norm_valid  : STD_LOGIC;
    signal vec_add_result  : Vec3;
    signal vec_add_valid   : STD_LOGIC;
    signal vec_sub_result  : Vec3;  -- Step 1: lookAt - position
    signal vec_sub_valid   : STD_LOGIC;
    signal vec_dot_result  : fp32;
    signal vec_dot_valid   : STD_LOGIC;
    signal vec_cross_result: Vec3;  -- Step 2: U vector (unnormalized)
    signal vec_cross_valid : STD_LOGIC;
    
    -- Additional operations for camera setup
    -- U vector computation
    signal norm_u_in       : Vec3 := VEC3_ZERO;  -- Input to U normalization
    signal vec_norm_u_result : Vec3;  -- Step 2: normalized U vector
    signal vec_norm_u_valid  : STD_LOGIC;
    signal vec_scale_u_result : Vec3;  -- Step 2: U * horzSize (final projectionScreenU)
    signal vec_scale_u_valid  : STD_LOGIC;
    
    -- V vector computation
    signal cross_v_a       : Vec3 := VEC3_ZERO;  -- Will be updated from normalized U
    signal cross_v_b       : Vec3 := VEC3_ZERO;  -- Will be updated from alignment vector
    signal vec_cross_v_result : Vec3;  -- Step 3: V vector (unnormalized)
    signal vec_cross_v_valid  : STD_LOGIC;
    signal norm_v_in       : Vec3 := VEC3_ZERO;  -- Input to V normalization
    signal vec_norm_v_result : Vec3;  -- Step 3: normalized V vector
    signal vec_norm_v_valid  : STD_LOGIC;
    signal vec_scale_v_result : Vec3;  -- Step 3: V * vertSize (final projectionScreenV)
    signal vec_scale_v_valid  : STD_LOGIC;
    
    -- Screen center computation
    signal scale_alignment_in : Vec3 := VEC3_ZERO;  -- Will be updated from alignment vector
    signal vec_scale_alignment_result : Vec3;  -- alignment * cameraLength
    signal vec_scale_alignment_valid  : STD_LOGIC;
    signal add_center_a    : Vec3 := VEC3_ZERO;  -- Will be cameraPosition (DEFAULT_POSITION)
    signal add_center_b    : Vec3 := VEC3_ZERO;  -- Will be scaled alignment vector
    signal vec_screen_center_result : Vec3;  -- Final projectionScreenCentre
    signal vec_screen_center_valid  : STD_LOGIC;
    
    -- KEEP and MARK_DEBUG attributes to preserve signals in synthesis for post-synth simulation
    attribute KEEP : string;
    attribute MARK_DEBUG : string;
    
    attribute KEEP of vec_norm_result : signal is "TRUE";
    attribute KEEP of vec_norm_valid  : signal is "TRUE";
    attribute KEEP of vec_add_result  : signal is "TRUE";
    attribute KEEP of vec_add_valid   : signal is "TRUE";
    attribute KEEP of vec_sub_result  : signal is "TRUE";
    attribute KEEP of vec_sub_valid   : signal is "TRUE";
    attribute KEEP of vec_dot_result  : signal is "TRUE";
    attribute KEEP of vec_dot_valid   : signal is "TRUE";
    attribute KEEP of vec_cross_result: signal is "TRUE";
    attribute KEEP of vec_cross_valid : signal is "TRUE";
    
    attribute MARK_DEBUG of vec_norm_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_norm_valid  : signal is "TRUE";
    attribute MARK_DEBUG of vec_add_result  : signal is "TRUE";
    attribute MARK_DEBUG of vec_add_valid   : signal is "TRUE";
    attribute MARK_DEBUG of vec_sub_result  : signal is "TRUE";
    attribute MARK_DEBUG of vec_sub_valid   : signal is "TRUE";
    attribute MARK_DEBUG of vec_dot_result  : signal is "TRUE";
    attribute MARK_DEBUG of vec_dot_valid   : signal is "TRUE";
    attribute MARK_DEBUG of vec_cross_result: signal is "TRUE";
    attribute MARK_DEBUG of vec_cross_valid : signal is "TRUE";
    
    -- KEEP and MARK_DEBUG for camera setup signals
    attribute KEEP of norm_u_in : signal is "TRUE";
    attribute KEEP of vec_norm_u_result : signal is "TRUE";
    attribute KEEP of vec_norm_u_valid  : signal is "TRUE";
    attribute KEEP of vec_scale_u_result : signal is "TRUE";
    attribute KEEP of vec_scale_u_valid  : signal is "TRUE";
    
    attribute MARK_DEBUG of vec_norm_u_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_norm_u_valid  : signal is "TRUE";
    attribute MARK_DEBUG of vec_scale_u_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_scale_u_valid  : signal is "TRUE";
    
    -- KEEP and MARK_DEBUG for V vector signals
    attribute KEEP of cross_v_a : signal is "TRUE";
    attribute KEEP of cross_v_b : signal is "TRUE";
    attribute KEEP of vec_cross_v_result : signal is "TRUE";
    attribute KEEP of vec_cross_v_valid  : signal is "TRUE";
    attribute KEEP of norm_v_in : signal is "TRUE";
    attribute KEEP of vec_norm_v_result : signal is "TRUE";
    attribute KEEP of vec_norm_v_valid  : signal is "TRUE";
    attribute KEEP of vec_scale_v_result : signal is "TRUE";
    attribute KEEP of vec_scale_v_valid  : signal is "TRUE";
    
    attribute MARK_DEBUG of vec_cross_v_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_cross_v_valid  : signal is "TRUE";
    attribute MARK_DEBUG of vec_norm_v_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_norm_v_valid  : signal is "TRUE";
    attribute MARK_DEBUG of vec_scale_v_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_scale_v_valid  : signal is "TRUE";
    
    -- KEEP and MARK_DEBUG for screen center signals
    attribute KEEP of scale_alignment_in : signal is "TRUE";
    attribute KEEP of vec_scale_alignment_result : signal is "TRUE";
    attribute KEEP of vec_scale_alignment_valid  : signal is "TRUE";
    attribute KEEP of add_center_a : signal is "TRUE";
    attribute KEEP of add_center_b : signal is "TRUE";
    attribute KEEP of vec_screen_center_result : signal is "TRUE";
    attribute KEEP of vec_screen_center_valid  : signal is "TRUE";
    
    attribute MARK_DEBUG of vec_scale_alignment_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_scale_alignment_valid  : signal is "TRUE";
    attribute MARK_DEBUG of vec_screen_center_result : signal is "TRUE";
    attribute MARK_DEBUG of vec_screen_center_valid  : signal is "TRUE";
    
    -- KEEP attributes for input signals too
    attribute KEEP of norm_in  : signal is "TRUE";
    attribute KEEP of add_a    : signal is "TRUE";
    attribute KEEP of add_b    : signal is "TRUE";
    attribute KEEP of sub_a    : signal is "TRUE";
    attribute KEEP of sub_b    : signal is "TRUE";
    attribute KEEP of dot_a    : signal is "TRUE";
    attribute KEEP of dot_b    : signal is "TRUE";
    attribute KEEP of cross_a  : signal is "TRUE";
    attribute KEEP of cross_b  : signal is "TRUE";
    
    -- Heartbeat counter
    signal counter         : unsigned(25 downto 0) := (others => '0');
    
    -------------------------------------------------------------------------------
    -- MATRIX-VECTOR TRANSFORM TEST SIGNALS
    -------------------------------------------------------------------------------
    -- Test transformation of a point by a 2x scale matrix
    -- Test matrix: 2x scale (identity * 2)
    signal test_matrix : Mat4 := (
        x1 => X"40000000",  -- 2.0
        y1 => X"00000000",  -- 0.0
        z1 => X"00000000",  -- 0.0
        w1 => X"00000000",  -- 0.0
        x2 => X"00000000",  -- 0.0
        y2 => X"40000000",  -- 2.0
        z2 => X"00000000",  -- 0.0
        w2 => X"00000000",  -- 0.0
        x3 => X"00000000",  -- 0.0
        y3 => X"00000000",  -- 0.0
        z3 => X"40000000",  -- 2.0
        w3 => X"00000000",  -- 0.0
        x4 => X"00000000",  -- 0.0
        y4 => X"00000000",  -- 0.0
        z4 => X"00000000",  -- 0.0
        w4 => X"3F800000"   -- 1.0
    );
    
    -- Test vector: (1, 2, 3, 1)
    signal test_vector : Vec4 := (
        x => X"3F800000",  -- 1.0
        y => X"40000000",  -- 2.0
        z => X"40400000",  -- 3.0
        w => X"3F800000"   -- 1.0
    );
    
    -- Result: should be (2, 4, 6, 1)
    signal transform_result : Vec4;
    signal transform_valid : std_logic;
    
    attribute KEEP of test_matrix : signal is "TRUE";
    attribute KEEP of test_vector : signal is "TRUE";
    attribute KEEP of transform_result : signal is "TRUE";
    attribute KEEP of transform_valid : signal is "TRUE";
    
    attribute MARK_DEBUG of test_matrix : signal is "TRUE";
    attribute MARK_DEBUG of test_vector : signal is "TRUE";
    attribute MARK_DEBUG of transform_result : signal is "TRUE";
    attribute MARK_DEBUG of transform_valid : signal is "TRUE";

begin

    -- Instantiate Clocking Wizard: Generate 200 MHz from 100 MHz
    clk_wiz_inst : clk_wiz_0
        port map (
            clk_in1  => clk,        -- 100 MHz input
            clk_out1 => clk_200mhz, -- 200 MHz output
            reset    => reset,      -- Reset input
            locked   => clk_locked  -- PLL locked status
        );
    
    -- Synchronize reset to 200 MHz clock domain
    -- Hold reset until PLL is locked
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if clk_locked = '0' then
                reset_sync <= '1';
            else
                reset_sync <= reset;
            end if;
        end if;
    end process;

    -- Generate heartbeat signal (runs on 100 MHz clock)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                counter <= (others => '0');
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    heartbeat <= counter(25);
    
    -- All following processes run on 200 MHz clock for 2x speedup
    
    -- Update norm_in from subtraction result
    -- This chains the operations: sub_result -> normalize
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                norm_in <= VEC3_ZERO;
            elsif vec_sub_valid = '1' then
                norm_in <= vec_sub_result;
            end if;
        end if;
    end process;
    
    -- Update cross_a from normalize result (alignment vector)
    -- This chains: normalize_result -> cross product
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                cross_a <= VEC3_ZERO;
            elsif vec_norm_valid = '1' then
                cross_a <= vec_norm_result;
            end if;
        end if;
    end process;
    
    -- Update norm_u_in from cross result
    -- This chains: cross_result -> normalize U vector
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                norm_u_in <= VEC3_ZERO;
            elsif vec_cross_valid = '1' then
                norm_u_in <= vec_cross_result;
            end if;
        end if;
    end process;
    
    -- Update cross_v inputs for V vector computation
    -- cross_v_a = normalized U, cross_v_b = alignment vector
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                cross_v_a <= VEC3_ZERO;
                cross_v_b <= VEC3_ZERO;
            else
                -- Update cross_v_a from normalized U
                if vec_norm_u_valid = '1' then
                    cross_v_a <= vec_norm_u_result;
                end if;
                -- Update cross_v_b from alignment vector (first normalize result)
                if vec_norm_valid = '1' then
                    cross_v_b <= vec_norm_result;
                end if;
            end if;
        end if;
    end process;
    
    -- Update norm_v_in from V cross result
    -- This chains: cross_v_result -> normalize V vector
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                norm_v_in <= VEC3_ZERO;
            elsif vec_cross_v_valid = '1' then
                norm_v_in <= vec_cross_v_result;
            end if;
        end if;
    end process;
    
    -- Update scale_alignment_in for screen center computation
    -- This chains: alignment vector -> scale by cameraLength
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                scale_alignment_in <= VEC3_ZERO;
            elsif vec_norm_valid = '1' then
                scale_alignment_in <= vec_norm_result;
            end if;
        end if;
    end process;
    
    -- Update add_center inputs for screen center computation
    -- add_center_a = cameraPosition, add_center_b = scaled alignment
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                add_center_a <= VEC3_ZERO;
                add_center_b <= VEC3_ZERO;
            else
                -- Camera position is constant
                add_center_a <= DEFAULT_POSITION;
                -- Update from scaled alignment vector
                if vec_scale_alignment_valid = '1' then
                    add_center_b <= vec_scale_alignment_result;
                end if;
            end if;
        end if;
    end process;
    
    -- Instantiate vec3_normalize: normalize camera direction vector
    -- Normalizes (0, 10, 0) -> (0, 1, 0) which is the alignment vector
    vec3_norm_inst : vec3_normalize_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            v         => norm_in,
            result    => vec_norm_result,
            valid_out => vec_norm_valid
        );

    -- Instantiate vec3_scale: scale alignment by cameraLength (for screen center)
    -- Scales (0,1,0) * 1.0 = (0,1,0)
    vec3_scale_alignment_inst : vec3_scale_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            v         => scale_alignment_in,
            scalar    => m_camera_length,
            result    => vec_scale_alignment_result,
            valid_out => vec_scale_alignment_valid
        );

    -- Instantiate vec3 add: compute screen center (step 4)
    -- position + (alignment * length) = (0,-10,0) + (0,1,0) = (0,-9,0)
    vec3_add_inst : vec3_add_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            a         => add_center_a,
            b         => add_center_b,
            result    => vec_screen_center_result,
            valid_out => vec_screen_center_valid
        );

    -- Instantiate vec3 sub: compute lookAt - position = (0,0,0) - (0,-10,0) = (0,10,0)
    -- This gives the camera direction vector before normalization
    vec3_sub_inst : vec3_sub_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            a         => sub_a,
            b         => sub_b,
            result    => vec_sub_result,
            valid_out => vec_sub_valid
        );

    -- Instantiate vec3 dot: (2,3,4) · (5,6,7) = 10+18+28 = 56
    vec3_dot_inst : vec3_dot_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            a         => dot_a,
            b         => dot_b,
            result    => vec_dot_result,
            valid_out => vec_dot_valid
        );

    -- Instantiate vec3 cross: compute projectionScreenU (step 2)
    -- cross(alignmentVector, cameraUp) = cross((0,1,0), (0,0,1)) = (1,0,0)
    -- This is the horizontal screen vector (unnormalized, already unit length in this case)
    vec3_cross_inst : vec3_cross_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            a         => cross_a,
            b         => cross_b,
            result    => vec_cross_result,
            valid_out => vec_cross_valid
        );

    -- Instantiate second vec3_normalize: normalize U vector (step 2 continued)
    -- Normalizes (1,0,0) -> (1,0,0) - already unit length, but required by algorithm
    vec3_norm_u_inst : vec3_normalize_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            v         => norm_u_in,
            result    => vec_norm_u_result,
            valid_out => vec_norm_u_valid
        );

    -- Instantiate vec3_scale: multiply U by horizontal size (step 2 final)
    -- Scales (1,0,0) * 0.25 = (0.25,0,0) - final projectionScreenU
    vec3_scale_u_inst : vec3_scale_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => vec_norm_u_valid,
            v         => vec_norm_u_result,
            scalar    => m_camera_horz_size,
            result    => vec_scale_u_result,
            valid_out => vec_scale_u_valid
        );

    -- Instantiate second vec3_cross: compute V vector (step 3)
    -- cross(projectionScreenU, alignmentVector) = cross((1,0,0), (0,1,0)) = (0,0,1)
    vec3_cross_v_inst : vec3_cross_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            a         => cross_v_a,
            b         => cross_v_b,
            result    => vec_cross_v_result,
            valid_out => vec_cross_v_valid
        );

    -- Instantiate third vec3_normalize: normalize V vector (step 3 continued)
    -- Normalizes (0,0,1) -> (0,0,1) - already unit length
    vec3_norm_v_inst : vec3_normalize_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => valid_test,
            v         => norm_v_in,
            result    => vec_norm_v_result,
            valid_out => vec_norm_v_valid
        );

    -- Instantiate second vec3_scale: multiply V by vertical size (step 3 final)
    -- Scales (0,0,1) * 0.140625 = (0,0,0.140625) - final projectionScreenV
    vec3_scale_v_inst : vec3_scale_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            valid_in  => vec_norm_v_valid,
            v         => vec_norm_v_result,
            scalar    => m_camera_vert_size,
            result    => vec_scale_v_result,
            valid_out => vec_scale_v_valid
        );

    -------------------------------------------------------------------------------
    -- MATRIX-VECTOR TRANSFORM TEST
    -------------------------------------------------------------------------------
    -- Test transformation of a point by a 2x scale matrix
    -- Transform: v' = M * v where
    --   M = 2x scale matrix (scale by 2 in x, y, z)
    --   v = (1, 2, 3, 1) homogeneous point
    -- Expected result: (2, 4, 6, 1)
    -------------------------------------------------------------------------------
    
    mat4_vec4_mult_inst : mat4_vec4_mult_hw
        port map (
            clk       => clk_200mhz,
            reset     => reset_sync,
            m_in      => test_matrix,
            v_in      => test_vector,
            valid_in  => valid_test,
            v_out     => transform_result,
            valid_out => transform_valid
        );

end Behavioral;
