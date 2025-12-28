library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.lin_alg_pkg.all;
use work.crossbar_pkg.all;

-- Hardware Vec3 scalar multiplication using crossbar: result = v * scalar
-- Uses single producer ID with 3 operation IDs for x, y, z components
-- 
-- Performance:
--   Latency: ~4 clock cycles (crossbar latency + FP_MULT latency)
--   Throughput: 1 result per cycle when all 3 mults are granted
--   Resource usage: Shares crossbar MULT units
--
-- Producer ID: Uses single PRODUCER_ID with op IDs 0, 1, 2
entity vec3_scale_hw is
    generic (
        PRODUCER_ID : integer range 0 to 31 := 0  -- Single producer ID
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        v         : in  Vec3;
        scalar    : in  fp32;
        result    : out Vec3;
        valid_out : out std_logic;
        
        -- Crossbar interface (3 producer slots for x, y, z)
        mult_requests : out producer_mult_request_array_t;
        mult_grants   : in  producer_grant_array_t;
        mult_results  : in  producer_result_array_t
    );
end entity vec3_scale_hw;

architecture behavioral of vec3_scale_hw is
    
    -- State machine
    type state_t is (IDLE, REQUESTING, WAITING);
    signal state : state_t := IDLE;
    
    -- Operation counter for TID generation
    signal op_counter : unsigned(10 downto 0) := (others => '0');
    
    -- TID values for tracking x, y, z operations
    signal tid_x, tid_y, tid_z : std_logic_vector(TID_WIDTH-1 downto 0);
    
    -- Grant tracking
    signal granted_x, granted_y, granted_z : std_logic := '0';
    
    -- Result tracking
    signal result_x, result_y, result_z : std_logic_vector(31 downto 0);
    signal result_x_valid, result_y_valid, result_z_valid : std_logic := '0';
    
    -- Input registers
    signal v_reg : Vec3;
    signal scalar_reg : fp32;
    
