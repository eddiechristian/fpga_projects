library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;

entity crossbar_arbiter is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        
        -- Producer requests (one array per unit type)
        mult_requests   : in producer_mult_request_array_t;
        fma_requests    : in producer_fma_request_array_t;
        addsub_requests : in producer_addsub_request_array_t;
        
        -- Producer grants
        prod_grants     : out producer_grant_array_t;
        
        -- Mux select signals for input multiplexers
        mult_mux_sel    : out grant_vector_mult_t;
        fma_mux_sel     : out grant_vector_fma_t;
        addsub_mux_sel  : out grant_vector_addsub_t
    );
end crossbar_arbiter;

architecture Behavioral of crossbar_arbiter is

    -- Priority pointers for round-robin arbitration (one per FP unit)
    signal mult_priority    : integer range 0 to NUM_PRODUCERS-1 := 0;
    signal fma_priority     : integer range 0 to NUM_PRODUCERS-1 := 0;
    signal addsub_priority  : integer range 0 to NUM_PRODUCERS-1 := 0;
    
    -- Priority pointer arrays (one per FP unit of each type)
    type priority_array_mult_t is array (0 to NUM_MULT_UNITS-1) of integer range 0 to NUM_PRODUCERS-1;
    type priority_array_fma_t is array (0 to NUM_FMA_UNITS-1) of integer range 0 to NUM_PRODUCERS-1;
    type priority_array_addsub_t is array (0 to NUM_ADDSUB_UNITS-1) of integer range 0 to NUM_PRODUCERS-1;
    
    signal mult_priorities      : priority_array_mult_t := (others => 0);
    signal fma_priorities       : priority_array_fma_t := (others => 0);
    signal addsub_priorities    : priority_array_addsub_t := (others => 0);
    
    -- Request matrices (decoded from producer requests)
    signal req_mult     : request_matrix_mult_t;
    signal req_fma      : request_matrix_fma_t;
    signal req_addsub   : request_matrix_addsub_t;
    
    -- Grant vectors (internal)
    signal grant_mult_int   : grant_vector_mult_t;
    signal grant_fma_int    : grant_vector_fma_t;
    signal grant_addsub_int : grant_vector_addsub_t;

