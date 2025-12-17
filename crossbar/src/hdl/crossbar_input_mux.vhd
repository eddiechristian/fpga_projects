LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;
ENTITY crossbar_input_mux IS
    PORT (
        -- Producer data inputs (one array per unit type)
        dot_requests    : IN producer_dot_request_array_t;
        mult_requests   : IN producer_mult_request_array_t;
        fma_requests    : IN producer_fma_request_array_t;
        addsub_requests : IN producer_addsub_request_array_t;

        -- Mux select signals from arbiter
        dot_mux_sel     : IN grant_vector_dot_t;
        mult_mux_sel    : IN grant_vector_mult_t;
        fma_mux_sel     : IN grant_vector_fma_t;
        addsub_mux_sel  : IN grant_vector_addsub_t;

        -- FP unit outputs
        dot_inputs      : OUT fp_dot_input_array_t;
        mult_inputs     : OUT fp_mult_input_array_t;
        fma_inputs      : OUT fp_fma_input_array_t;
        addsub_inputs   : OUT fp_addsub_input_array_t
    );
END crossbar_input_mux;

ARCHITECTURE Behavioral OF crossbar_input_mux IS

BEGIN

    -- DOT unit input multiplexing
    PROCESS (dot_requests, dot_mux_sel)
        VARIABLE sel_prod : INTEGER;
    BEGIN
        FOR unit IN 0 TO NUM_DOT_UNITS - 1 LOOP
            sel_prod := dot_mux_sel(unit);

            IF sel_prod >= 0 AND sel_prod < NUM_PRODUCERS THEN
                -- Valid producer selected
                dot_inputs(unit).valid <= dot_requests(sel_prod).valid;
                dot_inputs(unit).a     <= dot_requests(sel_prod).a;
                dot_inputs(unit).b     <= dot_requests(sel_prod).b;
                dot_inputs(unit).tid   <= dot_requests(sel_prod).tid;
            ELSE
                -- No producer selected (unit idle)
                dot_inputs(unit).valid <= '0';
                dot_inputs(unit).a.x   <= (OTHERS => '0');
                dot_inputs(unit).a.y   <= (OTHERS => '0');
                dot_inputs(unit).a.z   <= (OTHERS => '0');

                dot_inputs(unit).b.x   <= (OTHERS => '0');
                dot_inputs(unit).b.y   <= (OTHERS => '0');
                dot_inputs(unit).b.z   <= (OTHERS => '0');

                dot_inputs(unit).tid   <= (OTHERS => '0');
            END IF;
        END LOOP;
    END PROCESS;
    -- MULT unit input multiplexing
    PROCESS (mult_requests, mult_mux_sel)
        VARIABLE sel_prod : INTEGER;
    BEGIN
        FOR unit IN 0 TO NUM_MULT_UNITS - 1 LOOP
            sel_prod := mult_mux_sel(unit);

            IF sel_prod >= 0 AND sel_prod < NUM_PRODUCERS THEN
                -- Valid producer selected
                mult_inputs(unit).valid <= mult_requests(sel_prod).valid;
                mult_inputs(unit).data  <= mult_requests(sel_prod).data;
                mult_inputs(unit).tid   <= mult_requests(sel_prod).tid;
            ELSE
                -- No producer selected (unit idle)
                mult_inputs(unit).valid <= '0';
                mult_inputs(unit).data  <= (OTHERS => '0');
                mult_inputs(unit).tid   <= (OTHERS => '0');
            END IF;
        END LOOP;
    END PROCESS;

    -- FMA unit input multiplexing
    PROCESS (fma_requests, fma_mux_sel)
        VARIABLE sel_prod : INTEGER;
    BEGIN
        FOR unit IN 0 TO NUM_FMA_UNITS - 1 LOOP
            sel_prod := fma_mux_sel(unit);

            IF sel_prod >= 0 AND sel_prod < NUM_PRODUCERS THEN
                -- Valid producer selected
                fma_inputs(unit).valid <= fma_requests(sel_prod).valid;
                fma_inputs(unit).data  <= fma_requests(sel_prod).data;
                fma_inputs(unit).tid   <= fma_requests(sel_prod).tid;
            ELSE
                -- No producer selected (unit idle)
                fma_inputs(unit).valid <= '0';
                fma_inputs(unit).data  <= (OTHERS => '0');
                fma_inputs(unit).tid   <= (OTHERS => '0');
            END IF;
        END LOOP;
    END PROCESS;

    -- ADDSUB unit input multiplexing
    PROCESS (addsub_requests, addsub_mux_sel)
        VARIABLE sel_prod : INTEGER;
    BEGIN
        FOR unit IN 0 TO NUM_ADDSUB_UNITS - 1 LOOP
            sel_prod := addsub_mux_sel(unit);

            IF sel_prod >= 0 AND sel_prod < NUM_PRODUCERS THEN
                -- Valid producer selected
                addsub_inputs(unit).valid <= addsub_requests(sel_prod).valid;
                addsub_inputs(unit).data  <= addsub_requests(sel_prod).data;
                addsub_inputs(unit).tid   <= addsub_requests(sel_prod).tid;
            ELSE
                -- No producer selected (unit idle)
                addsub_inputs(unit).valid <= '0';
                addsub_inputs(unit).data  <= (OTHERS => '0');
                addsub_inputs(unit).tid   <= (OTHERS => '0');
            END IF;
        END LOOP;
    END PROCESS;

END Behavioral;