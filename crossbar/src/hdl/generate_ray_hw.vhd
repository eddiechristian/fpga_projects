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
-- Producer allocation (same as before):
--   ID 0: scale_u
--   ID 1: scale_v
--   ID 2: add1
--   ID 3: add2
--   ID 4: sub

ENTITY generate_ray IS
    GENERIC (
        PRODUCER_ID_BASE : integer range 0 to 25 := 0;  -- Needs 5 consecutive IDs
        FIFO_DEPTH       : integer := 32                 -- Inter-stage buffer depth
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        proScreenX             : IN fp32;
        proScreenY             : IN fp32;
        valid_in               : IN STD_LOGIC;
        camera_in              : IN  Camera;
        ready_out              : OUT STD_LOGIC;  -- Can accept new input

        ray                    : OUT Ray;
        valid_out              : OUT STD_LOGIC;
        
        -- Crossbar interfaces
        mult_requests   : OUT producer_mult_request_array_t;
        mult_grants     : IN  producer_grant_array_t;
        mult_results    : IN  producer_result_array_t;
        
        addsub_requests : OUT producer_addsub_request_array_t;
        addsub_grants   : IN  producer_grant_array_t;
        addsub_results  : IN  producer_result_array_t
    );
END ENTITY generate_ray;

ARCHITECTURE behavioral OF generate_ray IS
    
    -- FIFO data widths
    -- FIFO1: 2*fp32 + 4*Vec3 = 64 + 384 = 448 bits
    -- FIFO2: 4*Vec3 = 384 bits
    -- FIFO3: 3*Vec3 = 288 bits
    -- FIFO4: 2*Vec3 = 192 bits
    CONSTANT FIFO1_WIDTH : integer := 448;
    CONSTANT FIFO2_WIDTH : integer := 384;
    CONSTANT FIFO3_WIDTH : integer := 288;
    CONSTANT FIFO4_WIDTH : integer := 192;
    
    -- Component declarations
    COMPONENT gen_ray_fifo IS
        GENERIC (
            DATA_WIDTH : integer := 32;
            DEPTH      : integer := 4
        );
        PORT (
            clk      : IN  std_logic;
            reset    : IN  std_logic;
            wr_en    : IN  std_logic;
            wr_data  : IN  std_logic_vector(DATA_WIDTH-1 downto 0);
            full     : OUT std_logic;
            rd_en    : IN  std_logic;
            rd_data  : OUT std_logic_vector(DATA_WIDTH-1 downto 0);
            empty    : OUT std_logic
        );
    END COMPONENT;
    
    COMPONENT vec3_scale_hw IS
        GENERIC (
            PRODUCER_ID : integer range 0 to 31 := 0
        );
        PORT (
            clk       : IN  std_logic;
            reset     : IN  std_logic;
            valid_in  : IN  std_logic;
            v         : IN  Vec3;
            scalar    : IN  fp32;
            result    : OUT Vec3;
            valid_out : OUT std_logic;
            mult_requests : OUT producer_mult_request_array_t;
            mult_grants   : IN  producer_grant_array_t;
            mult_results  : IN  producer_result_array_t
        );
    END COMPONENT;
    
    COMPONENT vec3_add_hw IS
        GENERIC (
            PRODUCER_ID : integer range 0 to 31 := 0
        );
        PORT (
            clk       : IN  std_logic;
            reset     : IN  std_logic;
            valid_in  : IN  std_logic;
            a         : IN  Vec3;
            b         : IN  Vec3;
            result    : OUT Vec3;
            valid_out : OUT std_logic;
            addsub_requests : OUT producer_addsub_request_array_t;
            addsub_grants   : IN  producer_grant_array_t;
            addsub_results  : IN  producer_result_array_t
        );
    END COMPONENT;
    
    COMPONENT vec3_sub_hw IS
        GENERIC (
            PRODUCER_ID : integer range 0 to 31 := 0
        );
        PORT (
            clk       : IN  std_logic;
            reset     : IN  std_logic;
            valid_in  : IN  std_logic;
            a         : IN  Vec3;
            b         : IN  Vec3;
            result    : OUT Vec3;
            valid_out : OUT std_logic;
            addsub_requests : OUT producer_addsub_request_array_t;
            addsub_grants   : IN  producer_grant_array_t;
            addsub_results  : IN  producer_result_array_t
        );
    END COMPONENT;
    
    -- Stage state machines
    TYPE stage_state_t IS (IDLE, READ, BUSY);
    SIGNAL scale_state : stage_state_t := IDLE;
    SIGNAL add1_state  : stage_state_t := IDLE;
    SIGNAL add2_state  : stage_state_t := IDLE;
    SIGNAL sub_state   : stage_state_t := IDLE;
    
    -- FIFO1 signals (Input → SCALE)
    SIGNAL fifo1_wr_en   : STD_LOGIC := '0';
    SIGNAL fifo1_wr_data : STD_LOGIC_VECTOR(FIFO1_WIDTH-1 downto 0);
    SIGNAL fifo1_full    : STD_LOGIC;
    SIGNAL fifo1_rd_en   : STD_LOGIC := '0';
    SIGNAL fifo1_rd_data : STD_LOGIC_VECTOR(FIFO1_WIDTH-1 downto 0);
    SIGNAL fifo1_empty   : STD_LOGIC;
    
    -- FIFO2 signals (SCALE → ADD1)
    SIGNAL fifo2_wr_en   : STD_LOGIC := '0';
    SIGNAL fifo2_wr_data : STD_LOGIC_VECTOR(FIFO2_WIDTH-1 downto 0);
    SIGNAL fifo2_full    : STD_LOGIC;
    SIGNAL fifo2_rd_en   : STD_LOGIC := '0';
    SIGNAL fifo2_rd_data : STD_LOGIC_VECTOR(FIFO2_WIDTH-1 downto 0);
    SIGNAL fifo2_empty   : STD_LOGIC;
    
    -- FIFO3 signals (ADD1 → ADD2)
    SIGNAL fifo3_wr_en   : STD_LOGIC := '0';
    SIGNAL fifo3_wr_data : STD_LOGIC_VECTOR(FIFO3_WIDTH-1 downto 0);
    SIGNAL fifo3_full    : STD_LOGIC;
    SIGNAL fifo3_rd_en   : STD_LOGIC := '0';
    SIGNAL fifo3_rd_data : STD_LOGIC_VECTOR(FIFO3_WIDTH-1 downto 0);
    SIGNAL fifo3_empty   : STD_LOGIC;
    
    -- FIFO4 signals (ADD2 → SUB)
    SIGNAL fifo4_wr_en   : STD_LOGIC := '0';
    SIGNAL fifo4_wr_data : STD_LOGIC_VECTOR(FIFO4_WIDTH-1 downto 0);
    SIGNAL fifo4_full    : STD_LOGIC;
    SIGNAL fifo4_rd_en   : STD_LOGIC := '0';
    SIGNAL fifo4_rd_data : STD_LOGIC_VECTOR(FIFO4_WIDTH-1 downto 0);
    SIGNAL fifo4_empty   : STD_LOGIC;
    
    -- Unpacked FIFO1 data
    SIGNAL f1_proScreenX      : fp32;
    SIGNAL f1_proScreenY      : fp32;
    SIGNAL f1_screen_u        : Vec3;
    SIGNAL f1_screen_v        : Vec3;
    SIGNAL f1_screen_centre   : Vec3;
    SIGNAL f1_position        : Vec3;
    
    -- Unpacked FIFO2 data
    SIGNAL f2_scale_u         : Vec3;
    SIGNAL f2_scale_v         : Vec3;
    SIGNAL f2_screen_centre   : Vec3;
    SIGNAL f2_position        : Vec3;
    
    -- Unpacked FIFO3 data
    SIGNAL f3_add1_result     : Vec3;
    SIGNAL f3_scale_v         : Vec3;
    SIGNAL f3_position        : Vec3;
    
    -- Unpacked FIFO4 data
    SIGNAL f4_add2_result     : Vec3;
    SIGNAL f4_position        : Vec3;
    
    -- Vec3 operation signals
    SIGNAL scale_u_result, scale_v_result : Vec3 := VEC3_ZERO;
    SIGNAL add1_result, add2_result       : Vec3 := VEC3_ZERO;
    SIGNAL sub_result                     : Vec3 := VEC3_ZERO;
    
    SIGNAL scale_u_valid, scale_v_valid : STD_LOGIC := '0';
    SIGNAL add1_valid, add2_valid       : STD_LOGIC := '0';
    SIGNAL sub_valid                    : STD_LOGIC := '0';
    
    SIGNAL scale_u_start, scale_v_start : STD_LOGIC := '0';
    SIGNAL add1_start, add2_start       : STD_LOGIC := '0';
    SIGNAL sub_start                    : STD_LOGIC := '0';
    
    -- Valid latches for scale stage (both must complete)
    SIGNAL scale_u_valid_latched : STD_LOGIC := '0';
    SIGNAL scale_v_valid_latched : STD_LOGIC := '0';
    
    -- Temporary storage for scale stage
    SIGNAL scale_stage_proScreenX    : fp32 := (others => '0');
    SIGNAL scale_stage_proScreenY    : fp32 := (others => '0');
    SIGNAL scale_stage_screen_u      : Vec3 := VEC3_ZERO;
    SIGNAL scale_stage_screen_v      : Vec3 := VEC3_ZERO;
    SIGNAL scale_stage_screen_centre : Vec3 := VEC3_ZERO;
    SIGNAL scale_stage_position      : Vec3 := VEC3_ZERO;
    
    -- Staging registers for ADD1/ADD2/SUB stages
    SIGNAL add1_stage_screen_centre  : Vec3 := VEC3_ZERO;
    SIGNAL add1_stage_scale_u        : Vec3 := VEC3_ZERO;
    SIGNAL add1_stage_scale_v        : Vec3 := VEC3_ZERO;
    SIGNAL add1_stage_position       : Vec3 := VEC3_ZERO;
    SIGNAL add2_stage_add1_result    : Vec3 := VEC3_ZERO;
    SIGNAL add2_stage_scale_v        : Vec3 := VEC3_ZERO;
    SIGNAL add2_stage_position       : Vec3 := VEC3_ZERO;
    SIGNAL sub_stage_position        : Vec3 := VEC3_ZERO;
    SIGNAL sub_stage_add2_result     : Vec3 := VEC3_ZERO;
    
    -- Request arrays for each component
    SIGNAL scale_u_mult_requests, scale_v_mult_requests : producer_mult_request_array_t := (OTHERS => init_producer_mult_request);
    SIGNAL add1_addsub_requests, add2_addsub_requests, sub_addsub_requests : producer_addsub_request_array_t := (OTHERS => init_producer_addsub_request);

    -- Helper function to pack FIFO1 data
    FUNCTION pack_fifo1_data(
        screenX, screenY : fp32;
        screen_u, screen_v, screen_centre, position : Vec3
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO1_WIDTH-1 downto 0);
    BEGIN
        result(31 downto 0)     := screenX;
        result(63 downto 32)    := screenY;
        result(95 downto 64)    := screen_u.x;
        result(127 downto 96)   := screen_u.y;
        result(159 downto 128)  := screen_u.z;
        result(191 downto 160)  := screen_v.x;
        result(223 downto 192)  := screen_v.y;
        result(255 downto 224)  := screen_v.z;
        result(287 downto 256)  := screen_centre.x;
        result(319 downto 288)  := screen_centre.y;
        result(351 downto 320)  := screen_centre.z;
        result(383 downto 352)  := position.x;
        result(415 downto 384)  := position.y;
        result(447 downto 416)  := position.z;
        RETURN result;
    END FUNCTION;
    
    -- Helper function to pack FIFO2 data
    FUNCTION pack_fifo2_data(
        scale_u, scale_v, screen_centre, position : Vec3
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO2_WIDTH-1 downto 0);
    BEGIN
        result(31 downto 0)     := scale_u.x;
        result(63 downto 32)    := scale_u.y;
        result(95 downto 64)    := scale_u.z;
        result(127 downto 96)   := scale_v.x;
        result(159 downto 128)  := scale_v.y;
        result(191 downto 160)  := scale_v.z;
        result(223 downto 192)  := screen_centre.x;
        result(255 downto 224)  := screen_centre.y;
        result(287 downto 256)  := screen_centre.z;
        result(319 downto 288)  := position.x;
        result(351 downto 320)  := position.y;
        result(383 downto 352)  := position.z;
        RETURN result;
    END FUNCTION;
    
    -- Helper function to pack FIFO3 data
    FUNCTION pack_fifo3_data(
        add1_result, scale_v, position : Vec3
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO3_WIDTH-1 downto 0);
    BEGIN
        result(31 downto 0)     := add1_result.x;
        result(63 downto 32)    := add1_result.y;
        result(95 downto 64)    := add1_result.z;
        result(127 downto 96)   := scale_v.x;
        result(159 downto 128)  := scale_v.y;
        result(191 downto 160)  := scale_v.z;
        result(223 downto 192)  := position.x;
        result(255 downto 224)  := position.y;
        result(287 downto 256)  := position.z;
        RETURN result;
    END FUNCTION;
    
    -- Helper function to pack FIFO4 data
    FUNCTION pack_fifo4_data(
        add2_result, position : Vec3
    ) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(FIFO4_WIDTH-1 downto 0);
    BEGIN
        result(31 downto 0)     := add2_result.x;
        result(63 downto 32)    := add2_result.y;
        result(95 downto 64)    := add2_result.z;
        result(127 downto 96)   := position.x;
        result(159 downto 128)  := position.y;
        result(191 downto 160)  := position.z;
        RETURN result;
    END FUNCTION;

