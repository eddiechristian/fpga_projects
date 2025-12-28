LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;
USE work.crossbar_pkg.ALL;

-- Generate Ray - Full 4-Stage Pipeline Architecture
-- Expected steady-state throughput: ~12 cycles per ray (10x speedup from 54 cycles)
-- 
-- Pipeline stages:
--   Stage 1 (INPUT): Accept inputs → FIFO1
--   Stage 2 (SCALE): scale_u + scale_v (parallel) → FIFO2
--   Stage 3 (ADD1): screen_centre + scale_u → FIFO3
--   Stage 4 (ADD2): add1_result + scale_v → FIFO4
--   Stage 5 (SUB): add2_result - position → Output
--
-- Producer allocation:
--   ID 0: coord_calc_x multiply
--   ID 1: coord_calc_y multiply  
--   ID 2: coord_calc_x subtract
--   ID 3: coord_calc_y subtract
--   ID 4: scale_u
--   ID 5: scale_v
--   ID 6: add1
--   ID 7: add2
--   ID 8: sub
-- Total: 9 producer IDs needed

ENTITY generate_ray IS
    GENERIC (
        WIDTH            : INTEGER               := 640;
        HEIGHT           : INTEGER               := 480;
        PRODUCER_ID_BASE : INTEGER RANGE 0 TO 25 := 0; -- Needs 9 consecutive IDs
        FIFO_DEPTH       : INTEGER               := 32 -- Inter-stage buffer depth
    );
    PORT (
        clk             : IN STD_LOGIC;
        reset           : IN STD_LOGIC;

        pixel_x         : IN INTEGER;
        pixel_y         : IN INTEGER;
        valid_in        : IN STD_LOGIC;
        camera_in       : IN Camera;
        ready_out       : OUT STD_LOGIC; -- Can accept new input

        ray             : OUT Ray;
        valid_out       : OUT STD_LOGIC;

        -- Crossbar interfaces
        mult_requests   : OUT producer_mult_request_array_t;
        mult_grants     : IN producer_grant_array_t;
        mult_results    : IN producer_result_array_t;

        addsub_requests : OUT producer_addsub_request_array_t;
        addsub_grants   : IN producer_grant_array_t;
        addsub_results  : IN producer_result_array_t
    );
END ENTITY generate_ray;

