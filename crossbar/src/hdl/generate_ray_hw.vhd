LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;
USE work.crossbar_pkg.ALL;

-- Generate Ray using vec3 operation components
-- Each vec3 component uses single producer ID with 3 operation IDs
-- Producer allocation:
--   ID 0: scale_u
--   ID 1: scale_v
--   ID 2: add1
--   ID 3: add2
--   ID 4: sub
-- Total: 5 producer IDs

ENTITY generate_ray IS
    GENERIC (
        PRODUCER_ID_BASE : integer range 0 to 25 := 0  -- Needs 5 consecutive IDs
    );
    PORT (
        clk   : IN STD_LOGIC;
        reset : IN STD_LOGIC;

        proScreenX             : IN fp32;
        proScreenY             : IN fp32;
        valid_in               : IN STD_LOGIC;
        camera_in              : IN  Camera;

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
    
    -- Component declarations
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
    
    -- State machine
    TYPE state_type IS (IDLE, SCALE, WAIT_SCALES, ADD1, WAIT_ADD1, ADD2, WAIT_ADD2, SUB, WAIT_SUB, DONE);
    SIGNAL state : state_type := IDLE;
    
    -- Internal signals
    SIGNAL scale_u_result, scale_v_result : Vec3 := VEC3_ZERO;
    SIGNAL add1_result, add2_result : Vec3 := VEC3_ZERO;
    SIGNAL sub_result : Vec3 := VEC3_ZERO;
    
    SIGNAL scale_u_valid, scale_v_valid : STD_LOGIC := '0';
    SIGNAL add1_valid, add2_valid : STD_LOGIC := '0';
    SIGNAL sub_valid : STD_LOGIC := '0';
    
    -- Latched valid signals (to catch single-cycle pulses)
    SIGNAL scale_u_valid_latched, scale_v_valid_latched : STD_LOGIC := '0';
    SIGNAL add1_valid_latched, add2_valid_latched : STD_LOGIC := '0';
    SIGNAL sub_valid_latched : STD_LOGIC := '0';
    
    SIGNAL scale_u_start, scale_v_start : STD_LOGIC := '0';
    SIGNAL add1_start, add2_start : STD_LOGIC := '0';
    SIGNAL sub_start : STD_LOGIC := '0';
    
    SIGNAL point1_reg : Vec3 := VEC3_ZERO;
    
    -- Request arrays for each component
    SIGNAL scale_u_mult_requests, scale_v_mult_requests : producer_mult_request_array_t := (OTHERS => init_producer_mult_request);
    SIGNAL add1_addsub_requests, add2_addsub_requests, sub_addsub_requests : producer_addsub_request_array_t := (OTHERS => init_producer_addsub_request);

BEGIN
    
    -- Instantiate vec3_scale for scale_u (ID 0)
    scale_u_inst : vec3_scale_hw
        GENERIC MAP (
            PRODUCER_ID => PRODUCER_ID_BASE + 0
        )
        PORT MAP (
            clk           => clk,
            reset         => reset,
            valid_in      => scale_u_start,
            v             => camera_in.screen_u,
            scalar        => proScreenX,
            result        => scale_u_result,
            valid_out     => scale_u_valid,
            mult_requests => scale_u_mult_requests,
            mult_grants   => mult_grants,
            mult_results  => mult_results
        );
    
    -- Instantiate vec3_scale for scale_v (ID 1)
    scale_v_inst : vec3_scale_hw
        GENERIC MAP (
            PRODUCER_ID => PRODUCER_ID_BASE + 1
        )
        PORT MAP (
            clk           => clk,
            reset         => reset,
            valid_in      => scale_v_start,
            v             => camera_in.screen_v,
            scalar        => proScreenY,
            result        => scale_v_result,
            valid_out     => scale_v_valid,
            mult_requests => scale_v_mult_requests,
            mult_grants   => mult_grants,
            mult_results  => mult_results
        );
    
    -- Instantiate vec3_add for add1: screen_centre + scale_u (ID 2)
    add1_inst : vec3_add_hw
        GENERIC MAP (
            PRODUCER_ID => PRODUCER_ID_BASE + 2
        )
        PORT MAP (
            clk             => clk,
            reset           => reset,
            valid_in        => add1_start,
            a               => camera_in.screen_centre,
            b               => scale_u_result,
            result          => add1_result,
            valid_out       => add1_valid,
            addsub_requests => add1_addsub_requests,
            addsub_grants   => addsub_grants,
            addsub_results  => addsub_results
        );
    
    -- Instantiate vec3_add for add2: add1 + scale_v (ID 3)
    add2_inst : vec3_add_hw
        GENERIC MAP (
            PRODUCER_ID => PRODUCER_ID_BASE + 3
        )
        PORT MAP (
            clk             => clk,
            reset           => reset,
            valid_in        => add2_start,
            a               => add1_result,
            b               => scale_v_result,
            result          => add2_result,
            valid_out       => add2_valid,
            addsub_requests => add2_addsub_requests,
            addsub_grants   => addsub_grants,
            addsub_results  => addsub_results
        );
    
    -- Instantiate vec3_sub for sub: add2 - camera.position (ID 4)
    sub_inst : vec3_sub_hw
        GENERIC MAP (
            PRODUCER_ID => PRODUCER_ID_BASE + 4
        )
        PORT MAP (
            clk             => clk,
            reset           => reset,
            valid_in        => sub_start,
            a               => add2_result,
            b               => camera_in.position,
            result          => sub_result,
            valid_out       => sub_valid,
            addsub_requests => sub_addsub_requests,
            addsub_grants   => addsub_grants,
            addsub_results  => addsub_results
        );
    
    -- Pass through mult requests directly (each uses different producer ID)
    PROCESS(scale_u_mult_requests, scale_v_mult_requests)
    BEGIN
        -- Initialize all to default
        FOR i IN 0 TO NUM_PRODUCERS-1 LOOP
            mult_requests(i) <= init_producer_mult_request;
        END LOOP;
        -- Assign active requests
        mult_requests(PRODUCER_ID_BASE + 0) <= scale_u_mult_requests(PRODUCER_ID_BASE + 0);
        mult_requests(PRODUCER_ID_BASE + 1) <= scale_v_mult_requests(PRODUCER_ID_BASE + 1);
    END PROCESS;
    
    -- Pass through addsub requests directly (each uses different producer ID)
    PROCESS(add1_addsub_requests, add2_addsub_requests, sub_addsub_requests)
    BEGIN
        -- Initialize all to default  
        FOR i IN 0 TO NUM_PRODUCERS-1 LOOP
            addsub_requests(i) <= init_producer_addsub_request;
        END LOOP;
        -- Assign active requests
        addsub_requests(PRODUCER_ID_BASE + 2) <= add1_addsub_requests(PRODUCER_ID_BASE + 2);
        addsub_requests(PRODUCER_ID_BASE + 3) <= add2_addsub_requests(PRODUCER_ID_BASE + 3);
        addsub_requests(PRODUCER_ID_BASE + 4) <= sub_addsub_requests(PRODUCER_ID_BASE + 4);
    END PROCESS;
    
    -- State machine
    PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            state <= IDLE;
            scale_u_start <= '0';
            scale_v_start <= '0';
            add1_start <= '0';
            add2_start <= '0';
            sub_start <= '0';
            valid_out <= '0';
            ray <= (VEC3_ZERO, VEC3_ZERO, VEC3_ZERO);
            point1_reg <= VEC3_ZERO;
            scale_u_valid_latched <= '0';
            scale_v_valid_latched <= '0';
            add1_valid_latched <= '0';
            add2_valid_latched <= '0';
            sub_valid_latched <= '0';
            
        ELSIF rising_edge(clk) THEN
            -- Default: clear start signals and valid_out
            scale_u_start <= '0';
            scale_v_start <= '0';
            add1_start <= '0';
            add2_start <= '0';
            sub_start <= '0';
            valid_out <= '0';
            
            -- Latch valid signals
            IF scale_u_valid = '1' THEN
                scale_u_valid_latched <= '1';
            END IF;
            IF scale_v_valid = '1' THEN
                scale_v_valid_latched <= '1';
            END IF;
            IF add1_valid = '1' THEN
                add1_valid_latched <= '1';
            END IF;
            IF add2_valid = '1' THEN
                add2_valid_latched <= '1';
            END IF;
            IF sub_valid = '1' THEN
                sub_valid_latched <= '1';
            END IF;
            
            CASE state IS
                WHEN IDLE =>
                    IF valid_in = '1' THEN
                        point1_reg <= camera_in.position;
                        scale_u_valid_latched <= '0';
                        scale_v_valid_latched <= '0';
                        state <= SCALE;
                    END IF;
                
                WHEN SCALE =>
                    -- Start both scales in parallel
                    scale_u_start <= '1';
                    scale_v_start <= '1';
                    report "GENERATE_RAY: Starting scales";
                    state <= WAIT_SCALES;
                
                WHEN WAIT_SCALES =>
                    report "GENERATE_RAY: WAIT_SCALES - scale_u_valid=" & std_logic'image(scale_u_valid) & 
                           " scale_v_valid=" & std_logic'image(scale_v_valid) & 
                           " mult_results(0).valid=" & std_logic'image(mult_results(0).valid) & 
                           " mult_results(1).valid=" & std_logic'image(mult_results(1).valid);
                    IF (scale_u_valid_latched = '1' OR scale_u_valid = '1') AND 
                       (scale_v_valid_latched = '1' OR scale_v_valid = '1') THEN
                        report "GENERATE_RAY: Both scales valid, moving to ADD1";
                        add1_valid_latched <= '0';
                        state <= ADD1;
                    END IF;
                
                WHEN ADD1 =>
                    add1_start <= '1';
                    state <= WAIT_ADD1;
                
                WHEN WAIT_ADD1 =>
                    IF add1_valid_latched = '1' OR add1_valid = '1' THEN
                        add2_valid_latched <= '0';
                        state <= ADD2;
                    END IF;
                
                WHEN ADD2 =>
                    add2_start <= '1';
                    state <= WAIT_ADD2;
                
                WHEN WAIT_ADD2 =>
                    IF add2_valid_latched = '1' OR add2_valid = '1' THEN
                        sub_valid_latched <= '0';
                        state <= SUB;
                    END IF;
                
                WHEN SUB =>
                    sub_start <= '1';
                    state <= WAIT_SUB;
                
                WHEN WAIT_SUB =>
                    IF sub_valid_latched = '1' OR sub_valid = '1' THEN
                        ray.point1 <= point1_reg;
                        ray.point2 <= add2_result;
                        ray.lab <= sub_result;
                        valid_out <= '1';
                        state <= DONE;
                    END IF;
                
                WHEN DONE =>
                    IF valid_in = '0' THEN
                        state <= IDLE;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE behavioral;
