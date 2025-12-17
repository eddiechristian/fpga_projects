LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

ENTITY crossbar_fp_system IS
    PORT (
        clk_100mhz      : IN STD_LOGIC;
        rst             : IN STD_LOGIC;
        locked          : OUT STD_LOGIC;

        -- Producer interfaces (separate array per unit type)
        dot_requests    : IN producer_dot_request_array_t;
        mult_requests   : IN producer_mult_request_array_t;
        fma_requests    : IN producer_fma_request_array_t;
        addsub_requests : IN producer_addsub_request_array_t;
        prod_grants     : OUT producer_grant_array_t;
        prod_results    : OUT producer_result_array_t
    );
END crossbar_fp_system;

ARCHITECTURE Structural OF crossbar_fp_system IS

    -- Clock management component (placeholder - will use clk_wiz)
    COMPONENT clk_wiz_0
        PORT (
            clk_in1  : IN STD_LOGIC;
            clk_out1 : OUT STD_LOGIC;
            reset    : IN STD_LOGIC;
            locked   : OUT STD_LOGIC
        );
    END COMPONENT;

    -- Internal clock and reset
    SIGNAL clk_internal   : STD_LOGIC;
    SIGNAL aresetn        : STD_LOGIC;
    SIGNAL locked_i       : STD_LOGIC;

    -- Arbiter outputs
    SIGNAL dot_mux_sel    : grant_vector_dot_t;
    SIGNAL mult_mux_sel   : grant_vector_mult_t;
    SIGNAL fma_mux_sel    : grant_vector_fma_t;
    SIGNAL addsub_mux_sel : grant_vector_addsub_t;

    -- Input mux outputs to FP units
    SIGNAL dot_inputs     : fp_dot_input_array_t;
    SIGNAL mult_inputs    : fp_mult_input_array_t;
    SIGNAL fma_inputs     : fp_fma_input_array_t;
    SIGNAL addsub_inputs  : fp_addsub_input_array_t;

    -- FP unit outputs
    SIGNAL dot_outputs    : fp_dot_output_array_t;
    SIGNAL mult_outputs   : fp_mult_output_array_t;
    SIGNAL fma_outputs    : fp_fma_output_array_t;
    SIGNAL addsub_outputs : fp_addsub_output_array_t;

BEGIN

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
    locked_i     <= NOT rst;
    locked       <= locked_i;

    -- Active-low reset for FP units
    aresetn      <= NOT rst;

    -- Crossbar arbiter
    arbiter_inst : ENTITY work.crossbar_arbiter
        PORT MAP(
            clk             => clk_internal,
            rst             => rst,
            dot_requests    => dot_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            dot_mux_sel     => dot_mux_sel,
            mult_mux_sel    => mult_mux_sel,
            fma_mux_sel     => fma_mux_sel,
            addsub_mux_sel  => addsub_mux_sel
        );

    -- Input multiplexer
    input_mux_inst : ENTITY work.crossbar_input_mux
        PORT MAP(
            dot_requests    => dot_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            dot_mux_sel     => dot_mux_sel,
            mult_mux_sel    => mult_mux_sel,
            fma_mux_sel     => fma_mux_sel,
            addsub_mux_sel  => addsub_mux_sel,
            dot_inputs      => dot_inputs,
            mult_inputs     => mult_inputs,
            fma_inputs      => fma_inputs,
            addsub_inputs   => addsub_inputs
        );

    -- Generate DOT unit wrappers
    gen_dot_units : FOR i IN 0 TO NUM_DOT_UNITS - 1 GENERATE
        dot_inst : ENTITY work.vec3_dot_hw
            PORT MAP(
                clk         => clk_internal,
                aresetn     => aresetn,  -- Active-LOW reset (matches other FP units)
                input_valid => dot_inputs(i).valid,
                input_tid   => dot_inputs(i).tid,
                a           => dot_inputs(i).a,
                b           => dot_inputs(i).b,
                valid_out   => dot_outputs(i).valid,
                result      => dot_outputs(i).data,
                output_tid  => dot_outputs(i).tid
            );
    END GENERATE;

    -- Generate MULT unit wrappers
    gen_mult_units : FOR i IN 0 TO NUM_MULT_UNITS - 1 GENERATE
        mult_wrapper_inst : ENTITY work.fp_mult_wrapper
            PORT MAP(
                aclk         => clk_internal,
                aresetn      => aresetn,
                s_axis_valid => mult_inputs(i).valid,
                s_axis_data  => mult_inputs(i).data(MULT_DATA_WIDTH - 1 DOWNTO 0),
                s_axis_tid   => mult_inputs(i).tid,
                m_axis_valid => mult_outputs(i).valid,
                m_axis_data  => mult_outputs(i).data,
                m_axis_tid   => mult_outputs(i).tid
            );
    END GENERATE;

    -- Generate FMA unit wrappers
    gen_fma_units : FOR i IN 0 TO NUM_FMA_UNITS - 1 GENERATE
        fma_wrapper_inst : ENTITY work.fp_fma_wrapper
            PORT MAP(
                aclk         => clk_internal,
                aresetn      => aresetn,
                s_axis_valid => fma_inputs(i).valid,
                s_axis_data  => fma_inputs(i).data(FMA_DATA_WIDTH - 1 DOWNTO 0),
                s_axis_tid   => fma_inputs(i).tid,
                m_axis_valid => fma_outputs(i).valid,
                m_axis_data  => fma_outputs(i).data,
                m_axis_tid   => fma_outputs(i).tid
            );
    END GENERATE;

    -- Generate ADDSUB unit wrappers
    gen_addsub_units : FOR i IN 0 TO NUM_ADDSUB_UNITS - 1 GENERATE
        addsub_wrapper_inst : ENTITY work.fp_addsub_wrapper
            PORT MAP(
                aclk         => clk_internal,
                aresetn      => aresetn,
                s_axis_valid => addsub_inputs(i).valid,
                s_axis_data  => addsub_inputs(i).data(ADDSUB_DATA_WIDTH - 1 DOWNTO 0),
                s_axis_tid   => addsub_inputs(i).tid,
                m_axis_valid => addsub_outputs(i).valid,
                m_axis_data  => addsub_outputs(i).data,
                m_axis_tid   => addsub_outputs(i).tid
            );
    END GENERATE;

    -- Output router
    output_router_inst : ENTITY work.crossbar_output_router
        PORT MAP(
            clk            => clk_internal,
            rst            => rst,
            dot_outputs    => dot_outputs,
            mult_outputs   => mult_outputs,
            fma_outputs    => fma_outputs,
            addsub_outputs => addsub_outputs,
            prod_results   => prod_results
        );

END Structural;