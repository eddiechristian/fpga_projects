library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.vec3_pkg.all;

entity top_module is
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        heartbeat : out STD_LOGIC
    );
end top_module;

architecture Behavioral of top_module is

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

    -- Valid signal for all operations
    signal valid_test   : STD_LOGIC := '1';
    
    -- Internal test signals for vec3 operations
    -- Normalize inputs
    signal norm_in      : Vec3 := (x => X"40400000",  -- 3.0
                                    y => X"40800000",  -- 4.0
                                    z => X"00000000"); -- 0.0
    
    -- Add inputs
    signal add_a        : Vec3 := (x => X"3F800000",  -- 1.0
                                    y => X"40000000",  -- 2.0
                                    z => X"40400000"); -- 3.0
    signal add_b        : Vec3 := (x => X"40800000",  -- 4.0
                                    y => X"40A00000",  -- 5.0
                                    z => X"40C00000"); -- 6.0
    
    -- Subtract inputs
    signal sub_a        : Vec3 := (x => X"41200000",  -- 10.0
                                    y => X"41100000",  -- 9.0
                                    z => X"41000000"); -- 8.0
    signal sub_b        : Vec3 := (x => X"3F800000",  -- 1.0
                                    y => X"40000000",  -- 2.0
                                    z => X"40400000"); -- 3.0
    
    -- Dot product inputs
    signal dot_a        : Vec3 := (x => X"40000000",  -- 2.0
                                    y => X"40400000",  -- 3.0
                                    z => X"40800000"); -- 4.0
    signal dot_b        : Vec3 := (x => X"40A00000",  -- 5.0
                                    y => X"40C00000",  -- 6.0
                                    z => X"40E00000"); -- 7.0
    
    -- Cross product inputs
    signal cross_a      : Vec3 := (x => X"3F800000",  -- 1.0
                                    y => X"00000000",  -- 0.0
                                    z => X"00000000"); -- 0.0
    signal cross_b      : Vec3 := (x => X"00000000",  -- 0.0
                                    y => X"3F800000",  -- 1.0
                                    z => X"00000000"); -- 0.0
    
    signal vec_norm_result : Vec3;
    signal vec_norm_valid  : STD_LOGIC;
    signal vec_add_result  : Vec3;
    signal vec_add_valid   : STD_LOGIC;
    signal vec_sub_result  : Vec3;
    signal vec_sub_valid   : STD_LOGIC;
    signal vec_dot_result  : fp32;
    signal vec_dot_valid   : STD_LOGIC;
    signal vec_cross_result: Vec3;
    signal vec_cross_valid : STD_LOGIC;
    
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

begin

    -- Generate heartbeat signal
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
    
    -- Instantiate vec3_normalize: normalize(3.0, 4.0, 0.0) = (0.6, 0.8, 0.0)
    vec3_norm_inst : vec3_normalize_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_test,
            v         => norm_in,
            result    => vec_norm_result,
            valid_out => vec_norm_valid
        );

    -- Instantiate vec3 add: (1,2,3) + (4,5,6) = (5,7,9)
    vec3_add_inst : vec3_add_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_test,
            a         => add_a,
            b         => add_b,
            result    => vec_add_result,
            valid_out => vec_add_valid
        );

    -- Instantiate vec3 sub: (10,9,8) - (1,2,3) = (9,7,5)
    vec3_sub_inst : vec3_sub_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_test,
            a         => sub_a,
            b         => sub_b,
            result    => vec_sub_result,
            valid_out => vec_sub_valid
        );

    -- Instantiate vec3 dot: (2,3,4) · (5,6,7) = 10+18+28 = 56
    vec3_dot_inst : vec3_dot_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_test,
            a         => dot_a,
            b         => dot_b,
            result    => vec_dot_result,
            valid_out => vec_dot_valid
        );

    -- Instantiate vec3 cross: (1,0,0) × (0,1,0) = (0,0,1)
    vec3_cross_inst : vec3_cross_hw
        port map (
            clk       => clk,
            reset     => reset,
            valid_in  => valid_test,
            a         => cross_a,
            b         => cross_b,
            result    => vec_cross_result,
            valid_out => vec_cross_valid
        );

end Behavioral;