ARCHITECTURE behavioral OF generate_ray IS

    -- FIFO data widths (each includes pixel_x and pixel_y as 2x32-bit integers = 64 bits)
    -- FIFO1: 2*fp32 + 4*Vec3 + 2*INT = 64 + 384 + 64 = 512 bits
    -- FIFO2: 4*Vec3 + 2*INT = 384 + 64 = 448 bits
    -- FIFO3: 3*Vec3 + 2*INT = 288 + 64 = 352 bits
    -- FIFO4: 2*Vec3 + 2*INT = 192 + 64 = 256 bits
    CONSTANT FIFO1_WIDTH : INTEGER := 512;
    CONSTANT FIFO2_WIDTH : INTEGER := 448;
    CONSTANT FIFO3_WIDTH : INTEGER := 352;
    CONSTANT FIFO4_WIDTH : INTEGER := 256;

    -- Component declarations
    COMPONENT gen_ray_fifo IS
        GENERIC (
            DATA_WIDTH : INTEGER := 32;
            DEPTH      : INTEGER := 4
        );
        PORT (
            clk     : IN STD_LOGIC;
            reset   : IN STD_LOGIC;
            wr_en   : IN STD_LOGIC;
            wr_data : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            full    : OUT STD_LOGIC;
            rd_en   : IN STD_LOGIC;
            rd_data : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            empty   : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT vec3_scale_hw IS
        GENERIC (
            PRODUCER_ID : INTEGER RANGE 0 TO 31 := 0
        );
        PORT (
            clk           : IN STD_LOGIC;
            reset         : IN STD_LOGIC;
            valid_in      : IN STD_LOGIC;
            v             : IN Vec3;
            scalar        : IN fp32;
            result        : OUT Vec3;
            valid_out     : OUT STD_LOGIC;
            mult_requests : OUT producer_mult_request_array_t;
            mult_grants   : IN producer_grant_array_t;
            mult_results  : IN producer_result_array_t
        );
    END COMPONENT;

    COMPONENT vec3_add_hw IS
        GENERIC (
            PRODUCER_ID : INTEGER RANGE 0 TO 31 := 0
        );
        PORT (
            clk             : IN STD_LOGIC;
            reset           : IN STD_LOGIC;
            valid_in        : IN STD_LOGIC;
            a               : IN Vec3;
            b               : IN Vec3;
            result          : OUT Vec3;
            valid_out       : OUT STD_LOGIC;
            addsub_requests : OUT producer_addsub_request_array_t;
            addsub_grants   : IN producer_grant_array_t;
            addsub_results  : IN producer_result_array_t
        );
    END COMPONENT;

    COMPONENT vec3_sub_hw IS
        GENERIC (
            PRODUCER_ID : INTEGER RANGE 0 TO 31 := 0
        );
        PORT (
            clk             : IN STD_LOGIC;
            reset           : IN STD_LOGIC;
            valid_in        : IN STD_LOGIC;
            a               : IN Vec3;
            b               : IN Vec3;
            result          : OUT Vec3;
            valid_out       : OUT STD_LOGIC;
            addsub_requests : OUT producer_addsub_request_array_t;
            addsub_grants   : IN producer_grant_array_t;
            addsub_results  : IN producer_result_array_t
        );
    END COMPONENT;

    -- Stage state machines
    TYPE stage_state_t IS (IDLE, READ, BUSY);
    SIGNAL coord_calc_stage_state                                          : stage_state_t := IDLE;
    SIGNAL scale_state                                                     : stage_state_t := IDLE;
    SIGNAL add1_state                                                      : stage_state_t := IDLE;
    SIGNAL add2_state                                                      : stage_state_t := IDLE;
    SIGNAL sub_state                                                       : stage_state_t := IDLE;

    -- FIFO1 signals (COORD_CALC → SCALE)
    SIGNAL fifo1_wr_en                                                     : STD_LOGIC     := '0';
    SIGNAL fifo1_wr_data                                                   : STD_LOGIC_VECTOR(FIFO1_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo1_full                                                      : STD_LOGIC;
    SIGNAL fifo1_rd_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo1_rd_data                                                   : STD_LOGIC_VECTOR(FIFO1_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo1_empty                                                     : STD_LOGIC;

    -- FIFO2 signals (SCALE → ADD1)
    SIGNAL fifo2_wr_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo2_wr_data                                                   : STD_LOGIC_VECTOR(FIFO2_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo2_full                                                      : STD_LOGIC;
    SIGNAL fifo2_rd_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo2_rd_data                                                   : STD_LOGIC_VECTOR(FIFO2_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo2_empty                                                     : STD_LOGIC;

    -- FIFO3 signals (ADD1 → ADD2)
    SIGNAL fifo3_wr_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo3_wr_data                                                   : STD_LOGIC_VECTOR(FIFO3_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo3_full                                                      : STD_LOGIC;
    SIGNAL fifo3_rd_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo3_rd_data                                                   : STD_LOGIC_VECTOR(FIFO3_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo3_empty                                                     : STD_LOGIC;

    -- FIFO4 signals (ADD2 → SUB)
    SIGNAL fifo4_wr_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo4_wr_data                                                   : STD_LOGIC_VECTOR(FIFO4_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo4_full                                                      : STD_LOGIC;
    SIGNAL fifo4_rd_en                                                     : STD_LOGIC := '0';
    SIGNAL fifo4_rd_data                                                   : STD_LOGIC_VECTOR(FIFO4_WIDTH - 1 DOWNTO 0);
    SIGNAL fifo4_empty                                                     : STD_LOGIC;

    -- Unpacked FIFO1 data
    SIGNAL f1_proScreenX                                                   : fp32;
    SIGNAL f1_proScreenY                                                   : fp32;
    SIGNAL f1_screen_u                                                     : Vec3;
    SIGNAL f1_screen_v                                                     : Vec3;
    SIGNAL f1_screen_centre                                                : Vec3;
    SIGNAL f1_position                                                     : Vec3;
    SIGNAL f1_pixel_x, f1_pixel_y                                          : INTEGER;

    -- Unpacked FIFO2 data
    SIGNAL f2_scale_u                                                      : Vec3;
    SIGNAL f2_scale_v                                                      : Vec3;
    SIGNAL f2_screen_centre                                                : Vec3;
    SIGNAL f2_position                                                     : Vec3;
    SIGNAL f2_pixel_x, f2_pixel_y                                          : INTEGER;

    -- Unpacked FIFO3 data
    SIGNAL f3_add1_result                                                  : Vec3;
    SIGNAL f3_scale_v                                                      : Vec3;
    SIGNAL f3_position                                                     : Vec3;
    SIGNAL f3_pixel_x, f3_pixel_y                                          : INTEGER;

    -- Unpacked FIFO4 data
    SIGNAL f4_add2_result                                                  : Vec3;
    SIGNAL f4_position                                                     : Vec3;
    SIGNAL f4_pixel_x, f4_pixel_y                                          : INTEGER;

    -- Vec3 operation signals
    SIGNAL scale_u_result, scale_v_result                                  : Vec3                            := VEC3_ZERO;
    SIGNAL add1_result, add2_result                                        : Vec3                            := VEC3_ZERO;
    SIGNAL sub_result                                                      : Vec3                            := VEC3_ZERO;

    SIGNAL scale_u_valid, scale_v_valid                                    : STD_LOGIC                       := '0';
    SIGNAL add1_valid, add2_valid                                          : STD_LOGIC                       := '0';
    SIGNAL sub_valid                                                       : STD_LOGIC                       := '0';

    SIGNAL scale_u_start, scale_v_start                                    : STD_LOGIC                       := '0';
    SIGNAL add1_start, add2_start                                          : STD_LOGIC                       := '0';
    SIGNAL sub_start                                                       : STD_LOGIC                       := '0';

    -- Valid latches for scale stage (both must complete)
    SIGNAL scale_u_valid_latched                                           : STD_LOGIC                       := '0';
    SIGNAL scale_v_valid_latched                                           : STD_LOGIC                       := '0';

    -- Temporary storage for scale stage
    SIGNAL scale_stage_proScreenX                                          : fp32                            := (OTHERS => '0');
    SIGNAL scale_stage_proScreenY                                          : fp32                            := (OTHERS => '0');
    SIGNAL scale_stage_screen_u                                            : Vec3                            := VEC3_ZERO;
    SIGNAL scale_stage_screen_v                                            : Vec3                            := VEC3_ZERO;
    SIGNAL scale_stage_screen_centre                                       : Vec3                            := VEC3_ZERO;
    SIGNAL scale_stage_position                                            : Vec3                            := VEC3_ZERO;
    SIGNAL scale_stage_pixel_x, scale_stage_pixel_y                        : INTEGER                         := 0;

    -- Staging registers for ADD1/ADD2/SUB stages
    SIGNAL add1_stage_screen_centre                                        : Vec3                            := VEC3_ZERO;
    SIGNAL add1_stage_scale_u                                              : Vec3                            := VEC3_ZERO;
    SIGNAL add1_stage_scale_v                                              : Vec3                            := VEC3_ZERO;
    SIGNAL add1_stage_position                                             : Vec3                            := VEC3_ZERO;
    SIGNAL add1_stage_pixel_x, add1_stage_pixel_y                          : INTEGER                         := 0;
    SIGNAL add2_stage_add1_result                                          : Vec3                            := VEC3_ZERO;
    SIGNAL add2_stage_scale_v                                              : Vec3                            := VEC3_ZERO;
    SIGNAL add2_stage_position                                             : Vec3                            := VEC3_ZERO;
    SIGNAL add2_stage_pixel_x, add2_stage_pixel_y                          : INTEGER                         := 0;
    SIGNAL sub_stage_position                                              : Vec3                            := VEC3_ZERO;
    SIGNAL sub_stage_add2_result                                           : Vec3                            := VEC3_ZERO;
    SIGNAL sub_stage_pixel_x, sub_stage_pixel_y                            : INTEGER                         := 0;

    -- Request arrays for each component
    SIGNAL scale_u_mult_requests, scale_v_mult_requests                    : producer_mult_request_array_t   := (OTHERS => init_producer_mult_request);
    SIGNAL add1_addsub_requests, add2_addsub_requests, sub_addsub_requests : producer_addsub_request_array_t := (OTHERS => init_producer_addsub_request);

    -- Coordinate calculation stage signals
    SIGNAL mult_x_granted, mult_y_granted                                  : STD_LOGIC                       := '0';
    SIGNAL mult_x_done, mult_y_done                                        : STD_LOGIC                       := '0';
    SIGNAL sub_x_granted, sub_y_granted                                    : STD_LOGIC                       := '0';
    SIGNAL sub_x_done, sub_y_done                                          : STD_LOGIC                       := '0';

    SIGNAL mult_x_result, mult_y_result                                    : fp32;
    SIGNAL proScreenX_calc, proScreenY_calc                                : fp32;

    -- Coord calc request arrays
    SIGNAL coord_mult_requests                                             : producer_mult_request_array_t   := (OTHERS => init_producer_mult_request);
    SIGNAL coord_addsub_requests                                           : producer_addsub_request_array_t := (OTHERS => init_producer_addsub_request);

    -- Staging registers for coord calc stage (captures camera data + pixels directly from input)
    SIGNAL coord_stage_screen_u                                            : Vec3                            := VEC3_ZERO;
    SIGNAL coord_stage_screen_v                                            : Vec3                            := VEC3_ZERO;
    SIGNAL coord_stage_screen_centre                                       : Vec3                            := VEC3_ZERO;
    SIGNAL coord_stage_position                                            : Vec3                            := VEC3_ZERO;

    -- Save pixel coordinates for populating Ray at output
    SIGNAL pixel_x_save                                                    : INTEGER                         := 0;
    SIGNAL pixel_y_save                                                    : INTEGER                         := 0;
    -- Helper function to convert integer to fp32
    FUNCTION int_to_fp32(i                                                 : INTEGER) RETURN fp32 IS
        VARIABLE abs_i                                                         : INTEGER;
        VARIABLE sign                                                          : STD_LOGIC;
        VARIABLE exponent                                                      : INTEGER;
        VARIABLE mantissa                                                      : INTEGER;
        VARIABLE result                                                        : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE temp                                                          : INTEGER;
    BEGIN
        IF i = 0 THEN
            RETURN X"00000000";
        END IF;
        abs_i := ABS(i);
        IF i < 0 THEN
            sign := '1';
        ELSE
            sign := '0';
        END IF;
        exponent := 127;
        temp     := abs_i;
        FOR bit_pos IN 30 DOWNTO 0 LOOP
            IF temp >= (2 ** bit_pos) THEN
                exponent := 127 + bit_pos;
                EXIT;
            END IF;
        END LOOP;
        IF (exponent - 127) >= 23 THEN
            mantissa := abs_i / (2 ** ((exponent - 127) - 23));
        ELSE
            mantissa := abs_i * (2 ** (23 - (exponent - 127)));
        END IF;
        mantissa             := mantissa MOD (2 ** 23);
        result(31)           := sign;
        result(30 DOWNTO 23) := STD_LOGIC_VECTOR(TO_UNSIGNED(exponent, 8));
        result(22 DOWNTO 0)  := STD_LOGIC_VECTOR(TO_UNSIGNED(mantissa, 23));
        RETURN result;
    END FUNCTION;

    -- Function to compute 2.0/dimension at synthesis time
    FUNCTION compute_factor(dimension : INTEGER) RETURN fp32 IS
        VARIABLE factor                   : REAL;
        VARIABLE sign                     : STD_LOGIC;
        VARIABLE exponent                 : INTEGER;
        VARIABLE mantissa                 : INTEGER;
        VARIABLE result                   : STD_LOGIC_VECTOR(31 DOWNTO 0);
        VARIABLE normalized               : REAL;
    BEGIN
        factor := 2.0 / REAL(dimension);
        IF factor = 0.0 THEN
            RETURN X"00000000";
        END IF;
        sign       := '0';
        normalized := factor;
        exponent   := 127;
        IF normalized >= 2.0 THEN
            WHILE normalized >= 2.0 LOOP
                normalized := normalized / 2.0;
                exponent   := exponent + 1;
            END LOOP;
        ELSIF normalized < 1.0 THEN
            WHILE normalized < 1.0 LOOP
                normalized := normalized * 2.0;
                exponent   := exponent - 1;
            END LOOP;
        END IF;
        mantissa             := INTEGER((normalized - 1.0) * (2.0 ** 23));
        result(31)           := sign;
        result(30 DOWNTO 23) := STD_LOGIC_VECTOR(TO_UNSIGNED(exponent, 8));
        result(22 DOWNTO 0)  := STD_LOGIC_VECTOR(TO_UNSIGNED(mantissa, 23));
        RETURN result;
    END FUNCTION;

    CONSTANT x_factor : fp32 := compute_factor(640);
    CONSTANT y_factor : fp32 := compute_factor(480);

    -- Helper function to pack FIFO1 data
    FUNCTION pack_fifo1_data(
        screenX, screenY                            : fp32;
        screen_u, screen_v, screen_centre, position : Vec3;
        pixel_x, pixel_y                            : INTEGER
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO1_WIDTH - 1 DOWNTO 0);
    BEGIN
        result(31 DOWNTO 0)    := screenX;
        result(63 DOWNTO 32)   := screenY;
        result(95 DOWNTO 64)   := screen_u.x;
        result(127 DOWNTO 96)  := screen_u.y;
        result(159 DOWNTO 128) := screen_u.z;
        result(191 DOWNTO 160) := screen_v.x;
        result(223 DOWNTO 192) := screen_v.y;
        result(255 DOWNTO 224) := screen_v.z;
        result(287 DOWNTO 256) := screen_centre.x;
        result(319 DOWNTO 288) := screen_centre.y;
        result(351 DOWNTO 320) := screen_centre.z;
        result(383 DOWNTO 352) := position.x;
        result(415 DOWNTO 384) := position.y;
        result(447 DOWNTO 416) := position.z;
        result(479 DOWNTO 448) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_x, 32));
        result(511 DOWNTO 480) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_y, 32));
        RETURN result;
    END FUNCTION;

    -- Helper function to pack FIFO2 data
    FUNCTION pack_fifo2_data(
        scale_u, scale_v, screen_centre, position : Vec3;
        pixel_x, pixel_y                           : INTEGER
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO2_WIDTH - 1 DOWNTO 0);
    BEGIN
        result(31 DOWNTO 0)    := scale_u.x;
        result(63 DOWNTO 32)   := scale_u.y;
        result(95 DOWNTO 64)   := scale_u.z;
        result(127 DOWNTO 96)  := scale_v.x;
        result(159 DOWNTO 128) := scale_v.y;
        result(191 DOWNTO 160) := scale_v.z;
        result(223 DOWNTO 192) := screen_centre.x;
        result(255 DOWNTO 224) := screen_centre.y;
        result(287 DOWNTO 256) := screen_centre.z;
        result(319 DOWNTO 288) := position.x;
        result(351 DOWNTO 320) := position.y;
        result(383 DOWNTO 352) := position.z;
        result(415 DOWNTO 384) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_x, 32));
        result(447 DOWNTO 416) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_y, 32));
        RETURN result;
    END FUNCTION;

    -- Helper function to pack FIFO3 data
    FUNCTION pack_fifo3_data(
        add1_result, scale_v, position : Vec3;
        pixel_x, pixel_y                : INTEGER
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO3_WIDTH - 1 DOWNTO 0);
    BEGIN
        result(31 DOWNTO 0)    := add1_result.x;
        result(63 DOWNTO 32)   := add1_result.y;
        result(95 DOWNTO 64)   := add1_result.z;
        result(127 DOWNTO 96)  := scale_v.x;
        result(159 DOWNTO 128) := scale_v.y;
        result(191 DOWNTO 160) := scale_v.z;
        result(223 DOWNTO 192) := position.x;
        result(255 DOWNTO 224) := position.y;
        result(287 DOWNTO 256) := position.z;
        result(319 DOWNTO 288) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_x, 32));
        result(351 DOWNTO 320) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_y, 32));
        RETURN result;
    END FUNCTION;

    -- Helper function to pack FIFO4 data
    FUNCTION pack_fifo4_data(
        add2_result, position : Vec3;
        pixel_x, pixel_y      : INTEGER
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO4_WIDTH - 1 DOWNTO 0);
    BEGIN
        result(31 DOWNTO 0)    := add2_result.x;
        result(63 DOWNTO 32)   := add2_result.y;
        result(95 DOWNTO 64)   := add2_result.z;
        result(127 DOWNTO 96)  := position.x;
        result(159 DOWNTO 128) := position.y;
        result(191 DOWNTO 160) := position.z;
        result(223 DOWNTO 192) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_x, 32));
        result(255 DOWNTO 224) := STD_LOGIC_VECTOR(TO_SIGNED(pixel_y, 32));
        RETURN result;
    END FUNCTION;