begin

    -- Decode producer requests into request matrices (now simpler with separate arrays)
    process(mult_requests, fma_requests, addsub_requests)
    begin
        -- Initialize all requests to 0
        req_mult <= (others => (others => '0'));
        req_fma <= (others => (others => '0'));
        req_addsub <= (others => (others => '0'));
        
        -- Decode MULT requests
        for i in 0 to NUM_PRODUCERS-1 loop
            if mult_requests(i).valid = '1' and mult_requests(i).unit_index < NUM_MULT_UNITS then
                req_mult(i, mult_requests(i).unit_index) <= '1';
            end if;
        end loop;
        
        -- Decode FMA requests
        for i in 0 to NUM_PRODUCERS-1 loop
            if fma_requests(i).valid = '1' and fma_requests(i).unit_index < NUM_FMA_UNITS then
                req_fma(i, fma_requests(i).unit_index) <= '1';
            end if;
        end loop;
        
        -- Decode ADDSUB requests
        for i in 0 to NUM_PRODUCERS-1 loop
            if addsub_requests(i).valid = '1' and addsub_requests(i).unit_index < NUM_ADDSUB_UNITS then
                req_addsub(i, addsub_requests(i).unit_index) <= '1';
            end if;
        end loop;
    end process;
    
    -- Round-robin arbitration for MULT units
    process(req_mult, mult_priorities)
        variable winner : integer;
        variable found : boolean;
    begin
        grant_mult_int <= (others => -1);  -- Default: no grants
        
        for unit in 0 to NUM_MULT_UNITS-1 loop
            found := false;
            -- Scan from priority pointer onwards
            for offset in 0 to NUM_PRODUCERS-1 loop
                winner := (mult_priorities(unit) + offset) mod NUM_PRODUCERS;
                if req_mult(winner, unit) = '1' and not found then
                    grant_mult_int(unit) <= winner;
                    found := true;
                end if;
            end loop;
        end loop;
    end process;
    
    -- Round-robin arbitration for FMA units
    process(req_fma, fma_priorities)
        variable winner : integer;
        variable found : boolean;
    begin
        grant_fma_int <= (others => -1);  -- Default: no grants
        
        for unit in 0 to NUM_FMA_UNITS-1 loop
            found := false;
            -- Scan from priority pointer onwards
            for offset in 0 to NUM_PRODUCERS-1 loop
                winner := (fma_priorities(unit) + offset) mod NUM_PRODUCERS;
                if req_fma(winner, unit) = '1' and not found then
                    grant_fma_int(unit) <= winner;
                    found := true;
                end if;
            end loop;
        end loop;
    end process;
    
    -- Round-robin arbitration for ADDSUB units
    process(req_addsub, addsub_priorities)
        variable winner : integer;
        variable found : boolean;
    begin
        grant_addsub_int <= (others => -1);  -- Default: no grants
        
        for unit in 0 to NUM_ADDSUB_UNITS-1 loop
            found := false;
            -- Scan from priority pointer onwards
            for offset in 0 to NUM_PRODUCERS-1 loop
                winner := (addsub_priorities(unit) + offset) mod NUM_PRODUCERS;
                if req_addsub(winner, unit) = '1' and not found then
                    grant_addsub_int(unit) <= winner;
                    found := true;
                end if;
            end loop;
        end loop;
    end process;
    
    -- Update priority pointers on clock edge
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset all priority pointers
                mult_priorities <= (others => 0);
                fma_priorities <= (others => 0);
                addsub_priorities <= (others => 0);
            else
                -- Update MULT priority pointers
                for unit in 0 to NUM_MULT_UNITS-1 loop
                    if grant_mult_int(unit) /= -1 then
                        -- Grant was made, update priority to next producer
                        mult_priorities(unit) <= (grant_mult_int(unit) + 1) mod NUM_PRODUCERS;
                    end if;
                end loop;
                
                -- Update FMA priority pointers
                for unit in 0 to NUM_FMA_UNITS-1 loop
                    if grant_fma_int(unit) /= -1 then
                        fma_priorities(unit) <= (grant_fma_int(unit) + 1) mod NUM_PRODUCERS;
                    end if;
                end loop;
                
                -- Update ADDSUB priority pointers
                for unit in 0 to NUM_ADDSUB_UNITS-1 loop
                    if grant_addsub_int(unit) /= -1 then
                        addsub_priorities(unit) <= (grant_addsub_int(unit) + 1) mod NUM_PRODUCERS;
                    end if;
                end loop;
            end if;
        end if;
    end process;
    
    -- Generate producer grant outputs (reverse mapping from grant vectors)
    process(grant_mult_int, grant_fma_int, grant_addsub_int)
    begin
        -- Default: no grants
        for i in 0 to NUM_PRODUCERS-1 loop
            prod_grants(i).granted <= '0';
            prod_grants(i).unit_type <= UNIT_MULT;
            prod_grants(i).unit_index <= 0;
        end loop;
        
        -- Check MULT grants
        for unit in 0 to NUM_MULT_UNITS-1 loop
            if grant_mult_int(unit) /= -1 then
                prod_grants(grant_mult_int(unit)).granted <= '1';
                prod_grants(grant_mult_int(unit)).unit_type <= UNIT_MULT;
                prod_grants(grant_mult_int(unit)).unit_index <= unit;
            end if;
        end loop;
        
        -- Check FMA grants
        for unit in 0 to NUM_FMA_UNITS-1 loop
            if grant_fma_int(unit) /= -1 then
                prod_grants(grant_fma_int(unit)).granted <= '1';
                prod_grants(grant_fma_int(unit)).unit_type <= UNIT_FMA;
                prod_grants(grant_fma_int(unit)).unit_index <= unit;
            end if;
        end loop;
        
        -- Check ADDSUB grants
        for unit in 0 to NUM_ADDSUB_UNITS-1 loop
            if grant_addsub_int(unit) /= -1 then
                prod_grants(grant_addsub_int(unit)).granted <= '1';
                prod_grants(grant_addsub_int(unit)).unit_type <= UNIT_ADDSUB;
                prod_grants(grant_addsub_int(unit)).unit_index <= unit;
            end if;
        end loop;
    end process;
    
    -- Output mux select signals (direct connection)
    mult_mux_sel <= grant_mult_int;
    fma_mux_sel <= grant_fma_int;
    addsub_mux_sel <= grant_addsub_int;

end Behavioral;
