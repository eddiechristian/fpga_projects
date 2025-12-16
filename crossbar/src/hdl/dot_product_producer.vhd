library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;

-- Dot product producer that uses crossbar FP resources
-- Computes: result = a.x*b.x + a.y*b.y + a.z*b.z
-- 
-- Unlike vec3_dot_hw which has dedicated FP units, this producer
-- shares FP resources through the crossbar with other producers.
-- 
-- State machine:
--   IDLE      : Wait for start signal
--   MULT_XYZ  : Request 3 multiplications
--   WAIT_MULT : Wait for all 3 MULT results
--   ADD_XY    : Request addition of x*x + y*y
--   WAIT_ADD1 : Wait for first ADD result
--   ADD_Z     : Request addition of (x*x+y*y) + z*z
--   WAIT_ADD2 : Wait for final result
--   DONE      : Assert done signal

entity dot_product_producer is
    generic (
        PRODUCER_ID : integer := 0
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Control interface
        start       : in  std_logic;
        done        : out std_logic;
        
        -- Input vectors (3 components each)
        a_x, a_y, a_z : in std_logic_vector(31 downto 0);
        b_x, b_y, b_z : in std_logic_vector(31 downto 0);
        
        -- Output
        result      : out std_logic_vector(31 downto 0);
        result_valid : out std_logic;
        
        -- Crossbar interface
        request     : out producer_request_t;
        grant       : in  producer_grant_t;
        prod_result : in  producer_result_t
    );
end entity dot_product_producer;

architecture behavioral of dot_product_producer is

    type state_t is (IDLE, MULT_X, MULT_Y, MULT_Z, WAIT_MULT, 
                     ADD_XY, WAIT_ADD1, ADD_Z, WAIT_ADD2, COMPLETE);
    signal state : state_t := IDLE;
    
    -- Operation counters for TID generation
    signal op_counter : unsigned(10 downto 0) := (others => '0');
    
    -- Storage for intermediate results
    signal mult_x_result : std_logic_vector(31 downto 0);
    signal mult_y_result : std_logic_vector(31 downto 0);
    signal mult_z_result : std_logic_vector(31 downto 0);
    signal add_xy_result : std_logic_vector(31 downto 0);
    
    -- Flags for received results
    signal mult_x_received : std_logic := '0';
    signal mult_y_received : std_logic := '0';
    signal mult_z_received : std_logic := '0';
    signal add_xy_received : std_logic := '0';
    
    -- TID tracking
    signal tid_mult_x : std_logic_vector(15 downto 0);
    signal tid_mult_y : std_logic_vector(15 downto 0);
    signal tid_mult_z : std_logic_vector(15 downto 0);
    signal tid_add_xy : std_logic_vector(15 downto 0);
    signal tid_add_z  : std_logic_vector(15 downto 0);

