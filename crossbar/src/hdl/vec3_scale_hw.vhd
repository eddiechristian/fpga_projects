library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.lin_alg_pkg.all;
use work.crossbar_pkg.all;

-- Hardware Vec3 scalar multiplication using crossbar: result = v * scalar
-- Uses 3 producer slots to request 3 multipliers in parallel
-- 
-- Performance:
--   Latency: ~4 clock cycles (crossbar latency + FP_MULT latency)
--   Throughput: 1 result per cycle when all 3 mults are granted
--   Resource usage: Shares crossbar MULT units
--
-- Producer IDs: Uses PRODUCER_ID_BASE, PRODUCER_ID_BASE+1, PRODUCER_ID_BASE+2
entity vec3_scale_hw is
    generic (
        PRODUCER_ID_BASE : integer range 0 to 28 := 0  -- Base ID (needs 3 consecutive IDs)
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
                mult_requests(PRODUCER_ID_BASE + 0) <= init_producer_mult_request;
                mult_requests(PRODUCER_ID_BASE + 1) <= init_producer_mult_request;
                mult_requests(PRODUCER_ID_BASE + 2) <= init_producer_mult_request;
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
                        mult_requests(PRODUCER_ID_BASE + 0).valid <= '0';
                        mult_requests(PRODUCER_ID_BASE + 1).valid <= '0';
                        mult_requests(PRODUCER_ID_BASE + 2).valid <= '0';
                        
                        if valid_in = '1' then
                            -- Latch inputs
                            v_reg <= v;
                            scalar_reg <= scalar;
                            op_counter <= op_counter + 1;
                            granted_x <= '0';
                            granted_y <= '0';
                            granted_z <= '0';
                            result_x_valid <= '0';
                            result_y_valid <= '0';
                            result_z_valid <= '0';
                            -- Generate TIDs immediately (each component uses its own producer ID)
                            tid_x <= make_tid(PRODUCER_ID_BASE + 0, to_integer(op_counter));
                            tid_y <= make_tid(PRODUCER_ID_BASE + 1, to_integer(op_counter));
                            tid_z <= make_tid(PRODUCER_ID_BASE + 2, to_integer(op_counter));
                            state <= REQUESTING;
                        end if;
                    
                    when REQUESTING =>
                        -- Request X multiplication (if not yet granted)
                        if granted_x = '0' then
                            mult_requests(PRODUCER_ID_BASE + 0).valid <= '1';
                            mult_requests(PRODUCER_ID_BASE + 0).unit_index <= 0;  -- Let arbiter choose
                            mult_requests(PRODUCER_ID_BASE + 0).data(31 downto 0) <= v_reg.x;
                            mult_requests(PRODUCER_ID_BASE + 0).data(63 downto 32) <= scalar_reg;
                            mult_requests(PRODUCER_ID_BASE + 0).tid <= tid_x;
                            
                            if mult_grants(PRODUCER_ID_BASE + 0).granted = '1' then
                                granted_x <= '1';
                            end if;
                        end if;
                        
                        -- Request Y multiplication (if not yet granted)
                        if granted_y = '0' then
                            mult_requests(PRODUCER_ID_BASE + 1).valid <= '1';
                            mult_requests(PRODUCER_ID_BASE + 1).unit_index <= 0;
                            mult_requests(PRODUCER_ID_BASE + 1).data(31 downto 0) <= v_reg.y;
                            mult_requests(PRODUCER_ID_BASE + 1).data(63 downto 32) <= scalar_reg;
                            mult_requests(PRODUCER_ID_BASE + 1).tid <= tid_y;
                            
                            if mult_grants(PRODUCER_ID_BASE + 1).granted = '1' then
                                granted_y <= '1';
                            end if;
                        end if;
                        
                        -- Request Z multiplication (if not yet granted)
                        if granted_z = '0' then
                            mult_requests(PRODUCER_ID_BASE + 2).valid <= '1';
                            mult_requests(PRODUCER_ID_BASE + 2).unit_index <= 0;
                            mult_requests(PRODUCER_ID_BASE + 2).data(31 downto 0) <= v_reg.z;
                            mult_requests(PRODUCER_ID_BASE + 2).data(63 downto 32) <= scalar_reg;
                            mult_requests(PRODUCER_ID_BASE + 2).tid <= tid_z;
                            
                            if mult_grants(PRODUCER_ID_BASE + 2).granted = '1' then
                                granted_z <= '1';
                            end if;
                        end if;
                        
                        -- Move to waiting once all are granted
                        if (granted_x = '1' or mult_grants(PRODUCER_ID_BASE + 0).granted = '1') and
                           (granted_y = '1' or mult_grants(PRODUCER_ID_BASE + 1).granted = '1') and
                           (granted_z = '1' or mult_grants(PRODUCER_ID_BASE + 2).granted = '1') then
                            state <= WAITING;
                        end if;
                    
                    when WAITING =>
                        -- Stop requesting
                        mult_requests(PRODUCER_ID_BASE + 0).valid <= '0';
                        mult_requests(PRODUCER_ID_BASE + 1).valid <= '0';
                        mult_requests(PRODUCER_ID_BASE + 2).valid <= '0';
                        
                        -- Capture X result
                        if mult_results(PRODUCER_ID_BASE + 0).valid = '1' and mult_results(PRODUCER_ID_BASE + 0).tid = tid_x then
                            result_x <= mult_results(PRODUCER_ID_BASE + 0).data;
                            result_x_valid <= '1';
                        end if;
                        
                        -- Capture Y result
                        if mult_results(PRODUCER_ID_BASE + 1).valid = '1' and mult_results(PRODUCER_ID_BASE + 1).tid = tid_y then
                            result_y <= mult_results(PRODUCER_ID_BASE + 1).data;
                            result_y_valid <= '1';
                        end if;
                        
                        -- Capture Z result
                        if mult_results(PRODUCER_ID_BASE + 2).valid = '1' and mult_results(PRODUCER_ID_BASE + 2).tid = tid_z then
                            result_z <= mult_results(PRODUCER_ID_BASE + 2).data;
                            result_z_valid <= '1';
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
