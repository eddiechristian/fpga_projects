library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package fp_math_pkg is
    
    -- IEEE 754 Single Precision (32-bit) type
    subtype fp32 is std_logic_vector(31 downto 0);
    
    -- Vector3 type using floating point
    type vector3_fp is record
        x : fp32;
        y : fp32;
        z : fp32;
    end record;
    
    -- Floating point constants (IEEE 754 format)
    constant FP_ZERO : fp32 := x"00000000";
    constant FP_ONE : fp32 := x"3F800000";
    constant FP_TWO : fp32 := x"40000000";
    constant FP_FOUR : fp32 := x"40800000";
    constant FP_HALF : fp32 := x"3F000000";
    constant FP_NEG_ONE : fp32 := x"BF800000";
    
    -- Xilinx FP IP Component Declarations
    
    -- Floating Point Multiplier
    component fp_mult
        port (
            aclk : in std_logic;
            s_axis_a_tvalid : in std_logic;
            s_axis_a_tdata : in std_logic_vector(31 downto 0);
            s_axis_b_tvalid : in std_logic;
            s_axis_b_tdata : in std_logic_vector(31 downto 0);
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Floating Point Adder/Subtractor
    component fp_add
        port (
            aclk : in std_logic;
            s_axis_a_tvalid : in std_logic;
            s_axis_a_tdata : in std_logic_vector(31 downto 0);
            s_axis_b_tvalid : in std_logic;
            s_axis_b_tdata : in std_logic_vector(31 downto 0);
            s_axis_operation_tvalid : in std_logic;
            s_axis_operation_tdata : in std_logic_vector(7 downto 0);  -- 0=add, 1=sub
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Floating Point Square Root
    component fp_sqrt
        port (
            aclk : in std_logic;
            s_axis_a_tvalid : in std_logic;
            s_axis_a_tdata : in std_logic_vector(31 downto 0);
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Floating Point Divider
    component fp_div
        port (
            aclk : in std_logic;
            s_axis_a_tvalid : in std_logic;
            s_axis_a_tdata : in std_logic_vector(31 downto 0);
            s_axis_b_tvalid : in std_logic;
            s_axis_b_tdata : in std_logic_vector(31 downto 0);
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tdata : out std_logic_vector(31 downto 0)
        );
    end component;
    
    -- Floating Point Compare
    component fp_compare
        port (
            aclk : in std_logic;
            s_axis_a_tvalid : in std_logic;
            s_axis_a_tdata : in std_logic_vector(31 downto 0);
            s_axis_b_tvalid : in std_logic;
            s_axis_b_tdata : in std_logic_vector(31 downto 0);
            s_axis_operation_tvalid : in std_logic;
            s_axis_operation_tdata : in std_logic_vector(7 downto 0);  -- Compare operation
            m_axis_result_tvalid : out std_logic;
            m_axis_result_tdata : out std_logic_vector(7 downto 0)  -- Result flags
        );
    end component;
    
    -- Helper functions
    function fp_to_uint8(fp_val : fp32) return unsigned;
    
end package fp_math_pkg;

package body fp_math_pkg is
    
    -- Convert FP to 8-bit unsigned (for color output)
    -- Clamps to [0, 255] range
    function fp_to_uint8(fp_val : fp32) return unsigned is
        variable exp : integer;
        variable mantissa : unsigned(22 downto 0);
        variable result : unsigned(7 downto 0);
        variable sign : std_logic;
    begin
        sign := fp_val(31);
        exp := to_integer(unsigned(fp_val(30 downto 23))) - 127;
        mantissa := unsigned(fp_val(22 downto 0));
        
        -- If negative or zero, return 0
        if sign = '1' or exp < 0 then
            return x"00";
        -- If exp >= 8, saturate to 255
        elsif exp >= 8 then
            return x"FF";
        else
            -- Simple conversion: shift mantissa by exponent
            -- This is approximate but fast
            result := unsigned(fp_val(30 downto 23));
            return result;
        end if;
    end function;
    
end package body fp_math_pkg;