BEGIN
    
    -- Instantiate FIFOs
    fifo1 : gen_ray_fifo
        GENERIC MAP (DATA_WIDTH => FIFO1_WIDTH, DEPTH => FIFO_DEPTH)
        PORT MAP (clk => clk, reset => reset, wr_en => fifo1_wr_en, wr_data => fifo1_wr_data,
                  full => fifo1_full, rd_en => fifo1_rd_en, rd_data => fifo1_rd_data, empty => fifo1_empty);
    
    fifo2 : gen_ray_fifo
        GENERIC MAP (DATA_WIDTH => FIFO2_WIDTH, DEPTH => FIFO_DEPTH)
        PORT MAP (clk => clk, reset => reset, wr_en => fifo2_wr_en, wr_data => fifo2_wr_data,
                  full => fifo2_full, rd_en => fifo2_rd_en, rd_data => fifo2_rd_data, empty => fifo2_empty);
    
    fifo3 : gen_ray_fifo
        GENERIC MAP (DATA_WIDTH => FIFO3_WIDTH, DEPTH => FIFO_DEPTH)
        PORT MAP (clk => clk, reset => reset, wr_en => fifo3_wr_en, wr_data => fifo3_wr_data,
                  full => fifo3_full, rd_en => fifo3_rd_en, rd_data => fifo3_rd_data, empty => fifo3_empty);
    
    fifo4 : gen_ray_fifo
        GENERIC MAP (DATA_WIDTH => FIFO4_WIDTH, DEPTH => FIFO_DEPTH)
        PORT MAP (clk => clk, reset => reset, wr_en => fifo4_wr_en, wr_data => fifo4_wr_data,
                  full => fifo4_full, rd_en => fifo4_rd_en, rd_data => fifo4_rd_data, empty => fifo4_empty);
    
    -- Input stage: Accept inputs when FIFO1 not full
    ready_out <= NOT fifo1_full;
    fifo1_wr_en <= valid_in AND NOT fifo1_full;
    fifo1_wr_data <= pack_fifo1_data(
        proScreenX, proScreenY,
        camera_in.screen_u, camera_in.screen_v,
        camera_in.screen_centre, camera_in.position
    );
    
    -- Debug process for input stage
    process(clk)
    begin
        if rising_edge(clk) then
            if fifo1_wr_en = '1' then
                report "INPUT: Wrote to FIFO1, fifo1_full='" & std_logic'image(fifo1_full) & "'";
            end if;
        end if;
    end process;
    
    -- Unpack FIFO outputs
    f1_proScreenX      <= fifo1_rd_data(31 downto 0);
    f1_proScreenY      <= fifo1_rd_data(63 downto 32);
    f1_screen_u.x      <= fifo1_rd_data(95 downto 64);
    f1_screen_u.y      <= fifo1_rd_data(127 downto 96);
    f1_screen_u.z      <= fifo1_rd_data(159 downto 128);
    f1_screen_v.x      <= fifo1_rd_data(191 downto 160);
    f1_screen_v.y      <= fifo1_rd_data(223 downto 192);
    f1_screen_v.z      <= fifo1_rd_data(255 downto 224);
    f1_screen_centre.x <= fifo1_rd_data(287 downto 256);
    f1_screen_centre.y <= fifo1_rd_data(319 downto 288);
    f1_screen_centre.z <= fifo1_rd_data(351 downto 320);
    f1_position.x      <= fifo1_rd_data(383 downto 352);
    f1_position.y      <= fifo1_rd_data(415 downto 384);
    f1_position.z      <= fifo1_rd_data(447 downto 416);
    
    f2_scale_u.x         <= fifo2_rd_data(31 downto 0);
    f2_scale_u.y         <= fifo2_rd_data(63 downto 32);
    f2_scale_u.z         <= fifo2_rd_data(95 downto 64);
    f2_scale_v.x         <= fifo2_rd_data(127 downto 96);
    f2_scale_v.y         <= fifo2_rd_data(159 downto 128);
    f2_scale_v.z         <= fifo2_rd_data(191 downto 160);
    f2_screen_centre.x   <= fifo2_rd_data(223 downto 192);
    f2_screen_centre.y   <= fifo2_rd_data(255 downto 224);
    f2_screen_centre.z   <= fifo2_rd_data(287 downto 256);
    f2_position.x        <= fifo2_rd_data(319 downto 288);
    f2_position.y        <= fifo2_rd_data(351 downto 320);
    f2_position.z        <= fifo2_rd_data(383 downto 352);
    
    f3_add1_result.x     <= fifo3_rd_data(31 downto 0);
    f3_add1_result.y     <= fifo3_rd_data(63 downto 32);
    f3_add1_result.z     <= fifo3_rd_data(95 downto 64);
    f3_scale_v.x         <= fifo3_rd_data(127 downto 96);
    f3_scale_v.y         <= fifo3_rd_data(159 downto 128);
    f3_scale_v.z         <= fifo3_rd_data(191 downto 160);
    f3_position.x        <= fifo3_rd_data(223 downto 192);
    f3_position.y        <= fifo3_rd_data(255 downto 224);
    f3_position.z        <= fifo3_rd_data(287 downto 256);
    
    f4_add2_result.x     <= fifo4_rd_data(31 downto 0);
    f4_add2_result.y     <= fifo4_rd_data(63 downto 32);
    f4_add2_result.z     <= fifo4_rd_data(95 downto 64);
    f4_position.x        <= fifo4_rd_data(127 downto 96);
    f4_position.y        <= fifo4_rd_data(159 downto 128);
    f4_position.z        <= fifo4_rd_data(191 downto 160);
    
    -- Instantiate vec3 components
    scale_u_inst : vec3_scale_hw
        GENERIC MAP (PRODUCER_ID => PRODUCER_ID_BASE + 0)
        PORT MAP (
            clk => clk, reset => reset, valid_in => scale_u_start,
            v => scale_stage_screen_u, scalar => scale_stage_proScreenX,
            result => scale_u_result, valid_out => scale_u_valid,
            mult_requests => scale_u_mult_requests,
            mult_grants => mult_grants, mult_results => mult_results
        );
    
    scale_v_inst : vec3_scale_hw
        GENERIC MAP (PRODUCER_ID => PRODUCER_ID_BASE + 1)
        PORT MAP (
            clk => clk, reset => reset, valid_in => scale_v_start,
            v => scale_stage_screen_v, scalar => scale_stage_proScreenY,
            result => scale_v_result, valid_out => scale_v_valid,
            mult_requests => scale_v_mult_requests,
            mult_grants => mult_grants, mult_results => mult_results
        );
    
    add1_inst : vec3_add_hw
        GENERIC MAP (PRODUCER_ID => PRODUCER_ID_BASE + 2)
        PORT MAP (
            clk => clk, reset => reset, valid_in => add1_start,
            a => add1_stage_screen_centre, b => add1_stage_scale_u,
            result => add1_result, valid_out => add1_valid,
            addsub_requests => add1_addsub_requests,
            addsub_grants => addsub_grants, addsub_results => addsub_results
        );
    
    add2_inst : vec3_add_hw
        GENERIC MAP (PRODUCER_ID => PRODUCER_ID_BASE + 3)
        PORT MAP (
            clk => clk, reset => reset, valid_in => add2_start,
            a => add2_stage_add1_result, b => add2_stage_scale_v,
            result => add2_result, valid_out => add2_valid,
            addsub_requests => add2_addsub_requests,
            addsub_grants => addsub_grants, addsub_results => addsub_results
        );
    
    sub_inst : vec3_sub_hw
        GENERIC MAP (PRODUCER_ID => PRODUCER_ID_BASE + 4)
        PORT MAP (
            clk => clk, reset => reset, valid_in => sub_start,
            a => sub_stage_add2_result, b => sub_stage_position,
            result => sub_result, valid_out => sub_valid,
            addsub_requests => sub_addsub_requests,
            addsub_grants => addsub_grants, addsub_results => addsub_results
        );
    
    -- Combine mult requests
    PROCESS(scale_u_mult_requests, scale_v_mult_requests)
    BEGIN
        FOR i IN 0 TO NUM_PRODUCERS-1 LOOP
            mult_requests(i) <= init_producer_mult_request;
        END LOOP;
        mult_requests(PRODUCER_ID_BASE + 0) <= scale_u_mult_requests(PRODUCER_ID_BASE + 0);
        mult_requests(PRODUCER_ID_BASE + 1) <= scale_v_mult_requests(PRODUCER_ID_BASE + 1);
    END PROCESS;
    
    -- Combine addsub requests
    PROCESS(add1_addsub_requests, add2_addsub_requests, sub_addsub_requests)
    BEGIN
        FOR i IN 0 TO NUM_PRODUCERS-1 LOOP
            addsub_requests(i) <= init_producer_addsub_request;
        END LOOP;
        addsub_requests(PRODUCER_ID_BASE + 2) <= add1_addsub_requests(PRODUCER_ID_BASE + 2);
        addsub_requests(PRODUCER_ID_BASE + 3) <= add2_addsub_requests(PRODUCER_ID_BASE + 3);
        addsub_requests(PRODUCER_ID_BASE + 4) <= sub_addsub_requests(PRODUCER_ID_BASE + 4);
    END PROCESS;
    
    -- SCALE Stage Controller
    PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            scale_state <= IDLE;
            scale_u_start <= '0';
            scale_v_start <= '0';
            fifo1_rd_en <= '0';
            fifo2_wr_en <= '0';
            scale_u_valid_latched <= '0';
            scale_v_valid_latched <= '0';
            
        ELSIF rising_edge(clk) THEN
            scale_u_start <= '0';
            scale_v_start <= '0';
            fifo1_rd_en <= '0';
            fifo2_wr_en <= '0';
            
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
                        report "SCALE: IDLE->READ, fifo1_empty='" & std_logic'image(fifo1_empty) & "' fifo2_full='" & std_logic'image(fifo2_full) & "'";
                    END IF;
                
                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    scale_stage_proScreenX <= f1_proScreenX;
                    scale_stage_proScreenY <= f1_proScreenY;
                    scale_stage_screen_u <= f1_screen_u;
                    scale_stage_screen_v <= f1_screen_v;
                    scale_stage_screen_centre <= f1_screen_centre;
                    scale_stage_position <= f1_position;
                    scale_u_valid_latched <= '0';
                    scale_v_valid_latched <= '0';
                    scale_u_start <= '1';
                    scale_v_start <= '1';
                    scale_state <= BUSY;
                    report "SCALE: READ->BUSY, starting scale operations";
                
                WHEN BUSY =>
                    IF (scale_u_valid_latched = '1' OR scale_u_valid = '1') AND 
                       (scale_v_valid_latched = '1' OR scale_v_valid = '1') THEN
                        fifo2_wr_en <= '1';
                        fifo2_wr_data <= pack_fifo2_data(
                            scale_u_result, scale_v_result,
                            scale_stage_screen_centre, scale_stage_position
                        );
                        scale_state <= IDLE;
                        report "SCALE: BUSY->IDLE, writing to FIFO2";
                    END IF;
            END CASE;
        END IF;
    END PROCESS;
    
    -- ADD1 Stage Controller
    PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            add1_state <= IDLE;
            add1_start <= '0';
            fifo2_rd_en <= '0';
            fifo3_wr_en <= '0';
            
        ELSIF rising_edge(clk) THEN
            add1_start <= '0';
            fifo2_rd_en <= '0';
            fifo3_wr_en <= '0';
            
            CASE add1_state IS
                WHEN IDLE =>
                    IF fifo2_empty = '0' AND fifo3_full = '0' THEN
                        fifo2_rd_en <= '1';
                        add1_state <= READ;
                        report "ADD1: IDLE->READ";
                    END IF;
                
                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    add1_stage_screen_centre <= f2_screen_centre;
                    add1_stage_scale_u <= f2_scale_u;
                    add1_stage_scale_v <= f2_scale_v;
                    add1_stage_position <= f2_position;
                    add1_start <= '1';
                    add1_state <= BUSY;
                
                WHEN BUSY =>
                    IF add1_valid = '1' THEN
                        fifo3_wr_en <= '1';
                        fifo3_wr_data <= pack_fifo3_data(
                            add1_result, add1_stage_scale_v, add1_stage_position
                        );
                        add1_state <= IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;
    
    -- ADD2 Stage Controller
    PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            add2_state <= IDLE;
            add2_start <= '0';
            fifo3_rd_en <= '0';
            fifo4_wr_en <= '0';
            
        ELSIF rising_edge(clk) THEN
            add2_start <= '0';
            fifo3_rd_en <= '0';
            fifo4_wr_en <= '0';
            
            CASE add2_state IS
                WHEN IDLE =>
                    IF fifo3_empty = '0' AND fifo4_full = '0' THEN
                        fifo3_rd_en <= '1';
                        add2_state <= READ;
                        report "ADD2: IDLE->READ";
                    END IF;
                
                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    add2_stage_add1_result <= f3_add1_result;
                    add2_stage_scale_v <= f3_scale_v;
                    add2_stage_position <= f3_position;
                    add2_start <= '1';
                    add2_state <= BUSY;
                
                WHEN BUSY =>
                    IF add2_valid = '1' THEN
                        fifo4_wr_en <= '1';
                        fifo4_wr_data <= pack_fifo4_data(
                            add2_result, add2_stage_position
                        );
                        add2_state <= IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;
    
    -- SUB Stage Controller (final stage with output)
    PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            sub_state <= IDLE;
            sub_start <= '0';
            fifo4_rd_en <= '0';
            valid_out <= '0';
            ray <= (VEC3_ZERO, VEC3_ZERO, VEC3_ZERO);
            
        ELSIF rising_edge(clk) THEN
            sub_start <= '0';
            fifo4_rd_en <= '0';
            valid_out <= '0';
            
            CASE sub_state IS
                WHEN IDLE =>
                    IF fifo4_empty = '0' THEN
                        fifo4_rd_en <= '1';
                        sub_state <= READ;
                        report "SUB: IDLE->READ";
                    END IF;
                
                WHEN READ =>
                    -- Data from FIFO is now valid, capture it
                    sub_stage_position <= f4_position;
                    sub_stage_add2_result <= f4_add2_result;
                    sub_start <= '1';
                    sub_state <= BUSY;
                
                WHEN BUSY =>
                    IF sub_valid = '1' THEN
                        ray.point1 <= sub_stage_position;
                        ray.point2 <= sub_stage_add2_result;
                        ray.lab <= sub_result;
                        valid_out <= '1';
                        sub_state <= IDLE;
                        report "SUB: BUSY->IDLE, asserting valid_out";
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
