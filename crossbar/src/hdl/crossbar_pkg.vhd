LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;

PACKAGE crossbar_pkg IS

    -- System configuration constants
    CONSTANT NUM_PRODUCERS     : INTEGER := 10;
    CONSTANT NUM_MULT_UNITS    : INTEGER := 10;
    CONSTANT NUM_FMA_UNITS     : INTEGER := 5;
    CONSTANT NUM_ADDSUB_UNITS  : INTEGER := 3;
    CONSTANT NUM_DOT_UNITS     : INTEGER := 10;  -- Vec3 dot product units
    CONSTANT NUM_DOT4_UNITS    : INTEGER := 10;  -- Vec4 dot product units
    CONSTANT TOTAL_FP_UNITS    : INTEGER := NUM_DOT_UNITS + NUM_DOT4_UNITS + NUM_MULT_UNITS + NUM_FMA_UNITS + NUM_ADDSUB_UNITS;

    -- Data width constants
    CONSTANT FP32_WIDTH        : INTEGER := 32;
    CONSTANT TID_WIDTH         : INTEGER := 16;
    CONSTANT MULT_DATA_WIDTH   : INTEGER := 64;  -- Two FP32 operands
    CONSTANT FMA_DATA_WIDTH    : INTEGER := 96;  -- Three FP32 operands
    CONSTANT ADDSUB_DATA_WIDTH : INTEGER := 65;  -- Two FP32 operands + op bit
    CONSTANT DOT_PRODUCT_WIDTH : INTEGER := 192; -- 3 Vec3  (6 x 32 bit)
    CONSTANT MAX_DATA_WIDTH    : INTEGER := 192; -- Maximum of all data widths

    -- TID field definitions
    CONSTANT PRODUCER_ID_BITS  : INTEGER := 5;   -- Bits 15:11 encode producer ID (up to 32 producers)
    CONSTANT OP_INDEX_BITS     : INTEGER := 11;  -- Bits 10:0 encode operation index (up to 2048 ops)

    -- Output FIFO configuration
    CONSTANT OUTPUT_FIFO_DEPTH : INTEGER := 8;

    -- FP unit latency (cycles)
    CONSTANT FP_LATENCY        : INTEGER := 2;

    -- Unit type enumeration
    TYPE unit_type_t IS (UNIT_MULT, UNIT_FMA, UNIT_ADDSUB, UNIT_DOT, UNIT_DOT4);

    -- Producer request records (separate type per unit to avoid MAX_DATA_WIDTH waste)
    TYPE producer_mult_request_t IS RECORD
        valid      : STD_LOGIC;
        unit_index : INTEGER RANGE 0 TO 15; -- Which MULT unit
        data       : STD_LOGIC_VECTOR(MULT_DATA_WIDTH - 1 DOWNTO 0);
        tid        : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE producer_fma_request_t IS RECORD
        valid      : STD_LOGIC;
        unit_index : INTEGER RANGE 0 TO 15; -- Which FMA unit
        data       : STD_LOGIC_VECTOR(FMA_DATA_WIDTH - 1 DOWNTO 0);
        tid        : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE producer_addsub_request_t IS RECORD
        valid      : STD_LOGIC;
        unit_index : INTEGER RANGE 0 TO 15; -- Which ADDSUB unit
        data       : STD_LOGIC_VECTOR(ADDSUB_DATA_WIDTH - 1 DOWNTO 0);
        tid        : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE producer_dot_request_t IS RECORD
        valid      : STD_LOGIC;
        unit_index : INTEGER RANGE 0 TO 15; -- Which DOT unit
        a          : Vec3;
        b          : Vec3;
        tid        : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE producer_dot4_request_t IS RECORD
        valid      : STD_LOGIC;
        unit_index : INTEGER RANGE 0 TO 15; -- Which DOT4 unit
        a          : Vec4;
        b          : Vec4;
        tid        : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    -- Producer grant record
    TYPE producer_grant_t IS RECORD
        granted    : STD_LOGIC;
        unit_type  : unit_type_t;
        unit_index : INTEGER RANGE 0 TO 15;
    END RECORD;

    -- Producer result record
    TYPE producer_result_t IS RECORD
        valid : STD_LOGIC;
        data  : STD_LOGIC_VECTOR(FP32_WIDTH - 1 DOWNTO 0);
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
        ready : STD_LOGIC; -- Backpressure from producer
    END RECORD;

    -- Array types for multiple producers (one array per unit type)
    TYPE producer_dot_request_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_dot_request_t;
    TYPE producer_dot4_request_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_dot4_request_t;
    TYPE producer_mult_request_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_mult_request_t;
    TYPE producer_fma_request_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_fma_request_t;
    TYPE producer_addsub_request_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_addsub_request_t;

    TYPE producer_grant_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_grant_t;
    TYPE producer_result_array_t IS ARRAY (0 TO NUM_PRODUCERS - 1) OF producer_result_t;

    -- Request matrix: request(producer)(fp_unit)
    TYPE request_matrix_dot_t IS ARRAY (0 TO NUM_PRODUCERS - 1, 0 TO NUM_DOT_UNITS - 1) OF STD_LOGIC;
    TYPE request_matrix_dot4_t IS ARRAY (0 TO NUM_PRODUCERS - 1, 0 TO NUM_DOT4_UNITS - 1) OF STD_LOGIC;
    TYPE request_matrix_mult_t IS ARRAY (0 TO NUM_PRODUCERS - 1, 0 TO NUM_MULT_UNITS - 1) OF STD_LOGIC;
    TYPE request_matrix_fma_t IS ARRAY (0 TO NUM_PRODUCERS - 1, 0 TO NUM_FMA_UNITS - 1) OF STD_LOGIC;
    TYPE request_matrix_addsub_t IS ARRAY (0 TO NUM_PRODUCERS - 1, 0 TO NUM_ADDSUB_UNITS - 1) OF STD_LOGIC;

    -- Grant vector: which producer (if any) granted to each FP unit
    -- -1 = no grant (unit idle), 0 to N-1 = producer index
    TYPE grant_vector_dot_t IS ARRAY (0 TO NUM_DOT_UNITS - 1) OF INTEGER RANGE -1 TO NUM_PRODUCERS - 1;
    TYPE grant_vector_dot4_t IS ARRAY (0 TO NUM_DOT4_UNITS - 1) OF INTEGER RANGE -1 TO NUM_PRODUCERS - 1;
    TYPE grant_vector_mult_t IS ARRAY (0 TO NUM_MULT_UNITS - 1) OF INTEGER RANGE -1 TO NUM_PRODUCERS - 1;
    TYPE grant_vector_fma_t IS ARRAY (0 TO NUM_FMA_UNITS - 1) OF INTEGER RANGE -1 TO NUM_PRODUCERS - 1;
    TYPE grant_vector_addsub_t IS ARRAY (0 TO NUM_ADDSUB_UNITS - 1) OF INTEGER RANGE -1 TO NUM_PRODUCERS - 1;

    -- FP unit interface types (separate types per unit to match data widths)
    TYPE fp_dot_input_t IS RECORD
        valid : STD_LOGIC;
        a     : Vec3;
        b     : Vec3;
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE fp_dot4_input_t IS RECORD
        valid : STD_LOGIC;
        a     : Vec4;
        b     : Vec4;
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE fp_mult_input_t IS RECORD
        valid : STD_LOGIC;
        data  : STD_LOGIC_VECTOR(MULT_DATA_WIDTH - 1 DOWNTO 0);
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE fp_fma_input_t IS RECORD
        valid : STD_LOGIC;
        data  : STD_LOGIC_VECTOR(FMA_DATA_WIDTH - 1 DOWNTO 0);
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE fp_addsub_input_t IS RECORD
        valid : STD_LOGIC;
        data  : STD_LOGIC_VECTOR(ADDSUB_DATA_WIDTH - 1 DOWNTO 0);
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    TYPE fp_unit_output_t IS RECORD
        valid : STD_LOGIC;
        data  : STD_LOGIC_VECTOR(FP32_WIDTH - 1 DOWNTO 0);
        tid   : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    END RECORD;

    -- Arrays for FP unit interfaces

    TYPE fp_dot_input_array_t IS ARRAY (0 TO NUM_DOT_UNITS - 1) OF fp_dot_input_t;
    TYPE fp_dot_output_array_t IS ARRAY (0 TO NUM_DOT_UNITS - 1) OF fp_unit_output_t;

    TYPE fp_dot4_input_array_t IS ARRAY (0 TO NUM_DOT4_UNITS - 1) OF fp_dot4_input_t;
    TYPE fp_dot4_output_array_t IS ARRAY (0 TO NUM_DOT4_UNITS - 1) OF fp_unit_output_t;

    TYPE fp_mult_input_array_t IS ARRAY (0 TO NUM_MULT_UNITS - 1) OF fp_mult_input_t;
    TYPE fp_mult_output_array_t IS ARRAY (0 TO NUM_MULT_UNITS - 1) OF fp_unit_output_t;

    TYPE fp_fma_input_array_t IS ARRAY (0 TO NUM_FMA_UNITS - 1) OF fp_fma_input_t;
    TYPE fp_fma_output_array_t IS ARRAY (0 TO NUM_FMA_UNITS - 1) OF fp_unit_output_t;

    TYPE fp_addsub_input_array_t IS ARRAY (0 TO NUM_ADDSUB_UNITS - 1) OF fp_addsub_input_t;
    TYPE fp_addsub_output_array_t IS ARRAY (0 TO NUM_ADDSUB_UNITS - 1) OF fp_unit_output_t;

    -- Utility functions

    -- Extract producer ID from TID
    FUNCTION get_producer_id(tid : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0)) RETURN INTEGER;

    -- Create TID from producer ID and operation index
    FUNCTION make_tid(producer_id : INTEGER; op_index : INTEGER) RETURN STD_LOGIC_VECTOR;

    -- Initialize producer requests to idle state
    FUNCTION init_producer_dot_request RETURN producer_dot_request_t;
    FUNCTION init_producer_dot4_request RETURN producer_dot4_request_t;
    FUNCTION init_producer_mult_request RETURN producer_mult_request_t;
    FUNCTION init_producer_fma_request RETURN producer_fma_request_t;
    FUNCTION init_producer_addsub_request RETURN producer_addsub_request_t;

    -- Initialize producer grant to no grant
    FUNCTION init_producer_grant RETURN producer_grant_t;

    -- Initialize producer result to invalid
    FUNCTION init_producer_result RETURN producer_result_t;