BEGIN

    -- Instantiate FIFOs (FIFO0 removed - COORD_CALC takes inputs directly)
    fifo1 : gen_ray_fifo
    GENERIC MAP(DATA_WIDTH => FIFO1_WIDTH, DEPTH => FIFO_DEPTH)
    PORT MAP(
        clk => clk, reset => reset, wr_en => fifo1_wr_en, wr_data => fifo1_wr_data,
        full => fifo1_full, rd_en => fifo1_rd_en, rd_data => fifo1_rd_data, empty => fifo1_empty);

    fifo2 : gen_ray_fifo
    GENERIC MAP(DATA_WIDTH => FIFO2_WIDTH, DEPTH => FIFO_DEPTH)
    PORT MAP(
        clk => clk, reset => reset, wr_en => fifo2_wr_en, wr_data => fifo2_wr_data,
        full => fifo2_full, rd_en => fifo2_rd_en, rd_data => fifo2_rd_data, empty => fifo2_empty);

    fifo3 : gen_ray_fifo
    GENERIC MAP(DATA_WIDTH => FIFO3_WIDTH, DEPTH => FIFO_DEPTH)
    PORT MAP(
        clk => clk, reset => reset, wr_en => fifo3_wr_en, wr_data => fifo3_wr_data,
        full => fifo3_full, rd_en => fifo3_rd_en, rd_data => fifo3_rd_data, empty => fifo3_empty);

    fifo4 : gen_ray_fifo
    GENERIC MAP(DATA_WIDTH => FIFO4_WIDTH, DEPTH => FIFO_DEPTH)
    PORT MAP(
        clk => clk, reset => reset, wr_en => fifo4_wr_en, wr_data => fifo4_wr_data,
        full => fifo4_full, rd_en => fifo4_rd_en, rd_data => fifo4_rd_data, empty => fifo4_empty);

    -- Input stage: COORD_CALC accepts inputs directly (ready when IDLE and FIFO1 not full)
    ready_out <= '1' WHEN (coord_calc_stage_state = IDLE AND fifo1_full = '0') ELSE
        '0';

    -- Debug process for input stage
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF fifo1_wr_en = '1' THEN
                REPORT "INPUT: Wrote to FIFO1, fifo1_full='" & STD_LOGIC'image(fifo1_full) & "'";
            END IF;
        END IF;
    END PROCESS;

    -- Unpack FIFO outputs
    f1_proScreenX      <= fifo1_rd_data(31 DOWNTO 0);
    f1_proScreenY      <= fifo1_rd_data(63 DOWNTO 32);
    f1_screen_u.x      <= fifo1_rd_data(95 DOWNTO 64);
    f1_screen_u.y      <= fifo1_rd_data(127 DOWNTO 96);
    f1_screen_u.z      <= fifo1_rd_data(159 DOWNTO 128);
    f1_screen_v.x      <= fifo1_rd_data(191 DOWNTO 160);
    f1_screen_v.y      <= fifo1_rd_data(223 DOWNTO 192);
    f1_screen_v.z      <= fifo1_rd_data(255 DOWNTO 224);
    f1_screen_centre.x <= fifo1_rd_data(287 DOWNTO 256);
    f1_screen_centre.y <= fifo1_rd_data(319 DOWNTO 288);
    f1_screen_centre.z <= fifo1_rd_data(351 DOWNTO 320);
    f1_position.x      <= fifo1_rd_data(383 DOWNTO 352);
    f1_position.y      <= fifo1_rd_data(415 DOWNTO 384);
    f1_position.z      <= fifo1_rd_data(447 DOWNTO 416);
    f1_pixel_x         <= TO_INTEGER(SIGNED(fifo1_rd_data(479 DOWNTO 448)));
    f1_pixel_y         <= TO_INTEGER(SIGNED(fifo1_rd_data(511 DOWNTO 480)));

    f2_scale_u.x       <= fifo2_rd_data(31 DOWNTO 0);
    f2_scale_u.y       <= fifo2_rd_data(63 DOWNTO 32);
    f2_scale_u.z       <= fifo2_rd_data(95 DOWNTO 64);
    f2_scale_v.x       <= fifo2_rd_data(127 DOWNTO 96);
    f2_scale_v.y       <= fifo2_rd_data(159 DOWNTO 128);
    f2_scale_v.z       <= fifo2_rd_data(191 DOWNTO 160);
    f2_screen_centre.x <= fifo2_rd_data(223 DOWNTO 192);
    f2_screen_centre.y <= fifo2_rd_data(255 DOWNTO 224);
    f2_screen_centre.z <= fifo2_rd_data(287 DOWNTO 256);
    f2_position.x      <= fifo2_rd_data(319 DOWNTO 288);
    f2_position.y      <= fifo2_rd_data(351 DOWNTO 320);
    f2_position.z      <= fifo2_rd_data(383 DOWNTO 352);
    f2_pixel_x         <= TO_INTEGER(SIGNED(fifo2_rd_data(415 DOWNTO 384)));
    f2_pixel_y         <= TO_INTEGER(SIGNED(fifo2_rd_data(447 DOWNTO 416)));

    f3_add1_result.x   <= fifo3_rd_data(31 DOWNTO 0);
    f3_add1_result.y   <= fifo3_rd_data(63 DOWNTO 32);
    f3_add1_result.z   <= fifo3_rd_data(95 DOWNTO 64);
    f3_scale_v.x       <= fifo3_rd_data(127 DOWNTO 96);
    f3_scale_v.y       <= fifo3_rd_data(159 DOWNTO 128);
    f3_scale_v.z       <= fifo3_rd_data(191 DOWNTO 160);
    f3_position.x      <= fifo3_rd_data(223 DOWNTO 192);
    f3_position.y      <= fifo3_rd_data(255 DOWNTO 224);
    f3_position.z      <= fifo3_rd_data(287 DOWNTO 256);
    f3_pixel_x         <= TO_INTEGER(SIGNED(fifo3_rd_data(319 DOWNTO 288)));
    f3_pixel_y         <= TO_INTEGER(SIGNED(fifo3_rd_data(351 DOWNTO 320)));

    f4_add2_result.x   <= fifo4_rd_data(31 DOWNTO 0);
    f4_add2_result.y   <= fifo4_rd_data(63 DOWNTO 32);
    f4_add2_result.z   <= fifo4_rd_data(95 DOWNTO 64);
    f4_position.x      <= fifo4_rd_data(127 DOWNTO 96);
    f4_position.y      <= fifo4_rd_data(159 DOWNTO 128);
    f4_position.z      <= fifo4_rd_data(191 DOWNTO 160);
    f4_pixel_x         <= TO_INTEGER(SIGNED(fifo4_rd_data(223 DOWNTO 192)));
    f4_pixel_y         <= TO_INTEGER(SIGNED(fifo4_rd_data(255 DOWNTO 224)));

    -- Instantiate vec3 components (IDs 4-8, reserve 0-3 for coord calc)
    scale_u_inst : vec3_scale_hw
    GENERIC MAP(PRODUCER_ID => PRODUCER_ID_BASE + 4)
    PORT MAP(
        clk           => clk,
        reset         => reset,
        valid_in      => scale_u_start,
        v             => scale_stage_screen_u,
        scalar        => scale_stage_proScreenX,
        result        => scale_u_result,
        valid_out     => scale_u_valid,
        mult_requests => scale_u_mult_requests,
        mult_grants   => mult_grants,
        mult_results  => mult_results
    );

    scale_v_inst : vec3_scale_hw
    GENERIC MAP(PRODUCER_ID => PRODUCER_ID_BASE + 5)
    PORT MAP(
        clk => clk, reset => reset, valid_in => scale_v_start,
        v => scale_stage_screen_v, scalar => scale_stage_proScreenY,
        result => scale_v_result, valid_out => scale_v_valid,
        mult_requests => scale_v_mult_requests,
        mult_grants => mult_grants, mult_results => mult_results
    );

    add1_inst : vec3_add_hw
    GENERIC MAP(PRODUCER_ID => PRODUCER_ID_BASE + 6)
    PORT MAP(
        clk => clk, reset => reset, valid_in => add1_start,
        a => add1_stage_screen_centre, b => add1_stage_scale_u,
        result => add1_result, valid_out => add1_valid,
        addsub_requests => add1_addsub_requests,
        addsub_grants => addsub_grants, addsub_results => addsub_results
    );

    add2_inst : vec3_add_hw
    GENERIC MAP(PRODUCER_ID => PRODUCER_ID_BASE + 7)
    PORT MAP(
        clk => clk, reset => reset, valid_in => add2_start,
        a => add2_stage_add1_result, b => add2_stage_scale_v,
        result => add2_result, valid_out => add2_valid,
        addsub_requests => add2_addsub_requests,
        addsub_grants => addsub_grants, addsub_results => addsub_results
    );

    sub_inst : vec3_sub_hw
    GENERIC MAP(PRODUCER_ID => PRODUCER_ID_BASE + 8)
    PORT MAP(
        clk => clk, reset => reset, valid_in => sub_start,
        a => sub_stage_add2_result, b => sub_stage_position,
        result => sub_result, valid_out => sub_valid,
        addsub_requests => sub_addsub_requests,
        addsub_grants => addsub_grants, addsub_results => addsub_results
    );

    -- Combine mult requests (coord calc IDs 0-1, scale IDs 4-5)
    PROCESS (coord_mult_requests, scale_u_mult_requests, scale_v_mult_requests)
    BEGIN
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            mult_requests(i) <= init_producer_mult_request;
        END LOOP;
        -- Coord calc
        mult_requests(PRODUCER_ID_BASE + 0) <= coord_mult_requests(PRODUCER_ID_BASE + 0);
        mult_requests(PRODUCER_ID_BASE + 1) <= coord_mult_requests(PRODUCER_ID_BASE + 1);
        -- Vec3 scale
        mult_requests(PRODUCER_ID_BASE + 4) <= scale_u_mult_requests(PRODUCER_ID_BASE + 4);
        mult_requests(PRODUCER_ID_BASE + 5) <= scale_v_mult_requests(PRODUCER_ID_BASE + 5);
    END PROCESS;

    -- Combine addsub requests (coord calc IDs 2-3, vec3 ops IDs 6-8)
    PROCESS (coord_addsub_requests, add1_addsub_requests, add2_addsub_requests, sub_addsub_requests)
    BEGIN
        FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
            addsub_requests(i) <= init_producer_addsub_request;
        END LOOP;
        -- Coord calc
        addsub_requests(PRODUCER_ID_BASE + 2) <= coord_addsub_requests(PRODUCER_ID_BASE + 2);
        addsub_requests(PRODUCER_ID_BASE + 3) <= coord_addsub_requests(PRODUCER_ID_BASE + 3);
        -- Vec3 ops
        addsub_requests(PRODUCER_ID_BASE + 6) <= add1_addsub_requests(PRODUCER_ID_BASE + 6);
        addsub_requests(PRODUCER_ID_BASE + 7) <= add2_addsub_requests(PRODUCER_ID_BASE + 7);
        addsub_requests(PRODUCER_ID_BASE + 8) <= sub_addsub_requests(PRODUCER_ID_BASE + 8);
    END PROCESS;

    -- COORD_CALC Stage Controller
    PROCESS (clk, reset)
        VARIABLE x_fp, y_fp : fp32;
    BEGIN
        IF reset = '1' THEN
            coord_calc_stage_state <= IDLE;
            mult_x_granted         <= '0';
            mult_y_granted         <= '0';
            mult_x_done            <= '0';
            mult_y_done            <= '0';
            sub_x_granted          <= '0';
            sub_y_granted          <= '0';
            sub_x_done             <= '0';
            sub_y_done             <= '0';
            fifo1_wr_en            <= '0';
            FOR i IN 0 TO NUM_PRODUCERS - 1 LOOP
                coord_mult_requests(i)   <= init_producer_mult_request;
                coord_addsub_requests(i) <= init_producer_addsub_request;
            END LOOP;

        ELSIF rising_edge(clk) THEN
            fifo1_wr_en <= '0';

            CASE coord_calc_stage_state IS
                WHEN IDLE =>
                    IF valid_in = '1' AND fifo1_full = '0' THEN
                        -- Accept inputs directly (no FIFO0)
                        coord_stage_screen_u      <= camera_in.screen_u;
                        coord_stage_screen_v      <= camera_in.screen_v;
                        coord_stage_screen_centre <= camera_in.screen_centre;
                        coord_stage_position      <= camera_in.position;
                        pixel_x_save              <= pixel_x;
                        pixel_y_save              <= pixel_y;
                        mult_x_granted            <= '0';
                        mult_y_granted            <= '0';
                        mult_x_done               <= '0';
                        mult_y_done               <= '0';
                        sub_x_granted             <= '0';
                        sub_y_granted             <= '0';
                        sub_x_done                <= '0';
                        sub_y_done                <= '0';
                        coord_calc_stage_state    <= BUSY;
                    END IF;

                WHEN READ =>
                    -- READ state no longer needed
                    coord_calc_stage_state <= IDLE;

                WHEN BUSY =>
                    -- X multiply
                    IF mult_x_granted = '0' THEN
                        x_fp := int_to_fp32(pixel_x_save);
                        coord_mult_requests(PRODUCER_ID_BASE + 0).valid      <= '1';
                        coord_mult_requests(PRODUCER_ID_BASE + 0).unit_index <= 0;
                        coord_mult_requests(PRODUCER_ID_BASE + 0).data       <= x_fp & x_factor;
                        coord_mult_requests(PRODUCER_ID_BASE + 0).tid        <= make_tid(PRODUCER_ID_BASE + 0, 0);
                        IF mult_grants(PRODUCER_ID_BASE + 0).granted = '1' THEN
                            mult_x_granted                                  <= '1';
                            coord_mult_requests(PRODUCER_ID_BASE + 0).valid <= '0';
                        END IF;
                    ELSE
                        coord_mult_requests(PRODUCER_ID_BASE + 0).valid <= '0';
                    END IF;

                    -- Y multiply
                    IF mult_y_granted = '0' THEN
                        y_fp := int_to_fp32(pixel_y_save);
                        coord_mult_requests(PRODUCER_ID_BASE + 1).valid      <= '1';
                        coord_mult_requests(PRODUCER_ID_BASE + 1).unit_index <= 0;
                        coord_mult_requests(PRODUCER_ID_BASE + 1).data       <= y_fp & y_factor;
                        coord_mult_requests(PRODUCER_ID_BASE + 1).tid        <= make_tid(PRODUCER_ID_BASE + 1, 0);
                        IF mult_grants(PRODUCER_ID_BASE + 1).granted = '1' THEN
                            mult_y_granted                                  <= '1';
                            coord_mult_requests(PRODUCER_ID_BASE + 1).valid <= '0';
                        END IF;
                    ELSE
                        coord_mult_requests(PRODUCER_ID_BASE + 1).valid <= '0';
                    END IF;

                    -- Capture mult results
                    IF mult_results(PRODUCER_ID_BASE + 0).valid = '1' THEN
                        mult_x_result <= mult_results(PRODUCER_ID_BASE + 0).data;
                        mult_x_done   <= '1';
                    END IF;
                    IF mult_results(PRODUCER_ID_BASE + 1).valid = '1' THEN
                        mult_y_result <= mult_results(PRODUCER_ID_BASE + 1).data;
                        mult_y_done   <= '1';
                    END IF;

                    -- X subtract (after mult done)
                    IF mult_x_done = '1' AND sub_x_granted = '0' THEN
                        coord_addsub_requests(PRODUCER_ID_BASE + 2).valid      <= '1';
                        coord_addsub_requests(PRODUCER_ID_BASE + 2).unit_index <= 0;
                        coord_addsub_requests(PRODUCER_ID_BASE + 2).data       <= mult_x_result & X"3F800000" & '1';
                        coord_addsub_requests(PRODUCER_ID_BASE + 2).tid        <= make_tid(PRODUCER_ID_BASE + 2, 0);
                        IF addsub_grants(PRODUCER_ID_BASE + 2).granted = '1' THEN
                            sub_x_granted                                     <= '1';
                            coord_addsub_requests(PRODUCER_ID_BASE + 2).valid <= '0';
                        END IF;
                    ELSE
                        coord_addsub_requests(PRODUCER_ID_BASE + 2).valid <= '0';
                    END IF;

                    -- Y subtract (after mult done)
                    IF mult_y_done = '1' AND sub_y_granted = '0' THEN
                        coord_addsub_requests(PRODUCER_ID_BASE + 3).valid      <= '1';
                        coord_addsub_requests(PRODUCER_ID_BASE + 3).unit_index <= 0;
                        coord_addsub_requests(PRODUCER_ID_BASE + 3).data       <= mult_y_result & X"3F800000" & '1';
                        coord_addsub_requests(PRODUCER_ID_BASE + 3).tid        <= make_tid(PRODUCER_ID_BASE + 3, 0);
                        IF addsub_grants(PRODUCER_ID_BASE + 3).granted = '1' THEN
                            sub_y_granted                                     <= '1';
                            coord_addsub_requests(PRODUCER_ID_BASE + 3).valid <= '0';
                        END IF;
                    ELSE
                        coord_addsub_requests(PRODUCER_ID_BASE + 3).valid <= '0';
                    END IF;

                    -- Capture sub results
                    IF addsub_results(PRODUCER_ID_BASE + 2).valid = '1' THEN
                        proScreenX_calc <= addsub_results(PRODUCER_ID_BASE + 2).data;
                        sub_x_done      <= '1';
                    END IF;
                    IF addsub_results(PRODUCER_ID_BASE + 3).valid = '1' THEN
                        proScreenY_calc <= addsub_results(PRODUCER_ID_BASE + 3).data;
                        sub_y_done      <= '1';
                    END IF;

                    -- Done when both subs complete
                    IF sub_x_done = '1' AND sub_y_done = '1' THEN
                        fifo1_wr_en   <= '1';
                        fifo1_wr_data <= pack_fifo1_data(
                            proScreenX_calc, proScreenY_calc,
                            coord_stage_screen_u, coord_stage_screen_v,
                            coord_stage_screen_centre, coord_stage_position,
                            pixel_x_save, pixel_y_save
                            );
                        coord_calc_stage_state <= IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    -- SCALE Stage Controller
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            scale_state           <= IDLE;
            scale_u_start         <= '0';
            scale_v_start         <= '0';
            fifo1_rd_en           <= '0';
            fifo2_wr_en           <= '0';
            scale_u_valid_latched <= '0';
            scale_v_valid_latched <= '0';

        ELSIF rising_edge(clk) THEN
            scale_u_start <= '0';
            scale_v_start <= '0';
            fifo1_rd_en   <= '0';
            fifo2_wr_en   <= '0';

            -- Latch valid signals
            IF scale_u_valid = '1' THEN
                scale_u_valid_latched <= '1';
            END IF;
            IF scale_v_valid = '1' THEN
                scale_v_valid_latched <= '1';
            END IF;

            CASE scale_state IS
                WHEN IDLE =>
                    IF fifo1_empty = '0' AND fifo2_full = '0' THEN
                        fifo1_rd_en <= '1';
                        scale_state <= READ;
                        REPORT "SCALE: IDLE->READ, fifo1_empty='" & STD_LOGIC'image(fifo1_empty) & "' fifo2_full='" & STD_LOGIC'image(fifo2_full) & "'";
                    END IF;

                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    scale_stage_proScreenX    <= f1_proScreenX;
                    scale_stage_proScreenY    <= f1_proScreenY;
                    scale_stage_screen_u      <= f1_screen_u;
                    scale_stage_screen_v      <= f1_screen_v;
                    scale_stage_screen_centre <= f1_screen_centre;
                    scale_stage_position      <= f1_position;
                    scale_stage_pixel_x       <= f1_pixel_x;
                    scale_stage_pixel_y       <= f1_pixel_y;
                    scale_u_valid_latched     <= '0';
                    scale_v_valid_latched     <= '0';
                    scale_u_start             <= '1';
                    scale_v_start             <= '1';
                    scale_state               <= BUSY;
                    REPORT "SCALE: READ->BUSY, starting scale operations";

                WHEN BUSY =>
                    IF (scale_u_valid_latched = '1' OR scale_u_valid = '1') AND
                        (scale_v_valid_latched = '1' OR scale_v_valid = '1') THEN
                        fifo2_wr_en   <= '1';
                        fifo2_wr_data <= pack_fifo2_data(
                            scale_u_result, scale_v_result,
                            scale_stage_screen_centre, scale_stage_position,
                            scale_stage_pixel_x, scale_stage_pixel_y
                            );
                        scale_state <= IDLE;
                        REPORT "SCALE: BUSY->IDLE, writing to FIFO2";
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    -- ADD1 Stage Controller
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            add1_state  <= IDLE;
            add1_start  <= '0';
            fifo2_rd_en <= '0';
            fifo3_wr_en <= '0';

        ELSIF rising_edge(clk) THEN
            add1_start  <= '0';
            fifo2_rd_en <= '0';
            fifo3_wr_en <= '0';

            CASE add1_state IS
                WHEN IDLE =>
                    IF fifo2_empty = '0' AND fifo3_full = '0' THEN
                        fifo2_rd_en <= '1';
                        add1_state  <= READ;
                        REPORT "ADD1: IDLE->READ";
                    END IF;

                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    add1_stage_screen_centre <= f2_screen_centre;
                    add1_stage_scale_u       <= f2_scale_u;
                    add1_stage_scale_v       <= f2_scale_v;
                    add1_stage_position      <= f2_position;
                    add1_stage_pixel_x       <= f2_pixel_x;
                    add1_stage_pixel_y       <= f2_pixel_y;
                    add1_start               <= '1';
                    add1_state               <= BUSY;

                WHEN BUSY =>
                    IF add1_valid = '1' THEN
                        fifo3_wr_en   <= '1';
                        fifo3_wr_data <= pack_fifo3_data(
                            add1_result, add1_stage_scale_v, add1_stage_position,
                            add1_stage_pixel_x, add1_stage_pixel_y
                            );
                        add1_state <= IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    -- ADD2 Stage Controller
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            add2_state  <= IDLE;
            add2_start  <= '0';
            fifo3_rd_en <= '0';
            fifo4_wr_en <= '0';

        ELSIF rising_edge(clk) THEN
            add2_start  <= '0';
            fifo3_rd_en <= '0';
            fifo4_wr_en <= '0';

            CASE add2_state IS
                WHEN IDLE =>
                    IF fifo3_empty = '0' AND fifo4_full = '0' THEN
                        fifo3_rd_en <= '1';
                        add2_state  <= READ;
                        REPORT "ADD2: IDLE->READ";
                    END IF;

                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    add2_stage_add1_result <= f3_add1_result;
                    add2_stage_scale_v     <= f3_scale_v;
                    add2_stage_position    <= f3_position;
                    add2_stage_pixel_x     <= f3_pixel_x;
                    add2_stage_pixel_y     <= f3_pixel_y;
                    add2_start             <= '1';
                    add2_state             <= BUSY;

                WHEN BUSY =>
                    IF add2_valid = '1' THEN
                        fifo4_wr_en   <= '1';
                        fifo4_wr_data <= pack_fifo4_data(
                            add2_result, add2_stage_position,
                            add2_stage_pixel_x, add2_stage_pixel_y
                            );
                        add2_state <= IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    -- SUB Stage Controller (final stage with output)
    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            sub_state   <= IDLE;
            sub_start   <= '0';
            fifo4_rd_en <= '0';
            valid_out   <= '0';
            ray         <= (VEC3_ZERO, VEC3_ZERO, VEC3_ZERO, 0, 0);

        ELSIF rising_edge(clk) THEN
            sub_start   <= '0';
            fifo4_rd_en <= '0';
            valid_out   <= '0';

            CASE sub_state IS
                WHEN IDLE =>
                    IF fifo4_empty = '0' THEN
                        fifo4_rd_en <= '1';
                        sub_state   <= READ;
                        REPORT "SUB: IDLE->READ";
                    END IF;

                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    sub_stage_position    <= f4_position;
                    sub_stage_add2_result <= f4_add2_result;
                    sub_stage_pixel_x     <= f4_pixel_x;
                    sub_stage_pixel_y     <= f4_pixel_y;
                    sub_start             <= '1';
                    sub_state             <= BUSY;

                WHEN BUSY =>
                    IF sub_valid = '1' THEN
                        ray.point1  <= sub_stage_position;
                        ray.point2  <= sub_stage_add2_result;
                        ray.lab     <= sub_result;
                        ray.pixel_x <= sub_stage_pixel_x;
                        ray.pixel_y <= sub_stage_pixel_y;
                        valid_out   <= '1';
                        sub_state   <= IDLE;
                        REPORT "SUB: BUSY->IDLE, asserting valid_out";
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;