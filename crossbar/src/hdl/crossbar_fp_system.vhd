library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;

entity crossbar_fp_system is
    Port (
        clk_100mhz      : in std_logic;
        rst             : in std_logic;
        locked          : out std_logic;
        
        -- Producer interfaces (separate array per unit type)
        mult_requests   : in producer_mult_request_array_t;
        fma_requests    : in producer_fma_request_array_t;
        addsub_requests : in producer_addsub_request_array_t;
        prod_grants     : out producer_grant_array_t;
        prod_results    : out producer_result_array_t
    );
end crossbar_fp_system;

architecture Structural of crossbar_fp_system is

    -- Clock management component (placeholder - will use clk_wiz)
    component clk_wiz_0
        port (
            clk_in1     : in std_logic;
            clk_out1    : out std_logic;
            reset       : in std_logic;
            locked      : out std_logic
        );
    end component;
    
    -- Internal clock and reset
    signal clk_internal : std_logic;
    signal aresetn : std_logic;
    signal locked_i : std_logic;
    
    -- Arbiter outputs
    signal mult_mux_sel    : grant_vector_mult_t;
    signal fma_mux_sel     : grant_vector_fma_t;
    signal addsub_mux_sel  : grant_vector_addsub_t;
    
    -- Input mux outputs to FP units
    signal mult_inputs     : fp_mult_input_array_t;
    signal fma_inputs      : fp_fma_input_array_t;
    signal addsub_inputs   : fp_addsub_input_array_t;
    
    -- FP unit outputs
    signal mult_outputs    : fp_mult_output_array_t;
    signal fma_outputs     : fp_fma_output_array_t;
    signal addsub_outputs  : fp_addsub_output_array_t;

begin

    -- Clock management (for now, pass through - will add PLL/MMCM later)
    -- clk_wiz_inst : clk_wiz_0
    --     port map (
    --         clk_in1  => clk_100mhz,
    --         clk_out1 => clk_internal,
    --         reset    => rst,
    --         locked   => locked_i
    --     );
    
    -- Temporary direct assignment (for initial testing without clock wizard)
    clk_internal <= clk_100mhz;
    locked_i <= not rst;
    locked <= locked_i;
    
    -- Active-low reset for FP units
    aresetn <= not rst;
    
    -- Crossbar arbiter
    arbiter_inst : entity work.crossbar_arbiter
        port map (
            clk             => clk_internal,
            rst             => rst,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            mult_mux_sel    => mult_mux_sel,
            fma_mux_sel     => fma_mux_sel,
            addsub_mux_sel  => addsub_mux_sel
        );
    
    -- Input multiplexer
    input_mux_inst : entity work.crossbar_input_mux
        port map (
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            mult_mux_sel    => mult_mux_sel,
            fma_mux_sel     => fma_mux_sel,
            addsub_mux_sel  => addsub_mux_sel,
            mult_inputs     => mult_inputs,
            fma_inputs      => fma_inputs,
            addsub_inputs   => addsub_inputs
        );
    
    -- Generate MULT unit wrappers
    gen_mult_units: for i in 0 to NUM_MULT_UNITS-1 generate
        mult_wrapper_inst : entity work.fp_mult_wrapper
            port map (
                aclk          => clk_internal,
                aresetn       => aresetn,
                s_axis_valid  => mult_inputs(i).valid,
                s_axis_data   => mult_inputs(i).data(MULT_DATA_WIDTH-1 downto 0),
                s_axis_tid    => mult_inputs(i).tid,
                m_axis_valid  => mult_outputs(i).valid,
                m_axis_data   => mult_outputs(i).data,
                m_axis_tid    => mult_outputs(i).tid
            );
    end generate;
    
    -- Generate FMA unit wrappers
    gen_fma_units: for i in 0 to NUM_FMA_UNITS-1 generate
        fma_wrapper_inst : entity work.fp_fma_wrapper
            port map (
                aclk          => clk_internal,
                aresetn       => aresetn,
                s_axis_valid  => fma_inputs(i).valid,
                s_axis_data   => fma_inputs(i).data(FMA_DATA_WIDTH-1 downto 0),
                s_axis_tid    => fma_inputs(i).tid,
                m_axis_valid  => fma_outputs(i).valid,
                m_axis_data   => fma_outputs(i).data,
                m_axis_tid    => fma_outputs(i).tid
            );
    end generate;
    
    -- Generate ADDSUB unit wrappers
    gen_addsub_units: for i in 0 to NUM_ADDSUB_UNITS-1 generate
        addsub_wrapper_inst : entity work.fp_addsub_wrapper
            port map (
                aclk          => clk_internal,
                aresetn       => aresetn,
                s_axis_valid  => addsub_inputs(i).valid,
                s_axis_data   => addsub_inputs(i).data(ADDSUB_DATA_WIDTH-1 downto 0),
                s_axis_tid    => addsub_inputs(i).tid,
                m_axis_valid  => addsub_outputs(i).valid,
                m_axis_data   => addsub_outputs(i).data,
                m_axis_tid    => addsub_outputs(i).tid
            );
    end generate;
    
    -- Output router
    output_router_inst : entity work.crossbar_output_router
        port map (
            clk            => clk_internal,
            rst            => rst,
            mult_outputs   => mult_outputs,
            fma_outputs    => fma_outputs,
            addsub_outputs => addsub_outputs,
            prod_results   => prod_results
        );

end Structural;