begin
    
    -- Main state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                op_counter <= (others => '0');
                mult_requests(PRODUCER_ID) <= init_producer_mult_request;
                granted_x <= '0';
                granted_y <= '0';
                granted_z <= '0';
                result_x_valid <= '0';
                result_y_valid <= '0';
                result_z_valid <= '0';
                valid_out <= '0';
            else
                -- Default: clear valid_out
                valid_out <= '0';
                
                case state is
                    when IDLE =>
                        -- Default: no requests when idle
                        mult_requests(PRODUCER_ID).valid <= '0';
                        
                        if valid_in = '1' then
                            report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Starting operation, moving to REQUESTING";
                            -- Latch inputs
                            v_reg <= v;
                            scalar_reg <= scalar;
                            granted_x <= '0';
                            granted_y <= '0';
                            granted_z <= '0';
                            result_x_valid <= '0';
                            result_y_valid <= '0';
                            result_z_valid <= '0';
                            -- Generate TIDs with operation IDs 0, 1, 2 for x, y, z (before incrementing counter)
                            tid_x <= make_tid(PRODUCER_ID, to_integer(op_counter) * 3 + 0);
                            tid_y <= make_tid(PRODUCER_ID, to_integer(op_counter) * 3 + 1);
                            tid_z <= make_tid(PRODUCER_ID, to_integer(op_counter) * 3 + 2);
                            -- Increment counter for next operation
                            op_counter <= op_counter + 1;
                            state <= REQUESTING;
                        end if;
                    
                    when REQUESTING =>
                        -- Request X, Y, Z multiplications sequentially using same producer ID
                        if granted_x = '0' then
                            mult_requests(PRODUCER_ID).valid <= '1';
                            mult_requests(PRODUCER_ID).unit_index <= (PRODUCER_ID * 3 + 0) mod NUM_MULT_UNITS;
                            mult_requests(PRODUCER_ID).data(31 downto 0) <= v_reg.x;
                            mult_requests(PRODUCER_ID).data(63 downto 32) <= scalar_reg;
                            mult_requests(PRODUCER_ID).tid <= tid_x;
                            if mult_grants(PRODUCER_ID).granted = '1' then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): X granted";
                                granted_x <= '1';
                            end if;
                        elsif granted_y = '0' then
                            mult_requests(PRODUCER_ID).valid <= '1';
                            mult_requests(PRODUCER_ID).unit_index <= (PRODUCER_ID * 3 + 1) mod NUM_MULT_UNITS;
                            mult_requests(PRODUCER_ID).data(31 downto 0) <= v_reg.y;
                            mult_requests(PRODUCER_ID).data(63 downto 32) <= scalar_reg;
                            mult_requests(PRODUCER_ID).tid <= tid_y;
                            if mult_grants(PRODUCER_ID).granted = '1' then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Y granted";
                                granted_y <= '1';
                            end if;
                        elsif granted_z = '0' then
                            mult_requests(PRODUCER_ID).valid <= '1';
                            mult_requests(PRODUCER_ID).unit_index <= (PRODUCER_ID * 3 + 2) mod NUM_MULT_UNITS;
                            mult_requests(PRODUCER_ID).data(31 downto 0) <= v_reg.z;
                            mult_requests(PRODUCER_ID).data(63 downto 32) <= scalar_reg;
                            mult_requests(PRODUCER_ID).tid <= tid_z;
                            if mult_grants(PRODUCER_ID).granted = '1' then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Z granted";
                                granted_z <= '1';
                            end if;
                        else
                            report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): All granted, moving to WAITING";
                            state <= WAITING;
                        end if;
                        
                        -- Capture results even while requesting (results may arrive early)
                        if mult_results(PRODUCER_ID).valid = '1' then
                            if mult_results(PRODUCER_ID).tid = tid_x and result_x_valid = '0' then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Captured X result (in REQUESTING)";
                                result_x <= mult_results(PRODUCER_ID).data;
                                result_x_valid <= '1';
                            elsif mult_results(PRODUCER_ID).tid = tid_y and result_y_valid = '0' then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Captured Y result (in REQUESTING)";
                                result_y <= mult_results(PRODUCER_ID).data;
                                result_y_valid <= '1';
                            elsif mult_results(PRODUCER_ID).tid = tid_z and result_z_valid = '0' then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Captured Z result (in REQUESTING)";
                                result_z <= mult_results(PRODUCER_ID).data;
                                result_z_valid <= '1';
                            end if;
                        end if;
                        
                        -- Check if done (all requests granted AND all results received)
                        if granted_x = '1' and granted_y = '1' and granted_z = '1' and
                           result_x_valid = '1' and result_y_valid = '1' and result_z_valid = '1' then
                            report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): All complete in REQUESTING, asserting valid_out";
                            valid_out <= '1';
                            state <= IDLE;
                        end if;
                    
                    when WAITING =>
                        -- Stop requesting
                        mult_requests(PRODUCER_ID).valid <= '0';
                        
                        report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): WAITING - mult_results.valid=" & std_logic'image(mult_results(PRODUCER_ID).valid) & 
                               " result_valid=(" & std_logic'image(result_x_valid) & "," & std_logic'image(result_y_valid) & "," & std_logic'image(result_z_valid) & ")";
                        
                        -- Capture results by matching TID
                        if mult_results(PRODUCER_ID).valid = '1' then
                            if mult_results(PRODUCER_ID).tid = tid_x then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Captured X result";
                                result_x <= mult_results(PRODUCER_ID).data;
                                result_x_valid <= '1';
                            elsif mult_results(PRODUCER_ID).tid = tid_y then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Captured Y result";
                                result_y <= mult_results(PRODUCER_ID).data;
                                result_y_valid <= '1';
                            elsif mult_results(PRODUCER_ID).tid = tid_z then
                                report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): Captured Z result";
                                result_z <= mult_results(PRODUCER_ID).data;
                                result_z_valid <= '1';
                            end if;
                        end if;
                        
                        -- When all results are ready, assert valid_out
                        if result_x_valid = '1' and result_y_valid = '1' and result_z_valid = '1' then
                            report "VEC3_SCALE(" & integer'image(PRODUCER_ID) & "): All results ready, asserting valid_out";
                            valid_out <= '1';
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    -- Output assignment
    result.x <= result_x;
    result.y <= result_y;
    result.z <= result_z;
    
end architecture behavioral;
