LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;

-- Dot product producer that uses crossbar FP resources
-- Computes: result = a.x*b.x + a.y*b.y + a.z*b.z
-- 
-- Unlike vec3_dot_hw which has dedicated FP units, this producer
-- shares FP resources through the crossbar with other producers.
-- 
-- State machine:
--   IDLE      : Wait for input_valid signal
--   MULT_XYZ  : Request 3 multiplications
--   WAIT_MULT : Wait for all 3 MULT results
--   ADD_XY    : Request addition of x*x + y*y
--   WAIT_ADD1 : Wait for first ADD result
--   ADD_Z     : Request addition of (x*x+y*y) + z*z
--   WAIT_ADD2 : Wait for final result
--   DONE      : Assert done signal

ENTITY dot_product IS
    GENERIC (
        PRODUCER_ID  : INTEGER := 0;
        MULT_X_INDEX : INTEGER := 0;
        MULT_Y_INDEX : INTEGER := 1;
        MULT_Z_INDEX : INTEGER := 2;
        ADD_INDEX    : INTEGER := 0
    );
    PORT (
        clk          : IN STD_LOGIC;
        rst          : IN STD_LOGIC;

        -- Control interface
        input_valid  : IN STD_LOGIC;

        -- Input vectors
        a            : IN Vec3;
        b            : IN Vec3;

        -- Output
        result       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        result_valid : OUT STD_LOGIC;

        -- Crossbar interface (separate request per unit type)
        mult_request   : OUT producer_mult_request_t;
        fma_request    : OUT producer_fma_request_t;
        addsub_request : OUT producer_addsub_request_t;
        grant          : IN producer_grant_t;
        prod_result    : IN producer_result_t
    );
END ENTITY dot_product;

