library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.lin_alg_pkg.all;
use work.crossbar_pkg.all;

-- Hardware Vec3 addition using crossbar: result = a + b
-- Uses single producer ID with 3 operation IDs for x, y, z components
-- 
-- Performance:
--   Latency: ~4 clock cycles (crossbar latency + FP_ADDSUB latency)
--   Throughput: 1 result per cycle when all 3 addsubs are granted
--   Resource usage: Shares crossbar ADDSUB units
--
-- Producer ID: Uses single PRODUCER_ID with op IDs 0, 1, 2
entity vec3_add_hw is
    generic (
        PRODUCER_ID : integer range 0 to 31 := 0  -- Single producer ID
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        valid_in  : in  std_logic;
        a         : in  Vec3;
        b         : in  Vec3;
        result    : out Vec3;
        valid_out : out std_logic;
        
        -- Crossbar interface (3 producer slots for x, y, z)
        addsub_requests : out producer_addsub_request_array_t;
        addsub_grants   : in  producer_grant_array_t;
        addsub_results  : in  producer_result_array_t
    );
end entity vec3_add_hw;

architecture behavioral of vec3_add_hw is
    
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
    signal a_reg, b_reg : Vec3;
    
begin
    
    -- Main state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                op_counter <= (others => '0');
                addsub_requests(PRODUCER_ID) <= init_producer_addsub_request;
                addsub_requests(PRODUCER_ID) <= init_producer_addsub_request;
                addsub_requests(PRODUCER_ID) <= init_producer_addsub_request;
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
                        addsub_requests(PRODUCER_ID).valid <= '0';
                        addsub_requests(PRODUCER_ID).valid <= '0';
                        addsub_requests(PRODUCER_ID).valid <= '0';
                        
                        if valid_in = '1' then
                            report "VEC3_ADD: Entering REQUESTING state, PRODUCER_ID=" & integer'image(PRODUCER_ID);
                            -- Latch inputs
                            a_reg <= a;
                            b_reg <= b;
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
                        -- Request X, Y, Z additions sequentially using same producer ID
                        if granted_x = '0' then
                            addsub_requests(PRODUCER_ID).valid <= '1';
                            addsub_requests(PRODUCER_ID).unit_index <= 0;
                            addsub_requests(PRODUCER_ID).data(31 downto 0) <= a_reg.x;
                            addsub_requests(PRODUCER_ID).data(63 downto 32) <= b_reg.x;
                            addsub_requests(PRODUCER_ID).data(64) <= '0';  -- 0 = ADD operation
                            addsub_requests(PRODUCER_ID).tid <= tid_x;
                            if addsub_grants(PRODUCER_ID).granted = '1' then
                                granted_x <= '1';
                            end if;
                        elsif granted_y = '0' then
                            addsub_requests(PRODUCER_ID).valid <= '1';
                            addsub_requests(PRODUCER_ID).unit_index <= 0;
                            addsub_requests(PRODUCER_ID).data(31 downto 0) <= a_reg.y;
                            addsub_requests(PRODUCER_ID).data(63 downto 32) <= b_reg.y;
                            addsub_requests(PRODUCER_ID).data(64) <= '0';
                            addsub_requests(PRODUCER_ID).tid <= tid_y;
                            if addsub_grants(PRODUCER_ID).granted = '1' then
                                granted_y <= '1';
                            end if;
                        elsif granted_z = '0' then
                            addsub_requests(PRODUCER_ID).valid <= '1';
                            addsub_requests(PRODUCER_ID).unit_index <= 0;
                            addsub_requests(PRODUCER_ID).data(31 downto 0) <= a_reg.z;
                            addsub_requests(PRODUCER_ID).data(63 downto 32) <= b_reg.z;
                            addsub_requests(PRODUCER_ID).data(64) <= '0';
                            addsub_requests(PRODUCER_ID).tid <= tid_z;
                            if addsub_grants(PRODUCER_ID).granted = '1' then
                                granted_z <= '1';
                            end if;
                        else
                            state <= WAITING;
                        end if;
                        
                        -- Capture results even while requesting (results may arrive early)
                        if addsub_results(PRODUCER_ID).valid = '1' then
                            if addsub_results(PRODUCER_ID).tid = tid_x and result_x_valid = '0' then
                                result_x <= addsub_results(PRODUCER_ID).data;
                                result_x_valid <= '1';
                            elsif addsub_results(PRODUCER_ID).tid = tid_y and result_y_valid = '0' then
                                result_y <= addsub_results(PRODUCER_ID).data;
                                result_y_valid <= '1';
                            elsif addsub_results(PRODUCER_ID).tid = tid_z and result_z_valid = '0' then
                                result_z <= addsub_results(PRODUCER_ID).data;
                                result_z_valid <= '1';
                            end if;
                        end if;
                        
                        -- Check if done (all requests granted AND all results received)
                        if granted_x = '1' and granted_y = '1' and granted_z = '1' and
                           result_x_valid = '1' and result_y_valid = '1' and result_z_valid = '1' then
                            valid_out <= '1';
                            state <= IDLE;
                        end if;
                    
                    when WAITING =>
                        -- Stop requesting
                        addsub_requests(PRODUCER_ID).valid <= '0';
                        
                        -- Capture results by matching TID
                        if addsub_results(PRODUCER_ID).valid = '1' then
                            if addsub_results(PRODUCER_ID).tid = tid_x then
                                result_x <= addsub_results(PRODUCER_ID).data;
                                result_x_valid <= '1';
                            elsif addsub_results(PRODUCER_ID).tid = tid_y then
                                result_y <= addsub_results(PRODUCER_ID).data;
                                result_y_valid <= '1';
                            elsif addsub_results(PRODUCER_ID).tid = tid_z then
                                result_z <= addsub_results(PRODUCER_ID).data;
                                result_z_valid <= '1';
                            end if;
                        end if;
                        
                        -- When all results are ready, assert valid_out
                        if result_x_valid = '1' and result_y_valid = '1' and result_z_valid = '1' then
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
