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

    -------------------------------------------------------------------------------
    -- CAMERA GEOMETRY CONSTANTS (commented out for later use)
    -------------------------------------------------------------------------------
    -- constant DEFAULT_POSITION : Vec3 := (
    --     x => X"00000000",  -- 0.0
    --     y => X"C1200000",  -- -10.0
    --     z => X"00000000"   -- 0.0
    -- );
    -- 
    -- constant ALIGNMENT_VECTOR : Vec3 := (
    --     x => X"00000000",  -- 0.0
    --     y => X"3F800000",  -- 1.0
    --     z => X"00000000"   -- 0.0
    -- );
    -- 
    -- constant SCREEN_U : Vec3 := (
    --     x => X"3E800000",  -- 0.25
    --     y => X"00000000",  -- 0.0
    --     z => X"00000000"   -- 0.0
    -- );
    -- 
    -- constant SCREEN_V : Vec3 := (
    --     x => X"00000000",  -- 0.0
    --     y => X"00000000",  -- 0.0
    --     z => X"3E100000"   -- 0.140625
    -- );
    -- 
    -- constant SCREEN_CENTRE : Vec3 := (
    --     x => X"00000000",  -- 0.0
    --     y => X"C1100000",  -- -9.0
    --     z => X"00000000"   -- 0.0
    -- );

    -------------------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    -------------------------------------------------------------------------------
    
    component clk_wiz_0
        port (
            clk_in1  : in  std_logic;
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic
        );
    end component;
    
    component trs_to_matrix_hw
        port (
            clk              : in std_logic;
            reset            : in std_logic;
            scale_x          : in fp32;
            scale_y          : in fp32;
            scale_z          : in fp32;
            rotation_x       : in fp32;
            rotation_y       : in fp32;
            rotation_z       : in fp32;
            translate_x      : in fp32;
            translate_y      : in fp32;
            translate_z      : in fp32;
            valid_in         : in std_logic;
            transform_matrix : out Mat4;
            inverse_matrix   : out Mat4;
            valid_out        : out std_logic;
            error            : out std_logic
        );
    end component;
    
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

    -------------------------------------------------------------------------------
    -- SIGNALS
    -------------------------------------------------------------------------------
    
    -- Clock signals
    signal clk_200mhz   : std_logic;
    signal clk_locked   : std_logic;
    signal reset_sync   : std_logic;
    
    -- Heartbeat counter
    signal counter : unsigned(25 downto 0) := (others => '0');
    
    -- Test control
    signal test_counter : integer := 0;
    signal valid_test   : std_logic := '0';
    
    -------------------------------------------------------------------------------
    -- TRS TRANSFORM TEST SIGNALS
    -------------------------------------------------------------------------------
    -- Test: Transform (1,1,0) with scale 4x, rotate 90° Z, translate (5,5,5)
    -- Expected result: (1, 9, 5, 1)
    
    signal trs_test_vector : Vec4 := (
        x => X"3F800000",  -- 1.0
        y => X"3F800000",  -- 1.0
        z => X"00000000",  -- 0.0
        w => X"3F800000"   -- 1.0
    );
    
    signal trs_forward_matrix : Mat4;
    signal trs_inverse_matrix : Mat4;
    signal trs_valid : std_logic;
    signal trs_error : std_logic;
    signal trs_result : Vec4;
    signal trs_result_valid : std_logic;
    
    -- Debug attributes
    attribute KEEP : string;
    attribute MARK_DEBUG : string;
    
    attribute KEEP of trs_test_vector : signal is "TRUE";
    attribute KEEP of trs_forward_matrix : signal is "TRUE";
    attribute KEEP of trs_valid : signal is "TRUE";
    attribute KEEP of trs_error : signal is "TRUE";
    attribute KEEP of trs_result : signal is "TRUE";
    attribute KEEP of trs_result_valid : signal is "TRUE";
    
    attribute MARK_DEBUG of trs_test_vector : signal is "TRUE";
    attribute MARK_DEBUG of trs_forward_matrix : signal is "TRUE";
    attribute MARK_DEBUG of trs_valid : signal is "TRUE";
    attribute MARK_DEBUG of trs_error : signal is "TRUE";
    attribute MARK_DEBUG of trs_result : signal is "TRUE";
    attribute MARK_DEBUG of trs_result_valid : signal is "TRUE";

