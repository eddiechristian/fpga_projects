LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

LIBRARY work;
USE work.crossbar_pkg.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;

-- Top module for ray tracer with pixel generator and ray consumer
ENTITY top_module_raytracer IS
    PORT (
        clk        : IN STD_LOGIC;
        rst        : IN STD_LOGIC;
        frame_done : OUT STD_LOGIC  -- Pulses when frame completes
    );
END ENTITY top_module_raytracer;

ARCHITECTURE structural OF top_module_raytracer IS

    -- Scene configuration
    SIGNAL scene : Scene;
    
    -- Crossbar signals
    SIGNAL dot_requests    : producer_dot_request_array_t;
    SIGNAL dot4_requests   : producer_dot4_request_array_t;
    SIGNAL mult_requests   : producer_mult_request_array_t;
    SIGNAL fma_requests    : producer_fma_request_array_t;
    SIGNAL addsub_requests : producer_addsub_request_array_t;
    SIGNAL prod_grants     : producer_grant_array_t;
    SIGNAL prod_results    : producer_result_array_t;
    SIGNAL locked          : STD_LOGIC;
    
    -- Pixel generator / ray FIFO signals
    SIGNAL pixel_gen_ray       : Ray;
    SIGNAL pixel_gen_ray_empty : STD_LOGIC;
    SIGNAL pixel_gen_ray_rd_en : STD_LOGIC;
    SIGNAL pixel_gen_frame_complete : STD_LOGIC;
    SIGNAL pixel_gen_frame_ack : STD_LOGIC;
    
    -- Consumer state
    SIGNAL ray_count : INTEGER := 0;
    SIGNAL frame_count : INTEGER := 0;
    SIGNAL frame_ack_delay_counter : INTEGER RANGE 0 TO 31 := 0;

BEGIN

    -- Initialize scene (hardcoded camera)
    scene.camera_val.position.x      <= X"00000000";  -- 0.0
    scene.camera_val.position.y      <= X"C1200000";  -- -10.0
    scene.camera_val.position.z      <= X"00000000";  -- 0.0
    scene.camera_val.lookat          <= VEC3_ZERO;
    scene.camera_val.up              <= VEC3_UNIT_Z;
    scene.camera_val.screen_centre.x <= X"00000000";  -- 0.0
    scene.camera_val.screen_centre.y <= X"C1100000";  -- -9.0
    scene.camera_val.screen_centre.z <= X"00000000";  -- 0.0
    scene.camera_val.screen_u.x      <= X"3E800000";  -- 0.25
    scene.camera_val.screen_u.y      <= X"00000000";  -- 0.0
    scene.camera_val.screen_u.z      <= X"00000000";  -- 0.0
    scene.camera_val.screen_v.x      <= X"00000000";  -- 0.0
    scene.camera_val.screen_v.y      <= X"00000000";  -- 0.0
    scene.camera_val.screen_v.z      <= X"3E100000";  -- 0.140625

    -- Initialize unused crossbar producers
    gen_unused_dot : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        dot_requests(i) <= init_producer_dot_request;
    END GENERATE;

    gen_unused_dot4 : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        dot4_requests(i) <= init_producer_dot4_request;
    END GENERATE;

    gen_unused_fma : FOR i IN 0 TO NUM_PRODUCERS - 1 GENERATE
        fma_requests(i) <= init_producer_fma_request;
    END GENERATE;

    -- Crossbar system
    crossbar_inst : ENTITY work.crossbar_fp_system
        PORT MAP(
            clk_100mhz      => clk,
            rst             => rst,
            locked          => locked,
            dot_requests    => dot_requests,
            dot4_requests   => dot4_requests,
            mult_requests   => mult_requests,
            fma_requests    => fma_requests,
            addsub_requests => addsub_requests,
            prod_grants     => prod_grants,
            prod_results    => prod_results
        );
    
    -- Pixel generator with embedded generate_ray
    pixel_gen_inst : ENTITY work.pixel_gen_hw
        GENERIC MAP(
            WIDTH => 64,
            HEIGHT => 48,
            PRODUCER_ID_BASE => 0,  -- Uses producer IDs 0-8 (coord calc + ray gen all in generate_ray)
            RAY_FIFO_DEPTH => 64
        )
        PORT MAP(
            clk             => clk,
            reset           => rst,
            scene_val       => scene,
            
            -- Crossbar connections
            mult_requests   => mult_requests,
            mult_grants     => prod_grants,
            mult_results    => prod_results,
            addsub_requests => addsub_requests,
            addsub_grants   => prod_grants,
            addsub_results  => prod_results,
            
            -- Ray FIFO interface
            ray_rd_en       => pixel_gen_ray_rd_en,
            ray_out         => pixel_gen_ray,
            ray_empty       => pixel_gen_ray_empty,
            
            -- Frame control
            frame_complete  => pixel_gen_frame_complete,
            frame_ack       => pixel_gen_frame_ack
        );
    
    -- Ray consumer process
    ray_consumer: PROCESS(clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                pixel_gen_ray_rd_en <= '0';
                pixel_gen_frame_ack <= '0';
                ray_count <= 0;
                frame_count <= 0;
                frame_done <= '0';
            ELSE
                frame_done <= '0';
                
                -- Read rays continuously when available
                IF pixel_gen_ray_empty = '0' THEN
                    pixel_gen_ray_rd_en <= '1';
                ELSE
                    pixel_gen_ray_rd_en <= '0';
                END IF;
                
                -- Process ray (1 cycle after rd_en)
                IF pixel_gen_ray_rd_en = '1' THEN
                    ray_count <= ray_count + 1;
                    
                    -- Report every 10,000 rays
                    IF (ray_count + 1) MOD 10000 = 0 THEN
                        REPORT "Processed " & INTEGER'image(ray_count + 1) & " rays";
                    END IF;
                    
                    -- TODO: Add ray-scene intersection testing here
                    -- For now, just consume the rays
                END IF;
                
                -- Handle frame completion with 30-cycle delay
                IF pixel_gen_frame_complete = '1' THEN
                    IF frame_ack_delay_counter < 30 THEN
                        -- Wait 30 cycles before acknowledging
                        frame_ack_delay_counter <= frame_ack_delay_counter + 1;
                        pixel_gen_frame_ack <= '0';
                    ELSE
                        -- Acknowledge after delay
                        pixel_gen_frame_ack <= '1';
                        frame_count <= frame_count + 1;
                        frame_done <= '1';
                        frame_ack_delay_counter <= 0;
                        
                        REPORT "Frame " & INTEGER'image(frame_count) & " complete! " &
                               "Total rays: " & INTEGER'image(ray_count) &
                               " (ack delayed 30 cycles)";
                    END IF;
                ELSE
                    pixel_gen_frame_ack <= '0';
                    frame_ack_delay_counter <= 0;
                END IF;
            END IF;
        END IF;
    END PROCESS;

END ARCHITECTURE structural;
