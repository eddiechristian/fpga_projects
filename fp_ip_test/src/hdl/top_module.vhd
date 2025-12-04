library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        -- Input operands (32-bit single precision)
        a_in        : in  STD_LOGIC_VECTOR(31 downto 0);
        b_in        : in  STD_LOGIC_VECTOR(31 downto 0);
        valid_in    : in  STD_LOGIC;
        -- Outputs
        sqrt_out    : out STD_LOGIC_VECTOR(31 downto 0);
        mult_out    : out STD_LOGIC_VECTOR(31 downto 0);
        add_out     : out STD_LOGIC_VECTOR(31 downto 0);
        compare_out : out STD_LOGIC_VECTOR(7 downto 0);
        valid_out   : out STD_LOGIC
    );
end top_module;

architecture Behavioral of top_module is

    -- Component declarations for Vivado Floating Point IP
    component floating_point_sqrt
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    component floating_point_mult
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_b_tvalid         : in  STD_LOGIC;
            s_axis_b_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    component floating_point_add
        port (
            aclk                    : in  STD_LOGIC;
            s_axis_a_tvalid         : in  STD_LOGIC;
            s_axis_a_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_b_tvalid         : in  STD_LOGIC;
            s_axis_b_tdata          : in  STD_LOGIC_VECTOR(31 downto 0);
            m_axis_result_tvalid    : out STD_LOGIC;
            m_axis_result_tdata     : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    component floating_point_compare
        port (
            aclk                        : in  STD_LOGIC;
            s_axis_a_tvalid             : in  STD_LOGIC;
            s_axis_a_tdata              : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_b_tvalid             : in  STD_LOGIC;
            s_axis_b_tdata              : in  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_operation_tvalid     : in  STD_LOGIC;
            s_axis_operation_tdata      : in  STD_LOGIC_VECTOR(7 downto 0);
            m_axis_result_tvalid        : out STD_LOGIC;
            m_axis_result_tdata         : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- Internal signals
    signal sqrt_valid   : STD_LOGIC;
    signal mult_valid   : STD_LOGIC;
    signal add_valid    : STD_LOGIC;
    signal compare_valid: STD_LOGIC;
    signal all_valid    : STD_LOGIC;

begin

    -- Square Root IP
    sqrt_inst : floating_point_sqrt
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => valid_in,
            s_axis_a_tdata          => a_in,
            m_axis_result_tvalid    => sqrt_valid,
            m_axis_result_tdata     => sqrt_out
        );

    -- Multiplication IP
    mult_inst : floating_point_mult
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => valid_in,
            s_axis_a_tdata          => a_in,
            s_axis_b_tvalid         => valid_in,
            s_axis_b_tdata          => b_in,
            m_axis_result_tvalid    => mult_valid,
            m_axis_result_tdata     => mult_out
        );

    -- Addition IP
    add_inst : floating_point_add
        port map (
            aclk                    => clk,
            s_axis_a_tvalid         => valid_in,
            s_axis_a_tdata          => a_in,
            s_axis_b_tvalid         => valid_in,
            s_axis_b_tdata          => b_in,
            m_axis_result_tvalid    => add_valid,
            m_axis_result_tdata     => add_out
        );

    -- Compare IP (operation 24 = greater than)
    compare_inst : floating_point_compare
        port map (
            aclk                        => clk,
            s_axis_a_tvalid             => valid_in,
            s_axis_a_tdata              => a_in,
            s_axis_b_tvalid             => valid_in,
            s_axis_b_tdata              => b_in,
            s_axis_operation_tvalid     => valid_in,
            s_axis_operation_tdata      => X"18",  -- 24 = greater than
            m_axis_result_tvalid        => compare_valid,
            m_axis_result_tdata         => compare_out
        );

    -- Combine all valid signals
    all_valid <= sqrt_valid and mult_valid and add_valid and compare_valid;
    valid_out <= all_valid;

end Behavioral;
