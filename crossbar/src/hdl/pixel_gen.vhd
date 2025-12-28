LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.lin_alg_pkg.ALL;
USE work.ray_tracing_pkg.ALL;
USE work.crossbar_pkg.ALL;

ENTITY pixel_gen_hw IS
   
    GENERIC (
        WIDTH  : INTEGER := 640;
        HEIGHT : INTEGER := 480;
        PRODUCER_ID_BASE : INTEGER RANGE 0 TO 25 := 0;  -- Base ID for generate_ray (needs 9 IDs)
        RAY_FIFO_DEPTH   : INTEGER := 32
    );
    PORT (
        clk       : IN STD_LOGIC;
        reset     : IN STD_LOGIC;
        scene_val : IN Scene;
        
        -- Crossbar interfaces for generate_ray
        mult_requests   : OUT producer_mult_request_array_t;
        mult_grants     : IN  producer_grant_array_t;
        mult_results    : IN  producer_result_array_t;
        addsub_requests : OUT producer_addsub_request_array_t;
        addsub_grants   : IN  producer_grant_array_t;
        addsub_results  : IN  producer_result_array_t;
        
        -- Ray FIFO read interface (for downstream consumer)
        ray_rd_en  : IN  STD_LOGIC;
        ray_out    : OUT Ray;
        ray_empty  : OUT STD_LOGIC;
        
        -- Frame control
        frame_complete : OUT STD_LOGIC;  -- Pulses when frame done, waiting for ack
        frame_ack      : IN  STD_LOGIC   -- Consumer ready for next frame
    );
END ENTITY pixel_gen_hw;

ARCHITECTURE behavioral OF pixel_gen_hw IS

    SIGNAL x_counter     : INTEGER RANGE 0 TO WIDTH - 1  := 0;
    SIGNAL y_counter     : INTEGER RANGE 0 TO HEIGHT - 1 := 0;
    SIGNAL frame_counter : INTEGER;
    
    -- Generate ray signals
    SIGNAL gen_ray_ready     : STD_LOGIC;
    SIGNAL gen_ray_out       : Ray;
    SIGNAL gen_ray_valid     : STD_LOGIC;
    
    -- Ray FIFO signals
    SIGNAL ray_fifo_wr_en    : STD_LOGIC;
    SIGNAL ray_fifo_full     : STD_LOGIC;
    SIGNAL ray_fifo_rd_data  : STD_LOGIC_VECTOR(351 downto 0);  -- Ray = 3*Vec3 + 2*INT = 288 + 64 = 352 bits
    
    -- Ray packing/unpacking
    FUNCTION pack_ray(r : Ray) RETURN STD_LOGIC_VECTOR IS
        VARIABLE result : STD_LOGIC_VECTOR(351 DOWNTO 0);
    BEGIN
        result(351 DOWNTO 256) := r.point1.x & r.point1.y & r.point1.z;
        result(255 DOWNTO 160) := r.point2.x & r.point2.y & r.point2.z;
        result(159 DOWNTO 64)  := r.lab.x & r.lab.y & r.lab.z;
        result(63 DOWNTO 32)   := STD_LOGIC_VECTOR(TO_SIGNED(r.pixel_x, 32));
        result(31 DOWNTO 0)    := STD_LOGIC_VECTOR(TO_SIGNED(r.pixel_y, 32));
        RETURN result;
    END FUNCTION;
    
    FUNCTION unpack_ray(v : STD_LOGIC_VECTOR) RETURN Ray IS
        VARIABLE result : Ray;
    BEGIN
        result.point1.x := v(351 DOWNTO 320);
        result.point1.y := v(319 DOWNTO 288);
        result.point1.z := v(287 DOWNTO 256);
        result.point2.x := v(255 DOWNTO 224);
        result.point2.y := v(223 DOWNTO 192);
        result.point2.z := v(191 DOWNTO 160);
        result.lab.x    := v(159 DOWNTO 128);
        result.lab.y    := v(127 DOWNTO 96);
        result.lab.z    := v(95 DOWNTO 64);
        result.pixel_x  := TO_INTEGER(SIGNED(v(63 DOWNTO 32)));
        result.pixel_y  := TO_INTEGER(SIGNED(v(31 DOWNTO 0)));
        RETURN result;
    END FUNCTION;

    TYPE pixel_gen_state_t IS (RUNNING, END_FRAME);

    SIGNAL state : pixel_gen_state_t := RUNNING;
    
    COMPONENT gen_ray_fifo IS
        GENERIC (
            DATA_WIDTH : INTEGER := 32;
            DEPTH      : INTEGER := 4
        );
        PORT (
            clk      : IN  STD_LOGIC;
            reset    : IN  STD_LOGIC;
            wr_en    : IN  STD_LOGIC;
            wr_data  : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
            full     : OUT STD_LOGIC;
            rd_en    : IN  STD_LOGIC;
            rd_data  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1 DOWNTO 0);
            empty    : OUT STD_LOGIC
        );
    END COMPONENT;

