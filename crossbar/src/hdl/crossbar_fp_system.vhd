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
        dot4_requests   : IN producer_dot4_request_array_t;
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
    SIGNAL dot4_mux_sel   : grant_vector_dot4_t;
    SIGNAL mult_mux_sel   : grant_vector_mult_t;
    SIGNAL fma_mux_sel    : grant_vector_fma_t;
    SIGNAL addsub_mux_sel : grant_vector_addsub_t;

    -- Input mux outputs to FP units
    SIGNAL dot_inputs     : fp_dot_input_array_t;
    SIGNAL dot4_inputs    : fp_dot4_input_array_t;
    SIGNAL mult_inputs    : fp_mult_input_array_t;
    SIGNAL fma_inputs     : fp_fma_input_array_t;
    SIGNAL addsub_inputs  : fp_addsub_input_array_t;

    -- FP unit outputs
    SIGNAL dot_outputs    : fp_dot_output_array_t;
    SIGNAL dot4_outputs   : fp_dot4_output_array_t;
    SIGNAL mult_outputs   : fp_mult_output_array_t;
    SIGNAL fma_outputs    : fp_fma_output_array_t;
    SIGNAL addsub_outputs : fp_addsub_output_array_t;

    -- Unit busy indicators (for simulation visibility)
    SIGNAL dot_busy       : STD_LOGIC_VECTOR(NUM_DOT_UNITS - 1 DOWNTO 0);
    SIGNAL dot4_busy      : STD_LOGIC_VECTOR(NUM_DOT4_UNITS - 1 DOWNTO 0);
    SIGNAL mult_busy      : STD_LOGIC_VECTOR(NUM_MULT_UNITS - 1 DOWNTO 0);
    SIGNAL fma_busy       : STD_LOGIC_VECTOR(NUM_FMA_UNITS - 1 DOWNTO 0);
    SIGNAL addsub_busy    : STD_LOGIC_VECTOR(NUM_ADDSUB_UNITS - 1 DOWNTO 0);

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
            dot4_requests   => dot4_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            dot_mux_sel     => dot_mux_sel,
            dot4_mux_sel    => dot4_mux_sel,
            mult_mux_sel    => mult_mux_sel,
            fma_mux_sel     => fma_mux_sel,
            addsub_mux_sel  => addsub_mux_sel
        );

    -- Input multiplexer
    input_mux_inst : ENTITY work.crossbar_input_mux
        PORT MAP(
            dot_requests    => dot_requests,
            dot4_requests   => dot4_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            dot_mux_sel     => dot_mux_sel,
            dot4_mux_sel    => dot4_mux_sel,
            mult_mux_sel    => mult_mux_sel,
            fma_mux_sel     => fma_mux_sel,
            addsub_mux_sel  => addsub_mux_sel,
            dot_inputs      => dot_inputs,
            dot4_inputs     => dot4_inputs,
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

    -- Generate DOT4 unit wrappers
    gen_dot4_units : FOR i IN 0 TO NUM_DOT4_UNITS - 1 GENERATE
        dot4_inst : ENTITY work.vec4_dot_hw
            PORT MAP(
                clk         => clk_internal,
                aresetn     => aresetn,
                input_valid => dot4_inputs(i).valid,
                input_tid   => dot4_inputs(i).tid,
                a           => dot4_inputs(i).a,
                b           => dot4_inputs(i).b,
                valid_out   => dot4_outputs(i).valid,
                result      => dot4_outputs(i).data,
                output_tid  => dot4_outputs(i).tid
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

    -- Busy signal tracking: unit is busy from input valid to output valid
    PROCESS(clk_internal)
    BEGIN
        IF rising_edge(clk_internal) THEN
            IF rst = '1' THEN
                dot_busy    <= (OTHERS => '0');
                dot4_busy   <= (OTHERS => '0');
                mult_busy   <= (OTHERS => '0');
                fma_busy    <= (OTHERS => '0');
                addsub_busy <= (OTHERS => '0');
            ELSE
                -- DOT units
                FOR i IN 0 TO NUM_DOT_UNITS - 1 LOOP
                    IF dot_inputs(i).valid = '1' THEN
                        dot_busy(i) <= '1';
                    ELSIF dot_outputs(i).valid = '1' THEN
                        dot_busy(i) <= '0';
                    END IF;
                END LOOP;

                -- DOT4 units
                FOR i IN 0 TO NUM_DOT4_UNITS - 1 LOOP
                    IF dot4_inputs(i).valid = '1' THEN
                        dot4_busy(i) <= '1';
                    ELSIF dot4_outputs(i).valid = '1' THEN
                        dot4_busy(i) <= '0';
                    END IF;
                END LOOP;

                -- MULT units
                FOR i IN 0 TO NUM_MULT_UNITS - 1 LOOP
                    IF mult_inputs(i).valid = '1' THEN
                        mult_busy(i) <= '1';
                    ELSIF mult_outputs(i).valid = '1' THEN
                        mult_busy(i) <= '0';
                    END IF;
                END LOOP;

                -- FMA units
                FOR i IN 0 TO NUM_FMA_UNITS - 1 LOOP
                    IF fma_inputs(i).valid = '1' THEN
                        fma_busy(i) <= '1';
                    ELSIF fma_outputs(i).valid = '1' THEN
                        fma_busy(i) <= '0';
                    END IF;
                END LOOP;

                -- ADDSUB units
                FOR i IN 0 TO NUM_ADDSUB_UNITS - 1 LOOP
                    IF addsub_inputs(i).valid = '1' THEN
                        addsub_busy(i) <= '1';
                    ELSIF addsub_outputs(i).valid = '1' THEN
                        addsub_busy(i) <= '0';
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END PROCESS;

    -- Output router
    output_router_inst : ENTITY work.crossbar_output_router
        PORT MAP(
            clk            => clk_internal,
            rst            => rst,
            dot_outputs    => dot_outputs,
            dot4_outputs   => dot4_outputs,
            mult_outputs   => mult_outputs,
            fma_outputs    => fma_outputs,
            addsub_outputs => addsub_outputs,
            prod_results   => prod_results
        );

END Structural;