begin

    -------------------------------------------------------------------------------
    -- CLOCK GENERATION
    -------------------------------------------------------------------------------
    
    clk_wiz_inst : clk_wiz_0
        port map (
            clk_in1  => clk,
            clk_out1 => clk_200mhz,
            reset    => reset,
            locked   => clk_locked
        );
    
    -- Synchronize reset to 200 MHz clock domain
    -- In simulation, bypass PLL lock check (Clock Wizard doesn't lock in sim)
    process(clk_200mhz)
        variable lock_counter : integer := 0;
    begin
        if rising_edge(clk_200mhz) then
            -- In simulation, force lock after 10 cycles
            -- In hardware, wait for actual PLL lock
            if lock_counter < 10 then
                lock_counter := lock_counter + 1;
                reset_sync <= '1';
            elsif clk_locked = '0' then
                reset_sync <= '1';  -- Still in reset if PLL not locked
            else
                reset_sync <= reset;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------------
    -- HEARTBEAT
    -------------------------------------------------------------------------------
    
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

    -------------------------------------------------------------------------------
    -- TEST CONTROL - Pulse valid_test once after reset
    -------------------------------------------------------------------------------
    
    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset_sync = '1' then
                test_counter <= 0;
                valid_test <= '0';
            else
                test_counter <= test_counter + 1;
                
                -- Trigger operations at cycle 10
                if test_counter = 10 then
                    valid_test <= '1';
                else
                    valid_test <= '0';
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------------
    -- TRS TRANSFORM TEST
    -------------------------------------------------------------------------------
    -- Transform: (1,1,0) -> scale 4x -> rotate 90° Z -> translate (5,5,5)
    -- Expected: (1, 9, 5, 1)
    
    trs_inst : trs_to_matrix_hw
        port map (
            clk => clk_200mhz,
            reset => reset_sync,
            -- Scale: 4x uniform
            scale_x => X"40800000",  -- 4.0
            scale_y => X"40800000",  -- 4.0
            scale_z => X"40800000",  -- 4.0
            -- Rotation: 90° = π/2 radians around Z
            rotation_x => X"00000000",  -- 0.0
            rotation_y => X"00000000",  -- 0.0
            rotation_z => X"3FC90FDB",  -- π/2 ≈ 1.5708 radians
            -- Translation: (5, 5, 5)
            translate_x => X"40A00000",  -- 5.0
            translate_y => X"40A00000",  -- 5.0
            translate_z => X"40A00000",  -- 5.0
            valid_in => valid_test,
            transform_matrix => trs_forward_matrix,
            inverse_matrix => trs_inverse_matrix,
            valid_out => trs_valid,
            error => trs_error
        );
    
    -- Apply the forward transform to test vector (1, 1, 0, 1)
    trs_transform_inst : mat4_vec4_mult_hw
        port map (
            clk => clk_200mhz,
            reset => reset_sync,
            m_in => trs_forward_matrix,
            v_in => trs_test_vector,
            valid_in => trs_valid,
            v_out => trs_result,
            valid_out => trs_result_valid
        );

end Behavioral;
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

    signal test_matrix : Ray := (
       point1 => vec3 ( 
        x => X"01000000",
        y => X"10000000",
        z => X"00100000"
    );
       point2 => vec3 ( 
        x => X"00000001",
        y => X"00000010",
        z => X"00010000"
    );
       map_lab => VEC3_ZERO;
    );

    signal 
begin:


end Behavioral;