BEGIN
    
    -- Generate ray instance (handles coord calc internally)
    gen_ray_inst : entity work.generate_ray
    GENERIC MAP(
        WIDTH            => WIDTH,
        HEIGHT           => HEIGHT,
        PRODUCER_ID_BASE => PRODUCER_ID_BASE,
        FIFO_DEPTH       => 32
    )
    PORT MAP(
        clk              => clk,
        reset            => reset,
        pixel_x          => x_counter,
        pixel_y          => y_counter,
        valid_in         => gen_ray_ready,  -- Feed pixels when ready
        camera_in        => scene_val.camera_val,
        ready_out        => gen_ray_ready,
        ray              => gen_ray_out,
        valid_out        => gen_ray_valid,
        mult_requests    => mult_requests,
        mult_grants      => mult_grants,
        mult_results     => mult_results,
        addsub_requests  => addsub_requests,
        addsub_grants    => addsub_grants,
        addsub_results   => addsub_results
    );
    
    -- Ray output FIFO
    ray_fifo_inst : gen_ray_fifo
    GENERIC MAP(
        DATA_WIDTH => 352,
        DEPTH => RAY_FIFO_DEPTH
    )
    PORT MAP(
        clk     => clk,
        reset   => reset,
        wr_en   => ray_fifo_wr_en,
        wr_data => pack_ray(gen_ray_out),
        full    => ray_fifo_full,
        rd_en   => ray_rd_en,
        rd_data => ray_fifo_rd_data,
        empty   => ray_empty
    );
    
    -- Write to FIFO when ray is valid and FIFO not full
    ray_fifo_wr_en <= gen_ray_valid AND NOT ray_fifo_full;

    PROCESS (clk, reset)
    BEGIN
        IF reset = '1' THEN
            state              <= RUNNING;
            x_counter          <= 0;
            y_counter          <= 0;
            frame_counter      <= 0;
            frame_complete     <= '0';
        ELSIF rising_edge(clk) THEN
            CASE state IS
                WHEN RUNNING =>
                    -- Advance pixel counters when generate_ray is ready
                    IF gen_ray_ready = '1' THEN
                        IF x_counter < WIDTH - 1 THEN
                            x_counter <= x_counter + 1;
                        ELSIF y_counter < HEIGHT - 1 THEN
                            x_counter <= 0;
                            y_counter <= y_counter + 1;
                        ELSE
                            -- Reached last pixel
                            x_counter <= 0;
                            y_counter <= 0;
                            frame_counter <= frame_counter + 1;
                            state <= END_FRAME;
                        END IF;
                    END IF;
                    
                WHEN END_FRAME =>
                    -- Wait for: no rays in flight, FIFO empty, and consumer acknowledgment
                    frame_complete <= '1';  -- Signal frame done
                    
                    IF gen_ray_valid = '0' AND ray_empty = '1' AND frame_ack = '1' THEN
                        -- All conditions met: start next frame
                        frame_complete <= '0';
                        state <= RUNNING;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;
    
    -- Output assignment: unpack ray from FIFO
    ray_out <= unpack_ray(ray_fifo_rd_data);

END ARCHITECTURE behavioral;
