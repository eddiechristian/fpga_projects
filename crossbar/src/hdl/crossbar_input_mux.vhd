library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.crossbar_pkg.all;

entity crossbar_input_mux is
    Port (
        -- Producer data inputs (one array per unit type)
        mult_requests   : in producer_mult_request_array_t;
        fma_requests    : in producer_fma_request_array_t;
        addsub_requests : in producer_addsub_request_array_t;
        
        -- Mux select signals from arbiter
        mult_mux_sel    : in grant_vector_mult_t;
        fma_mux_sel     : in grant_vector_fma_t;
        addsub_mux_sel  : in grant_vector_addsub_t;
        
        -- FP unit outputs
        mult_inputs     : out fp_mult_input_array_t;
        fma_inputs      : out fp_fma_input_array_t;
        addsub_inputs   : out fp_addsub_input_array_t
    );
end crossbar_input_mux;

architecture Behavioral of crossbar_input_mux is

begin

    -- MULT unit input multiplexing
    process(mult_requests, mult_mux_sel)
        variable sel_prod : integer;
    begin
        for unit in 0 to NUM_MULT_UNITS-1 loop
            sel_prod := mult_mux_sel(unit);
            
            if sel_prod >= 0 and sel_prod < NUM_PRODUCERS then
                -- Valid producer selected
                mult_inputs(unit).valid <= mult_requests(sel_prod).valid;
                mult_inputs(unit).data <= mult_requests(sel_prod).data;
                mult_inputs(unit).tid <= mult_requests(sel_prod).tid;
            else
                -- No producer selected (unit idle)
                mult_inputs(unit).valid <= '0';
                mult_inputs(unit).data <= (others => '0');
                mult_inputs(unit).tid <= (others => '0');
            end if;
        end loop;
    end process;
    
    -- FMA unit input multiplexing
    process(fma_requests, fma_mux_sel)
        variable sel_prod : integer;
    begin
        for unit in 0 to NUM_FMA_UNITS-1 loop
            sel_prod := fma_mux_sel(unit);
            
            if sel_prod >= 0 and sel_prod < NUM_PRODUCERS then
                -- Valid producer selected
                fma_inputs(unit).valid <= fma_requests(sel_prod).valid;
                fma_inputs(unit).data <= fma_requests(sel_prod).data;
                fma_inputs(unit).tid <= fma_requests(sel_prod).tid;
            else
                -- No producer selected (unit idle)
                fma_inputs(unit).valid <= '0';
                fma_inputs(unit).data <= (others => '0');
                fma_inputs(unit).tid <= (others => '0');
            end if;
        end loop;
    end process;
    
    -- ADDSUB unit input multiplexing
    process(addsub_requests, addsub_mux_sel)
        variable sel_prod : integer;
    begin
        for unit in 0 to NUM_ADDSUB_UNITS-1 loop
            sel_prod := addsub_mux_sel(unit);
            
            if sel_prod >= 0 and sel_prod < NUM_PRODUCERS then
                -- Valid producer selected
                addsub_inputs(unit).valid <= addsub_requests(sel_prod).valid;
                addsub_inputs(unit).data <= addsub_requests(sel_prod).data;
                addsub_inputs(unit).tid <= addsub_requests(sel_prod).tid;
            else
                -- No producer selected (unit idle)
                addsub_inputs(unit).valid <= '0';
                addsub_inputs(unit).data <= (others => '0');
                addsub_inputs(unit).tid <= (others => '0');
            end if;
        end loop;
    end process;

end Behavioral;