begin

    -- Main state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                request <= init_producer_request;
                done <= '0';
                result_valid <= '0';
                op_counter <= (others => '0');
                mult_x_received <= '0';
                mult_y_received <= '0';
                mult_z_received <= '0';
                add_xy_received <= '0';
                
            else
                -- Default: no request
                request.valid <= '0';
                done <= '0';
                result_valid <= '0';
                
                case state is
                    when IDLE =>
                        if start = '1' then
                            state <= MULT_X;
                            mult_x_received <= '0';
                            mult_y_received <= '0';
                            mult_z_received <= '0';
                            add_xy_received <= '0';
                        end if;
                    
                    when MULT_X =>
                        -- Request X multiplication
                        request.valid <= '1';
                        request.unit_type <= UNIT_MULT;
                        request.unit_index <= 0;  -- Try unit 0 first
                        request.data(31 downto 0) <= a_x;
                        request.data(63 downto 32) <= b_x;
                        tid_mult_x <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        request.tid <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        
                        if grant.granted = '1' then
                            report "DOT_PROD: MULT_X granted, TID=" & integer'image(to_integer(unsigned(tid_mult_x))) 
                                   & " op_counter=" & integer'image(to_integer(op_counter));
                            op_counter <= op_counter + 1;
                            state <= MULT_Y;
                        end if;
                    
                    when MULT_Y =>
                        -- Request Y multiplication
                        request.valid <= '1';
                        request.unit_type <= UNIT_MULT;
                        request.unit_index <= 1;  -- Try unit 1
                        request.data(31 downto 0) <= a_y;
                        request.data(63 downto 32) <= b_y;
                        tid_mult_y <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        request.tid <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        
                        if grant.granted = '1' then
                            report "DOT_PROD: MULT_Y granted, TID=" & integer'image(to_integer(unsigned(tid_mult_y)))
                                   & " op_counter=" & integer'image(to_integer(op_counter));
                            op_counter <= op_counter + 1;
                            state <= MULT_Z;
                        end if;
                    
                    when MULT_Z =>
                        -- Request Z multiplication
                        request.valid <= '1';
                        request.unit_type <= UNIT_MULT;
                        request.unit_index <= 2;  -- Try unit 2
                        request.data(31 downto 0) <= a_z;
                        request.data(63 downto 32) <= b_z;
                        tid_mult_z <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        request.tid <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        
                        if grant.granted = '1' then
                            report "DOT_PROD: MULT_Z granted, TID=" & integer'image(to_integer(unsigned(tid_mult_z)))
                                   & " op_counter=" & integer'image(to_integer(op_counter));
                            op_counter <= op_counter + 1;
                            state <= WAIT_MULT;
                        end if;
                    
                    when WAIT_MULT =>
                        -- Wait for all 3 MULT results
                        if mult_x_received = '1' and mult_y_received = '1' and mult_z_received = '1' then
                            state <= ADD_XY;
                        end if;
                    
                    when ADD_XY =>
                        -- Request addition of X + Y results
                        request.valid <= '1';
                        request.unit_type <= UNIT_ADDSUB;
                        request.unit_index <= 0;
                        request.data(31 downto 0) <= mult_x_result;
                        request.data(63 downto 32) <= mult_y_result;
                        request.data(64) <= '0';  -- ADD operation
                        tid_add_xy <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        request.tid <= tid_add_xy;
                        
                        if grant.granted = '1' then
                            op_counter <= op_counter + 1;
                            state <= WAIT_ADD1;
                        end if;
                    
                    when WAIT_ADD1 =>
                        -- Wait for first ADD result
                        if add_xy_received = '1' then
                            state <= ADD_Z;
                        end if;
                    
                    when ADD_Z =>
                        -- Request addition of (X+Y) + Z
                        request.valid <= '1';
                        request.unit_type <= UNIT_ADDSUB;
                        request.unit_index <= 0;
                        request.data(31 downto 0) <= add_xy_result;
                        request.data(63 downto 32) <= mult_z_result;
                        request.data(64) <= '0';  -- ADD operation
                        tid_add_z <= make_tid(PRODUCER_ID, to_integer(op_counter));
                        request.tid <= tid_add_z;
                        
                        if grant.granted = '1' then
                            op_counter <= op_counter + 1;
                            state <= WAIT_ADD2;
                        end if;
                    
                    when WAIT_ADD2 =>
                        -- Final result received in result capture process
                        if prod_result.valid = '1' and prod_result.tid = tid_add_z then
                            result <= prod_result.data;
                            result_valid <= '1';
                            state <= COMPLETE;
                        end if;
                    
                    when COMPLETE =>
                        done <= '1';
                        result_valid <= '0';
                        if start = '0' then
                            state <= IDLE;
                        end if;
                        
                end case;
                
                -- Result capture process (runs in parallel with state machine)
                if prod_result.valid = '1' then
                    report "DOT_PROD: Received result TID=" & integer'image(to_integer(unsigned(prod_result.tid)))
                           & " Expected: X=" & integer'image(to_integer(unsigned(tid_mult_x)))
                           & " Y=" & integer'image(to_integer(unsigned(tid_mult_y)))
                           & " Z=" & integer'image(to_integer(unsigned(tid_mult_z)));
                    if prod_result.tid = tid_mult_x then
                        mult_x_result <= prod_result.data;
                        mult_x_received <= '1';
                        report "DOT_PROD: MULT_X result captured";
                    elsif prod_result.tid = tid_mult_y then
                        mult_y_result <= prod_result.data;
                        mult_y_received <= '1';
                        report "DOT_PROD: MULT_Y result captured";
                    elsif prod_result.tid = tid_mult_z then
                        mult_z_result <= prod_result.data;
                        mult_z_received <= '1';
                        report "DOT_PROD: MULT_Z result captured";
                    elsif prod_result.tid = tid_add_xy then
                        add_xy_result <= prod_result.data;
                        add_xy_received <= '1';
                        report "DOT_PROD: ADD_XY result captured";
                    end if;
                end if;
                
            end if;
        end if;
    end process;

end architecture behavioral;
