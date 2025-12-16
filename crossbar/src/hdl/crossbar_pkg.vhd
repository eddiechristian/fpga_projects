library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package crossbar_pkg is

    -- System configuration constants
    constant NUM_PRODUCERS      : integer := 10;
    constant NUM_MULT_UNITS     : integer := 10;
    constant NUM_FMA_UNITS      : integer := 5;
    constant NUM_ADDSUB_UNITS   : integer := 3;
    constant TOTAL_FP_UNITS     : integer := NUM_MULT_UNITS + NUM_FMA_UNITS + NUM_ADDSUB_UNITS;
    
    -- Data width constants
    constant FP32_WIDTH         : integer := 32;
    constant TID_WIDTH          : integer := 16;
    constant MULT_DATA_WIDTH    : integer := 64;  -- Two FP32 operands
    constant FMA_DATA_WIDTH     : integer := 96;  -- Three FP32 operands
    constant ADDSUB_DATA_WIDTH  : integer := 65;  -- Two FP32 operands + op bit
    constant MAX_DATA_WIDTH     : integer := 96;  -- Maximum of all data widths
    
    -- TID field definitions
    constant PRODUCER_ID_BITS   : integer := 5;   -- Bits 15:11 encode producer ID (up to 32 producers)
    constant OP_INDEX_BITS      : integer := 11;  -- Bits 10:0 encode operation index (up to 2048 ops)
    
    -- Output FIFO configuration
    constant OUTPUT_FIFO_DEPTH  : integer := 8;
    
    -- FP unit latency (cycles)
    constant FP_LATENCY         : integer := 2;
    
    -- Unit type enumeration
    type unit_type_t is (UNIT_MULT, UNIT_FMA, UNIT_ADDSUB);
    
    -- Producer request records (separate type per unit to avoid MAX_DATA_WIDTH waste)
    type producer_mult_request_t is record
        valid       : std_logic;
        unit_index  : integer range 0 to 15;  -- Which MULT unit
        data        : std_logic_vector(MULT_DATA_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    type producer_fma_request_t is record
        valid       : std_logic;
        unit_index  : integer range 0 to 15;  -- Which FMA unit
        data        : std_logic_vector(FMA_DATA_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    type producer_addsub_request_t is record
        valid       : std_logic;
        unit_index  : integer range 0 to 15;  -- Which ADDSUB unit
        data        : std_logic_vector(ADDSUB_DATA_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    -- Producer grant record
    type producer_grant_t is record
        granted     : std_logic;
        unit_type   : unit_type_t;
        unit_index  : integer range 0 to 15;
    end record;
    
    -- Producer result record
    type producer_result_t is record
        valid       : std_logic;
        data        : std_logic_vector(FP32_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
        ready       : std_logic;  -- Backpressure from producer
    end record;
    
    -- Array types for multiple producers (one array per unit type)
    type producer_mult_request_array_t is array (0 to NUM_PRODUCERS-1) of producer_mult_request_t;
    type producer_fma_request_array_t is array (0 to NUM_PRODUCERS-1) of producer_fma_request_t;
    type producer_addsub_request_array_t is array (0 to NUM_PRODUCERS-1) of producer_addsub_request_t;
    type producer_grant_array_t is array (0 to NUM_PRODUCERS-1) of producer_grant_t;
    type producer_result_array_t is array (0 to NUM_PRODUCERS-1) of producer_result_t;
    
    -- Request matrix: request(producer)(fp_unit)
    type request_matrix_mult_t is array (0 to NUM_PRODUCERS-1, 0 to NUM_MULT_UNITS-1) of std_logic;
    type request_matrix_fma_t is array (0 to NUM_PRODUCERS-1, 0 to NUM_FMA_UNITS-1) of std_logic;
    type request_matrix_addsub_t is array (0 to NUM_PRODUCERS-1, 0 to NUM_ADDSUB_UNITS-1) of std_logic;
    
    -- Grant vector: which producer (if any) granted to each FP unit
    -- -1 = no grant (unit idle), 0 to N-1 = producer index
    type grant_vector_mult_t is array (0 to NUM_MULT_UNITS-1) of integer range -1 to NUM_PRODUCERS-1;
    type grant_vector_fma_t is array (0 to NUM_FMA_UNITS-1) of integer range -1 to NUM_PRODUCERS-1;
    type grant_vector_addsub_t is array (0 to NUM_ADDSUB_UNITS-1) of integer range -1 to NUM_PRODUCERS-1;
    
    -- FP unit interface types (separate types per unit to match data widths)
    type fp_mult_input_t is record
        valid       : std_logic;
        data        : std_logic_vector(MULT_DATA_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    type fp_fma_input_t is record
        valid       : std_logic;
        data        : std_logic_vector(FMA_DATA_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    type fp_addsub_input_t is record
        valid       : std_logic;
        data        : std_logic_vector(ADDSUB_DATA_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    type fp_unit_output_t is record
        valid       : std_logic;
        data        : std_logic_vector(FP32_WIDTH-1 downto 0);
        tid         : std_logic_vector(TID_WIDTH-1 downto 0);
    end record;
    
    -- Arrays for FP unit interfaces
    type fp_mult_input_array_t is array (0 to NUM_MULT_UNITS-1) of fp_mult_input_t;
    type fp_mult_output_array_t is array (0 to NUM_MULT_UNITS-1) of fp_unit_output_t;
    type fp_fma_input_array_t is array (0 to NUM_FMA_UNITS-1) of fp_fma_input_t;
    type fp_fma_output_array_t is array (0 to NUM_FMA_UNITS-1) of fp_unit_output_t;
    type fp_addsub_input_array_t is array (0 to NUM_ADDSUB_UNITS-1) of fp_addsub_input_t;
    type fp_addsub_output_array_t is array (0 to NUM_ADDSUB_UNITS-1) of fp_unit_output_t;
    
    -- Utility functions
    
    -- Extract producer ID from TID
    function get_producer_id(tid : std_logic_vector(TID_WIDTH-1 downto 0)) return integer;
    
    -- Create TID from producer ID and operation index
    function make_tid(producer_id : integer; op_index : integer) return std_logic_vector;
    
    -- Initialize producer requests to idle state
    function init_producer_mult_request return producer_mult_request_t;
    function init_producer_fma_request return producer_fma_request_t;
    function init_producer_addsub_request return producer_addsub_request_t;
    
    -- Initialize producer grant to no grant
    function init_producer_grant return producer_grant_t;
    
    -- Initialize producer result to invalid
    function init_producer_result return producer_result_t;

end package crossbar_pkg;

package body crossbar_pkg is

    -- Extract producer ID from TID bits [15:11]
    function get_producer_id(tid : std_logic_vector(TID_WIDTH-1 downto 0)) return integer is
    begin
        return to_integer(unsigned(tid(15 downto 11)));
    end function;
    
    -- Create TID from producer ID and operation index
    function make_tid(producer_id : integer; op_index : integer) return std_logic_vector is
        variable tid : std_logic_vector(TID_WIDTH-1 downto 0);
    begin
        tid(15 downto 11) := std_logic_vector(to_unsigned(producer_id, PRODUCER_ID_BITS));
        tid(10 downto 0) := std_logic_vector(to_unsigned(op_index, OP_INDEX_BITS));
        return tid;
    end function;
    
    -- Initialize producer MULT request to idle state
    function init_producer_mult_request return producer_mult_request_t is
        variable req : producer_mult_request_t;
    begin
        req.valid := '0';
        req.unit_index := 0;
        req.data := (others => '0');
        req.tid := (others => '0');
        return req;
    end function;
    
    -- Initialize producer FMA request to idle state
    function init_producer_fma_request return producer_fma_request_t is
        variable req : producer_fma_request_t;
    begin
        req.valid := '0';
        req.unit_index := 0;
        req.data := (others => '0');
        req.tid := (others => '0');
        return req;
    end function;
    
    -- Initialize producer ADDSUB request to idle state
    function init_producer_addsub_request return producer_addsub_request_t is
        variable req : producer_addsub_request_t;
    begin
        req.valid := '0';
        req.unit_index := 0;
        req.data := (others => '0');
        req.tid := (others => '0');
        return req;
    end function;
    
    -- Initialize producer grant to no grant
    function init_producer_grant return producer_grant_t is
        variable grant : producer_grant_t;
    begin
        grant.granted := '0';
        grant.unit_type := UNIT_MULT;
        grant.unit_index := 0;
        return grant;
    end function;
    
    -- Initialize producer result to invalid
    function init_producer_result return producer_result_t is
        variable result : producer_result_t;
    begin
        result.valid := '0';
        result.data := (others => '0');
        result.tid := (others => '0');
        result.ready := '1';  -- Default to ready
        return result;
    end function;

end package body crossbar_pkg;
