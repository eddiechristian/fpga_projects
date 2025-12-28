LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;

ENTITY crossbar_arbiter IS
    PORT (
        clk             : IN STD_LOGIC;
        rst             : IN STD_LOGIC;

        -- Producer requests (one array per unit type)
        dot_requests    : IN producer_dot_request_array_t;
        dot4_requests   : IN producer_dot4_request_array_t;
        mult_requests   : IN producer_mult_request_array_t;
        fma_requests    : IN producer_fma_request_array_t;
        addsub_requests : IN producer_addsub_request_array_t;

        -- Producer grants
        prod_grants     : OUT producer_grant_array_t;

        -- Mux select signals for input multiplexers
        dot_mux_sel     : OUT grant_vector_dot_t;
        dot4_mux_sel    : OUT grant_vector_dot4_t;
        mult_mux_sel    : OUT grant_vector_mult_t;
        fma_mux_sel     : OUT grant_vector_fma_t;
        addsub_mux_sel  : OUT grant_vector_addsub_t
    );
END crossbar_arbiter;

ARCHITECTURE Behavioral OF crossbar_arbiter IS

    -- Priority pointers for round-robin arbitration (one per FP unit)
    SIGNAL dot_priority    : INTEGER RANGE 0 TO NUM_PRODUCERS - 1 := 0;
    SIGNAL dot4_priority   : INTEGER RANGE 0 TO NUM_PRODUCERS - 1 := 0;
    SIGNAL mult_priority   : INTEGER RANGE 0 TO NUM_PRODUCERS - 1 := 0;
    SIGNAL fma_priority    : INTEGER RANGE 0 TO NUM_PRODUCERS - 1 := 0;
    SIGNAL addsub_priority : INTEGER RANGE 0 TO NUM_PRODUCERS - 1 := 0;

    -- Priority pointer arrays (one per FP unit of each type)
    TYPE priority_array_dot_t IS ARRAY (0 TO NUM_DOT_UNITS - 1) OF INTEGER RANGE 0 TO NUM_PRODUCERS - 1;
    TYPE priority_array_dot4_t IS ARRAY (0 TO NUM_DOT4_UNITS - 1) OF INTEGER RANGE 0 TO NUM_PRODUCERS - 1;
    TYPE priority_array_mult_t IS ARRAY (0 TO NUM_MULT_UNITS - 1) OF INTEGER RANGE 0 TO NUM_PRODUCERS - 1;
    TYPE priority_array_fma_t IS ARRAY (0 TO NUM_FMA_UNITS - 1) OF INTEGER RANGE 0 TO NUM_PRODUCERS - 1;
    TYPE priority_array_addsub_t IS ARRAY (0 TO NUM_ADDSUB_UNITS - 1) OF INTEGER RANGE 0 TO NUM_PRODUCERS - 1;

    SIGNAL dot_priorities    : priority_array_dot_t    := (OTHERS => 0);
    SIGNAL dot4_priorities   : priority_array_dot4_t   := (OTHERS => 0);
    SIGNAL mult_priorities   : priority_array_mult_t   := (OTHERS => 0);
    SIGNAL fma_priorities    : priority_array_fma_t    := (OTHERS => 0);
    SIGNAL addsub_priorities : priority_array_addsub_t := (OTHERS => 0);

    -- Request matrices (decoded from producer requests)
    SIGNAL req_dot           : request_matrix_dot_t;
    SIGNAL req_dot4          : request_matrix_dot4_t;
    SIGNAL req_mult          : request_matrix_mult_t;
    SIGNAL req_fma           : request_matrix_fma_t;
    SIGNAL req_addsub        : request_matrix_addsub_t;

    -- Grant vectors (internal)
    SIGNAL grant_dot_int     : grant_vector_dot_t;
    SIGNAL grant_dot4_int    : grant_vector_dot4_t;
    SIGNAL grant_mult_int    : grant_vector_mult_t;
    SIGNAL grant_fma_int     : grant_vector_fma_t;
    SIGNAL grant_addsub_int  : grant_vector_addsub_t;

