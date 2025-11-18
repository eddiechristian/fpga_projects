library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port (
        clk : in STD_LOGIC;
        RST:  in  std_logic;  -- Reset button
        BTNU:  in std_logic;
        BTNC:  in std_logic;
        BTND:  in std_logic;
        BTNL:  in std_logic;
        BTNR:  in std_logic;
        led : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top_module;

architecture Behavioral of top_module is
    type State_Type is (START, ONE, TWO);

   
     -- Component declarations
    component debouncer
        Generic(
            DEBNC_CLOCKS : integer;
            PORT_WIDTH : integer);
        Port(
            SIGNAL_I : in std_logic_vector(4 downto 0);
            CLK_I : in std_logic;          
            SIGNAL_O : out std_logic_vector(4 downto 0)
        );
    end component;

      

 -- Signals
    signal btnReg : std_logic_vector (4 downto 0) := "00000";
    signal btnReg_prev : std_logic_vector(4 downto 0) := "00000";
    signal btnDeBnc : std_logic_vector(4 downto 0);
    signal led_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal led_out : unsigned(7 downto 0) := b"00000001";
    signal led_high_nibble : unsigned(3 downto 0) := b"1000";
    signal led_low_nibble : unsigned(3 downto 0) := b"0001";
    signal sig_clk_out: std_logic:='0';
    signal sig_clk_out_prev: std_logic:='0';
    signal CurrentState : State_Type := START;
    signal counter : integer range 0 to 100000000 := 0;
    signal led_state1_out : unsigned(7 downto 0) := b"00000001";
begin
   
    -- Debounce buttons
    Inst_btn_debounce: debouncer 
        generic map(
            DEBNC_CLOCKS => (2**16),
            PORT_WIDTH => 5)
        port map(
            SIGNAL_I => BTNU & BTNC & BTND & BTNL & BTNR,
            CLK_I => clk,
            SIGNAL_O => btnDeBnc
        );
    
    -- Register debounced buttons and detect button press
    btn_reg_process : process (clk)
    begin
        if (rising_edge(clk)) then
            btnReg <= btnDeBnc(4 downto 0);
            btnReg_prev <= btnReg;
            
            -- Detect button press (rising edge) and update LEDs
            --for i in 0 to 4 loop
            --    if btnReg(i) = '1' and btnReg_prev(i) = '0' then
            --        led_reg <= "000" & btnReg;
            --    end if;
            --end loop;

        end if;
    end process;
    
    

    -- Main process: handles state machine and LED updates
    main_process : process(clk)
    begin
        if rising_edge(clk) then
            -- State machine: only changes on button press
            if btnReg(4) = '1' and btnReg_prev(4) = '0' then
                case CurrentState is
                    when START => CurrentState <= ONE;
                    when ONE => CurrentState <= TWO;
                    when TWO => CurrentState <= START;
                end case;
            end if;
            
            -- Counter for LED updates
            if counter = 100_000_000 - 1 then
                counter <= 0;
                -- LED updates: happen every 1 second (100M cycles at 100 MHz)
                case CurrentState is
                    when START =>
                        led_out <= rotate_left(led_state1_out, 1);
                        led_state1_out <= rotate_left(led_state1_out, 1);
                    when ONE =>
                        led_high_nibble <= rotate_right(led_high_nibble, 1);
                        led_low_nibble <= rotate_left(led_low_nibble, 1);
                        led_out <= led_high_nibble & led_high_nibble;
                    when TWO =>
                        led_out <= rotate_right(led_state1_out, 1);
                        led_state1_out <= rotate_right(led_state1_out, 1);

                end case;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    -- Map counter bits to LEDs for a simple blinker
    led <= std_logic_vector(led_out);

end Behavioral;