END PACKAGE crossbar_pkg;

PACKAGE BODY crossbar_pkg IS

    -- Extract producer ID from TID bits [15:11]
    FUNCTION get_producer_id(tid : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0)) RETURN INTEGER IS
    BEGIN
        RETURN to_integer(unsigned(tid(15 DOWNTO 11)));
    END FUNCTION;

    -- Create TID from producer ID and operation index
    FUNCTION make_tid(producer_id : INTEGER; op_index : INTEGER) RETURN STD_LOGIC_VECTOR IS
        VARIABLE tid : STD_LOGIC_VECTOR(TID_WIDTH - 1 DOWNTO 0);
    BEGIN
        tid(15 DOWNTO 11) := STD_LOGIC_VECTOR(to_unsigned(producer_id, PRODUCER_ID_BITS));
        tid(10 DOWNTO 0)  := STD_LOGIC_VECTOR(to_unsigned(op_index, OP_INDEX_BITS));
        RETURN tid;
    END FUNCTION;

    -- Initialize producer DOT request to idle state
    FUNCTION init_producer_dot_request RETURN producer_dot_request_t IS
        VARIABLE req : producer_dot_request_t;
    BEGIN
        req.valid      := '0';
        req.unit_index := 0;
        req.a.x        := (OTHERS => '0');
        req.a.y        := (OTHERS => '0');
        req.a.z        := (OTHERS => '0');
        req.b.x        := (OTHERS => '0');
        req.b.y        := (OTHERS => '0');
        req.b.z        := (OTHERS => '0');
        req.tid        := (OTHERS => '0');
        RETURN req;
    END FUNCTION;

    -- Initialize producer DOT4 request to idle state
    FUNCTION init_producer_dot4_request RETURN producer_dot4_request_t IS
        VARIABLE req : producer_dot4_request_t;
    BEGIN
        req.valid      := '0';
        req.unit_index := 0;
        req.a.x        := (OTHERS => '0');
        req.a.y        := (OTHERS => '0');
        req.a.z        := (OTHERS => '0');
        req.a.w        := (OTHERS => '0');
        req.b.x        := (OTHERS => '0');
        req.b.y        := (OTHERS => '0');
        req.b.z        := (OTHERS => '0');
        req.b.w        := (OTHERS => '0');
        req.tid        := (OTHERS => '0');
        RETURN req;
    END FUNCTION;

    -- Initialize producer MULT request to idle state
    FUNCTION init_producer_mult_request RETURN producer_mult_request_t IS
        VARIABLE req : producer_mult_request_t;
    BEGIN
        req.valid      := '0';
        req.unit_index := 0;
        req.data       := (OTHERS => '0');
        req.tid        := (OTHERS => '0');
        RETURN req;
    END FUNCTION;

    -- Initialize producer FMA request to idle state
    FUNCTION init_producer_fma_request RETURN producer_fma_request_t IS
        VARIABLE req : producer_fma_request_t;
    BEGIN
        req.valid      := '0';
        req.unit_index := 0;
        req.data       := (OTHERS => '0');
        req.tid        := (OTHERS => '0');
        RETURN req;
    END FUNCTION;

    -- Initialize producer ADDSUB request to idle state
    FUNCTION init_producer_addsub_request RETURN producer_addsub_request_t IS
        VARIABLE req : producer_addsub_request_t;
    BEGIN
        req.valid      := '0';
        req.unit_index := 0;
        req.data       := (OTHERS => '0');
        req.tid        := (OTHERS => '0');
        RETURN req;
    END FUNCTION;

    -- Initialize producer grant to no grant
    FUNCTION init_producer_grant RETURN producer_grant_t IS
        VARIABLE grant : producer_grant_t;
    BEGIN
        grant.granted    := '0';
        grant.unit_type  := UNIT_MULT;
        grant.unit_index := 0;
        RETURN grant;
    END FUNCTION;

    -- Initialize producer result to invalid
    FUNCTION init_producer_result RETURN producer_result_t IS
        VARIABLE result : producer_result_t;
    BEGIN
        result.valid := '0';
        result.data  := (OTHERS => '0');
        result.tid   := (OTHERS => '0');
        result.ready := '1'; -- Default to ready
        RETURN result;
    END FUNCTION;

END PACKAGE BODY crossbar_pkg;