BEGIN

    -- Decode producer requests into request matrices (now simpler with separate arrays)
    PROCESS (dot_requests, dot4_requests, mult_requests, fma_requests, addsub_requests)
    BEGIN
        -- Initialize all requests to 0
        req_dot    <= (OTHERS => (OTHERS => '0'));
        req_dot4   <= (OTHERS => (OTHERS => '0'));
        req_mult   <= (OTHERS => (OTHERS => '0'));
        req_fma    <= (OTHERS => (OTHERS => '0'));
        req_addsub <= (OTHERS => (OTHERS => '0'));

        -- Decode DOT requests
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            IF dot_requests(i).valid = '1' AND dot_requests(i).unit_index < NUM_DOT_UNITS THEN
                req_dot(i, dot_requests(i).unit_index) <= '1';
            END IF;
        END LOOP;

        -- Decode DOT4 requests
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            IF dot4_requests(i).valid = '1' AND dot4_requests(i).unit_index < NUM_DOT4_UNITS THEN
                req_dot4(i, dot4_requests(i).unit_index) <= '1';
            END IF;
        END LOOP;

        -- Decode MULT requests
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP

            IF mult_requests(i).valid = '1' AND mult_requests(i).unit_index < NUM_MULT_UNITS THEN
                REPORT "ARBITER: MULT request from producer " & INTEGER'image(i) & ", unit_index=" & INTEGER'image(mult_requests(i).unit_index) & ", NUM_MULT_UNITS=" & INTEGER'image(NUM_MULT_UNITS);
                req_mult(i, mult_requests(i).unit_index) <= '1';
            END IF;
        END LOOP;

        -- Decode FMA requests
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            IF fma_requests(i).valid = '1' AND fma_requests(i).unit_index < NUM_FMA_UNITS THEN
                req_fma(i, fma_requests(i).unit_index) <= '1';
            END IF;
        END LOOP;

        -- Decode ADDSUB requests
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            IF addsub_requests(i).valid = '1' THEN
                REPORT "ARBITER: ADDSUB request from producer " & INTEGER'image(i) & ", unit_index=" & INTEGER'image(addsub_requests(i).unit_index) & ", NUM_ADDSUB_UNITS=" & INTEGER'image(NUM_ADDSUB_UNITS);
                IF addsub_requests(i).unit_index < NUM_ADDSUB_UNITS THEN
                    req_addsub(i, addsub_requests(i).unit_index) <= '1';
                    REPORT "ARBITER: ADDSUB req_addsub(" & INTEGER'image(i) & "," & INTEGER'image(addsub_requests(i).unit_index) & ") set to 1";
                END IF;
            END IF;
        END LOOP;
    END PROCESS;

    -- Round-robin arbitration for DOT units
    PROCESS (req_dot, dot_priorities)
        VARIABLE winner : INTEGER;
        VARIABLE found  : BOOLEAN;
    BEGIN
        grant_dot_int <= (OTHERS => - 1); -- Default: no grants

        FOR unit IN 0 TO NUM_DOT_UNITS - 1 LOOP
            found := false;
            -- Scan from priority pointer onwards
            FOR offset IN 0 TO NUM_PRODUCERS - 1 LOOP
                winner := (dot_priorities(unit) + offset) MOD NUM_PRODUCERS;
                IF req_dot(winner, unit) = '1' AND NOT found THEN
                    grant_dot_int(unit) <= winner;
                    found := true;
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS;

    -- Round-robin arbitration for DOT4 units
    PROCESS (req_dot4, dot4_priorities)
        VARIABLE winner : INTEGER;
        VARIABLE found  : BOOLEAN;
    BEGIN
        grant_dot4_int <= (OTHERS => - 1); -- Default: no grants

        FOR unit IN 0 TO NUM_DOT4_UNITS - 1 LOOP
            found := false;
            -- Scan from priority pointer onwards
            FOR offset IN 0 TO NUM_PRODUCERS - 1 LOOP
                winner := (dot4_priorities(unit) + offset) MOD NUM_PRODUCERS;
                IF req_dot4(winner, unit) = '1' AND NOT found THEN
                    grant_dot4_int(unit) <= winner;
                    found := true;
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS;

    -- Round-robin arbitration for MULT units
    PROCESS (req_mult, mult_priorities)
        VARIABLE winner : INTEGER;
        VARIABLE found  : BOOLEAN;
    BEGIN
        grant_mult_int <= (OTHERS => - 1); -- Default: no grants

        FOR unit IN 0 TO NUM_MULT_UNITS - 1 LOOP
            found := false;
            -- Scan from priority pointer onwards
            FOR offset IN 0 TO NUM_PRODUCERS - 1 LOOP
                winner := (mult_priorities(unit) + offset) MOD NUM_PRODUCERS;
                IF req_mult(winner, unit) = '1' AND NOT found THEN
                    grant_mult_int(unit) <= winner;
                    found := true;
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS;

    -- Round-robin arbitration for FMA units
    PROCESS (req_fma, fma_priorities)
        VARIABLE winner : INTEGER;
        VARIABLE found  : BOOLEAN;
    BEGIN
        grant_fma_int <= (OTHERS => - 1); -- Default: no grants

        FOR unit IN 0 TO NUM_FMA_UNITS - 1 LOOP
            found := false;
            -- Scan from priority pointer onwards
            FOR offset IN 0 TO NUM_PRODUCERS - 1 LOOP
                winner := (fma_priorities(unit) + offset) MOD NUM_PRODUCERS;
                IF req_fma(winner, unit) = '1' AND NOT found THEN
                    grant_fma_int(unit) <= winner;
                    found := true;
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS;

    -- Round-robin arbitration for ADDSUB units
    PROCESS (req_addsub, addsub_priorities)
        VARIABLE winner : INTEGER;
        VARIABLE found  : BOOLEAN;
    BEGIN
        grant_addsub_int <= (OTHERS => - 1); -- Default: no grants

        FOR unit IN 0 TO NUM_ADDSUB_UNITS - 1 LOOP
            found := false;
            -- Scan from priority pointer onwards
            FOR offset IN 0 TO NUM_PRODUCERS - 1 LOOP
                winner := (addsub_priorities(unit) + offset) MOD NUM_PRODUCERS;
                IF req_addsub(winner, unit) = '1' AND NOT found THEN
                    grant_addsub_int(unit) <= winner;
                    found := true;
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS;

    -- Update priority pointers on clock edge
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                -- Reset all priority pointers
                dot_priorities    <= (OTHERS => 0);
                dot4_priorities   <= (OTHERS => 0);
                mult_priorities   <= (OTHERS => 0);
                fma_priorities    <= (OTHERS => 0);
                addsub_priorities <= (OTHERS => 0);
            ELSE
                -- Update DOT priority pointers
                FOR unit IN 0 TO NUM_DOT_UNITS - 1 LOOP
                    IF grant_dot_int(unit) /= - 1 THEN
                        -- Grant was made, update priority to next producer
                        dot_priorities(unit) <= (grant_dot_int(unit) + 1) MOD NUM_PRODUCERS;
                        REPORT "ARBITER: DOT unit " & INTEGER'image(unit) & " granted to producer " & INTEGER'image(grant_dot_int(unit));
                    END IF;
                END LOOP;

                -- Update DOT4 priority pointers
                FOR unit IN 0 TO NUM_DOT4_UNITS - 1 LOOP
                    IF grant_dot4_int(unit) /= - 1 THEN
                        -- Grant was made, update priority to next producer
                        dot4_priorities(unit) <= (grant_dot4_int(unit) + 1) MOD NUM_PRODUCERS;
                    END IF;
                END LOOP;

                -- Update MULT priority pointers
                FOR unit IN 0 TO NUM_MULT_UNITS - 1 LOOP
                    IF grant_mult_int(unit) /= - 1 THEN
                        -- Grant was made, update priority to next producer
                        mult_priorities(unit) <= (grant_mult_int(unit) + 1) MOD NUM_PRODUCERS;
                    END IF;
                END LOOP;

                -- Update FMA priority pointers
                FOR unit IN 0 TO NUM_FMA_UNITS - 1 LOOP
                    IF grant_fma_int(unit) /= - 1 THEN
                        fma_priorities(unit) <= (grant_fma_int(unit) + 1) MOD NUM_PRODUCERS;
                    END IF;
                END LOOP;

                -- Update ADDSUB priority pointers
                FOR unit IN 0 TO NUM_ADDSUB_UNITS - 1 LOOP
                    IF grant_addsub_int(unit) /= - 1 THEN
                        addsub_priorities(unit) <= (grant_addsub_int(unit) + 1) MOD NUM_PRODUCERS;
                        REPORT "ARBITER: ADDSUB unit " & INTEGER'image(unit) & " granted to producer " & INTEGER'image(grant_addsub_int(unit));
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END PROCESS;

    -- Generate producer grant outputs (reverse mapping from grant vectors)
    PROCESS (grant_dot_int, grant_dot4_int, grant_mult_int, grant_fma_int, grant_addsub_int)
    BEGIN
        -- Default: no grants
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            prod_grants(i).granted    <= '0';
            prod_grants(i).unit_type  <= UNIT_MULT;
            prod_grants(i).unit_index <= 0;
        END LOOP;

        -- Check DOT grants
        FOR unit IN 0 TO NUM_DOT_UNITS - 1 LOOP
            IF grant_dot_int(unit) /= - 1 THEN
                prod_grants(grant_dot_int(unit)).granted    <= '1';
                prod_grants(grant_dot_int(unit)).unit_type  <= UNIT_DOT;
                prod_grants(grant_dot_int(unit)).unit_index <= unit;
            END IF;
        END LOOP;

        -- Check DOT4 grants
        FOR unit IN 0 TO NUM_DOT4_UNITS - 1 LOOP
            IF grant_dot4_int(unit) /= - 1 THEN
                prod_grants(grant_dot4_int(unit)).granted    <= '1';
                prod_grants(grant_dot4_int(unit)).unit_type  <= UNIT_DOT4;
                prod_grants(grant_dot4_int(unit)).unit_index <= unit;
            END IF;
        END LOOP;

        -- Check MULT grants
        FOR unit IN 0 TO NUM_MULT_UNITS - 1 LOOP
            IF grant_mult_int(unit) /= - 1 THEN
                prod_grants(grant_mult_int(unit)).granted    <= '1';
                prod_grants(grant_mult_int(unit)).unit_type  <= UNIT_MULT;
                prod_grants(grant_mult_int(unit)).unit_index <= unit;
            END IF;
        END LOOP;

        -- Check FMA grants
        FOR unit IN 0 TO NUM_FMA_UNITS - 1 LOOP
            IF grant_fma_int(unit) /= - 1 THEN
                prod_grants(grant_fma_int(unit)).granted    <= '1';
                prod_grants(grant_fma_int(unit)).unit_type  <= UNIT_FMA;
                prod_grants(grant_fma_int(unit)).unit_index <= unit;
            END IF;
        END LOOP;

        -- Check ADDSUB grants
        FOR unit IN 0 TO NUM_ADDSUB_UNITS - 1 LOOP
            IF grant_addsub_int(unit) /= - 1 THEN
                prod_grants(grant_addsub_int(unit)).granted    <= '1';
                prod_grants(grant_addsub_int(unit)).unit_type  <= UNIT_ADDSUB;
                prod_grants(grant_addsub_int(unit)).unit_index <= unit;
            END IF;
        END LOOP;
    END PROCESS;

    -- Output mux select signals (direct connection)
    dot_mux_sel    <= grant_dot_int;
    dot4_mux_sel   <= grant_dot4_int;
    mult_mux_sel   <= grant_mult_int;
    fma_mux_sel    <= grant_fma_int;
    addsub_mux_sel <= grant_addsub_int;

END Behavioral;