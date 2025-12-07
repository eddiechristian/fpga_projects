library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lin_alg_pkg.all;

entity top_module is
    Port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        led     : out std_logic
    );
end top_module;

architecture Behavioral of top_module is

    component clk_wiz_0
        port (
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    component trs_to_matrix_hw is
        Port (
            clk            : in std_logic;
            reset          : in std_logic;
            scale_x        : in fp32;
            scale_y        : in fp32;
            scale_z        : in fp32;
            rotation_x     : in fp32;
            rotation_y     : in fp32;
            rotation_z     : in fp32;
            translate_x    : in fp32;
            translate_y    : in fp32;
            translate_z    : in fp32;
            valid_in       : in std_logic;
            transform_matrix : out Mat4;
            inverse_matrix   : out Mat4;
            valid_out        : out std_logic;
            error          : out std_logic
        );
    end component;

    component mat4_vec4_mult_hw is
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

    signal clk_200mhz : std_logic;
    signal locked : std_logic;
    signal counter : integer := 0;
    
    -- TRS test signals
    signal trs_scale_x, trs_scale_y, trs_scale_z : fp32;
    signal trs_rot_x, trs_rot_y, trs_rot_z : fp32;
    signal trs_trans_x, trs_trans_y, trs_trans_z : fp32;
    signal trs_valid_in : std_logic := '0';
    signal trs_matrix : Mat4;
    signal trs_inverse : Mat4;
    signal trs_valid_out : std_logic;
    signal trs_error : std_logic;
    
    -- Transform test
    signal trs_input_vec : Vec4;
    signal trs_result : Vec4;
    signal trs_result_valid : std_logic;
    
    attribute MARK_DEBUG : string;
    attribute KEEP : string;
    
    attribute MARK_DEBUG of trs_scale_x : signal is "TRUE";
    attribute MARK_DEBUG of trs_scale_y : signal is "TRUE";
    attribute MARK_DEBUG of trs_scale_z : signal is "TRUE";
    attribute MARK_DEBUG of trs_rot_z : signal is "TRUE";
    attribute MARK_DEBUG of trs_trans_x : signal is "TRUE";
    attribute MARK_DEBUG of trs_trans_y : signal is "TRUE";
    attribute MARK_DEBUG of trs_trans_z : signal is "TRUE";
    attribute MARK_DEBUG of trs_valid_in : signal is "TRUE";
    attribute MARK_DEBUG of trs_matrix : signal is "TRUE";
    attribute MARK_DEBUG of trs_valid_out : signal is "TRUE";
    attribute MARK_DEBUG of trs_error : signal is "TRUE";
    attribute MARK_DEBUG of trs_input_vec : signal is "TRUE";
    attribute MARK_DEBUG of trs_result : signal is "TRUE";
    attribute MARK_DEBUG of trs_result_valid : signal is "TRUE";
    
    attribute KEEP of trs_result : signal is "TRUE";
    attribute KEEP of trs_error : signal is "TRUE";

begin

    clk_wiz_inst: clk_wiz_0 port map (
        clk_out1 => clk_200mhz,
        reset => reset,
        locked => locked,
        clk_in1 => clk
    );

    -- TRS Test: Transform (1,1,0) with scale 4x, rotate 90° Z, translate (5,5,5)
    -- Expected result: (1, 9, 5, 1)
    trs_scale_x <= X"40800000";    -- 4.0
    trs_scale_y <= X"40800000";    -- 4.0
    trs_scale_z <= X"40800000";    -- 4.0
    trs_rot_x <= X"00000000";      -- 0 radians
    trs_rot_y <= X"00000000";      -- 0 radians
    trs_rot_z <= X"3FC90FDB";      -- π/2 radians (90 degrees)
    trs_trans_x <= X"40A00000";    -- 5.0
    trs_trans_y <= X"40A00000";    -- 5.0
    trs_trans_z <= X"40A00000";    -- 5.0
    trs_input_vec <= make_vec4(X"3F800000", X"3F800000", X"00000000"); -- (1,1,0,1)

    trs_inst: trs_to_matrix_hw port map (
        clk => clk_200mhz,
        reset => reset,
        scale_x => trs_scale_x,
        scale_y => trs_scale_y,
        scale_z => trs_scale_z,
        rotation_x => trs_rot_x,
        rotation_y => trs_rot_y,
        rotation_z => trs_rot_z,
        translate_x => trs_trans_x,
        translate_y => trs_trans_y,
        translate_z => trs_trans_z,
        valid_in => trs_valid_in,
        transform_matrix => trs_matrix,
        inverse_matrix => trs_inverse,
        valid_out => trs_valid_out,
        error => trs_error
    );

    trs_transform_inst: mat4_vec4_mult_hw port map (
        clk => clk_200mhz,
        reset => reset,
        m_in => trs_matrix,
        v_in => trs_input_vec,
        valid_in => trs_valid_out,
        v_out => trs_result,
        valid_out => trs_result_valid
    );

    process(clk_200mhz)
    begin
        if rising_edge(clk_200mhz) then
            if reset = '1' then
                counter <= 0;
                trs_valid_in <= '0';
            else
                counter <= counter + 1;
                
                -- Trigger TRS computation at cycle 10
                if counter = 10 then
                    trs_valid_in <= '1';
                else
                    trs_valid_in <= '0';
                end if;
            end if;
        end if;
    end process;

    led <= trs_result_valid;

end Behavioral;