ARCHITECTURE behavioral OF dot_product IS

    TYPE state_t IS (IDLE, REQUEST_MULTS, WAIT_MULT,
        ADD_XY, WAIT_ADD1, ADD_Z, WAIT_ADD2);
    SIGNAL state           : state_t               := IDLE;

    -- Operation counters for TID generation
    SIGNAL op_counter      : unsigned(10 DOWNTO 0) := (OTHERS => '0');

    -- Storage for intermediate results
    SIGNAL mult_x_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL mult_y_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL mult_z_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL add_xy_result   : STD_LOGIC_VECTOR(31 DOWNTO 0);

    -- Flags for received results
    SIGNAL mult_x_received : STD_LOGIC := '0';
    SIGNAL mult_y_received : STD_LOGIC := '0';
    SIGNAL mult_z_received : STD_LOGIC := '0';
    SIGNAL add_xy_received : STD_LOGIC := '0';

    -- Flags for granted requests (to track which MULTs have been granted)
    SIGNAL mult_x_granted  : STD_LOGIC := '0';
    SIGNAL mult_y_granted  : STD_LOGIC := '0';
    SIGNAL mult_z_granted  : STD_LOGIC := '0';

    -- TID tracking
    SIGNAL tid_mult_x      : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL tid_mult_y      : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL tid_mult_z      : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL tid_add_xy      : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL tid_add_z       : STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN

    -- Main state machine
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state                    <= IDLE;
                mult_request.valid       <= '0';
                mult_request.unit_index  <= 0;
                mult_request.tid         <= (OTHERS => '0');
                fma_request.valid        <= '0';
                fma_request.unit_index   <= 0;
                fma_request.tid          <= (OTHERS => '0');
                addsub_request.valid     <= '0';
                addsub_request.unit_index <= 0;
                addsub_request.tid       <= (OTHERS => '0');
                -- .data fields are combinational, don't initialize
                result_valid             <= '0';
                op_counter         <= (OTHERS => '0');
                mult_x_received    <= '0';
                mult_y_received    <= '0';
                mult_z_received    <= '0';
                add_xy_received    <= '0';
                mult_x_granted     <= '0';
                mult_y_granted     <= '0';
                mult_z_granted     <= '0';

                ELSE
                -- Default: no requests
                mult_request.valid   <= '0';
                fma_request.valid    <= '0';
                addsub_request.valid <= '0';
                result_valid         <= '0';

                CASE state IS
                    WHEN IDLE =>
                        IF input_valid = '1' THEN
                            state           <= REQUEST_MULTS;
                            mult_x_received <= '0';
                            mult_y_received <= '0';
                            mult_z_received <= '0';
                            add_xy_received <= '0';
                            mult_x_granted  <= '0';
                            mult_y_granted  <= '0';
                            mult_z_granted  <= '0';
                            -- Pre-assign TIDs for all 3 multiplications
                            tid_mult_x      <= make_tid(PRODUCER_ID, 0);
                            tid_mult_y      <= make_tid(PRODUCER_ID, 1);
                            tid_mult_z      <= make_tid(PRODUCER_ID, 2);
                            op_counter      <= to_unsigned(3, op_counter'length);
                        END IF;

                    WHEN REQUEST_MULTS =>
                        -- Request whichever MULTs haven't been granted yet (in parallel)
                        mult_request.valid <= '1';

                        -- Priority: X first, then Y, then Z
                        IF mult_x_granted = '0' THEN
                            mult_request.unit_index         <= MULT_X_INDEX;
                            mult_request.data(31 DOWNTO 0)  <= a.x;
                            mult_request.data(63 DOWNTO 32) <= b.x;
                            mult_request.tid                <= tid_mult_x;
                            IF grant.granted = '1' THEN
                                mult_x_granted <= '1';
                                REPORT "DOT_PROD: MULT_X granted in parallel, TID=" & INTEGER'image(to_integer(unsigned(tid_mult_x)));
                            END IF;
                        ELSIF mult_y_granted = '0' THEN
                            mult_request.unit_index         <= MULT_Y_INDEX;
                            mult_request.data(31 DOWNTO 0)  <= a.y;
                            mult_request.data(63 DOWNTO 32) <= b.y;
                            mult_request.tid                <= tid_mult_y;
                            IF grant.granted = '1' THEN
                                mult_y_granted <= '1';
                                REPORT "DOT_PROD: MULT_Y granted in parallel, TID=" & INTEGER'image(to_integer(unsigned(tid_mult_y)));
                            END IF;
                        ELSIF mult_z_granted = '0' THEN
                            mult_request.unit_index         <= MULT_Z_INDEX;
                            mult_request.data(31 DOWNTO 0)  <= a.z;
                            mult_request.data(63 DOWNTO 32) <= b.z;
                            mult_request.tid                <= tid_mult_z;
                            IF grant.granted = '1' THEN
                                mult_z_granted <= '1';
                                REPORT "DOT_PROD: MULT_Z granted in parallel, TID=" & INTEGER'image(to_integer(unsigned(tid_mult_z)));
                            END IF;
                        ELSE
                            -- All 3 MULTs granted, move to wait state
                            mult_request.valid <= '0';
                            state              <= WAIT_MULT;
                        END IF;

                    WHEN WAIT_MULT =>
                        -- Wait for all 3 MULT results
                        IF mult_x_received = '1' AND mult_y_received = '1' AND mult_z_received = '1' THEN
                            state <= ADD_XY;
                        END IF;

                    WHEN ADD_XY =>
                        -- Request addition of X + Y results
                        addsub_request.valid              <= '1';
                        addsub_request.unit_index         <= ADD_INDEX;
                        addsub_request.data(31 DOWNTO 0)  <= mult_x_result;
                        addsub_request.data(63 DOWNTO 32) <= mult_y_result;
                        addsub_request.data(64)           <= '0'; -- ADD operation
                        tid_add_xy                        <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        addsub_request.tid                <= tid_add_xy;

                        IF grant.granted = '1' THEN
                            op_counter <= op_counter + 1;
                            state      <= WAIT_ADD1;
                        END IF;

                    WHEN WAIT_ADD1 =>
                        -- Wait for first ADD result
                        IF add_xy_received = '1' THEN
                            state <= ADD_Z;
                        END IF;

                    WHEN ADD_Z =>
                        -- Request addition of (X+Y) + Z
                        addsub_request.valid              <= '1';
                        addsub_request.unit_index         <= ADD_INDEX;
                        addsub_request.data(31 DOWNTO 0)  <= add_xy_result;
                        addsub_request.data(63 DOWNTO 32) <= mult_z_result;
                        addsub_request.data(64)           <= '0'; -- ADD operation
                        tid_add_z                         <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        addsub_request.tid                <= tid_add_z;

                        IF grant.granted = '1' THEN
                            op_counter <= op_counter + 1;
                            state      <= WAIT_ADD2;
                        END IF;

                    WHEN WAIT_ADD2 =>
                        -- Final result received, pulse result_valid and return to IDLE
                        IF prod_result.valid = '1' AND prod_result.tid = tid_add_z THEN
                            result       <= prod_result.data;
                            result_valid <= '1';
                            state        <= IDLE;
                        END IF;

                END CASE;

                -- Result capture process (runs in parallel with state machine)
                IF prod_result.valid = '1' THEN
                    REPORT "DOT_PROD: Received result TID=" & INTEGER'image(to_integer(unsigned(prod_result.tid)))
                    & " Expected: X=" & INTEGER'image(to_integer(unsigned(tid_mult_x)))
                    & " Y=" & INTEGER'image(to_integer(unsigned(tid_mult_y)))
                    & " Z=" & INTEGER'image(to_integer(unsigned(tid_mult_z)));
                    IF prod_result.tid = tid_mult_x THEN
                        mult_x_result   <= prod_result.data;
                        mult_x_received <= '1';
                        REPORT "DOT_PROD: MULT_X result captured";
                        ELSIF prod_result.tid = tid_mult_y THEN
                        mult_y_result   <= prod_result.data;
                        mult_y_received <= '1';
                        REPORT "DOT_PROD: MULT_Y result captured";
                        ELSIF prod_result.tid = tid_mult_z THEN
                        mult_z_result   <= prod_result.data;
                        mult_z_received <= '1';
                        REPORT "DOT_PROD: MULT_Z result captured";
                        ELSIF prod_result.tid = tid_add_xy THEN
                        add_xy_result   <= prod_result.data;
                        add_xy_received <= '1';
                        REPORT "DOT_PROD: ADD_XY result captured";
                    END IF;
                END IF;

            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;