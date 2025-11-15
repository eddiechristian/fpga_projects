library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    Generic (
        CLK_FREQ    : integer := 100_000_000;  -- System clock frequency in Hz
        I2C_FREQ    : integer := 100_000        -- I2C clock frequency in Hz
    );
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- Control interface
        start       : in  std_logic;            -- Start transaction
        stop        : in  std_logic;            -- Generate stop condition
        write_data  : in  std_logic_vector(7 downto 0);
        read_data   : out std_logic_vector(7 downto 0);
        ack_out     : out std_logic;            -- ACK received from slave
        busy        : out std_logic;
        -- I2C bus
        scl         : inout std_logic;
        sda         : inout std_logic
    );
end i2c_master;

architecture Behavioral of i2c_master is
    -- I2C clock divider
    constant DIVIDER : integer := CLK_FREQ / (I2C_FREQ * 4);
    
    type state_type is (IDLE, START_COND, SEND_BIT, ACK_BIT, STOP_COND);
    signal state : state_type := IDLE;
    
    signal clk_div      : integer range 0 to DIVIDER := 0;
    signal i2c_clk_en   : std_logic := '0';
    signal i2c_phase    : integer range 0 to 3 := 0;  -- 4 phases per bit
    
    signal scl_out      : std_logic := '1';
    signal sda_out      : std_logic := '1';
    signal sda_in       : std_logic;
    
    signal bit_count    : integer range 0 to 7 := 0;
    signal shift_reg    : std_logic_vector(7 downto 0) := (others => '0');
    
    signal busy_int     : std_logic := '0';

begin
    -- Tri-state control
    scl <= '0' when scl_out = '0' else 'Z';
    sda <= '0' when sda_out = '0' else 'Z';
    sda_in <= sda;
    
    busy <= busy_int;
    
    -- I2C clock divider
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                clk_div <= 0;
                i2c_clk_en <= '0';
            else
                if clk_div = DIVIDER - 1 then
                    clk_div <= 0;
                    i2c_clk_en <= '1';
                else
                    clk_div <= clk_div + 1;
                    i2c_clk_en <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- I2C state machine
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                scl_out <= '1';
                sda_out <= '1';
                busy_int <= '0';
                bit_count <= 0;
                i2c_phase <= 0;
                ack_out <= '0';
            else
                if i2c_clk_en = '1' then
                    case state is
                        when IDLE =>
                            scl_out <= '1';
                            sda_out <= '1';
                            busy_int <= '0';
                            bit_count <= 0;
                            i2c_phase <= 0;
                            
                            if start = '1' then
                                shift_reg <= write_data;
                                state <= START_COND;
                                busy_int <= '1';
                            end if;
                        
                        when START_COND =>
                            case i2c_phase is
                                when 0 =>
                                    sda_out <= '1';
                                    scl_out <= '1';
                                    i2c_phase <= 1;
                                when 1 =>
                                    sda_out <= '0';  -- Start: SDA falls while SCL high
                                    scl_out <= '1';
                                    i2c_phase <= 2;
                                when 2 =>
                                    sda_out <= '0';
                                    scl_out <= '1';
                                    i2c_phase <= 3;
                                when 3 =>
                                    scl_out <= '0';
                                    sda_out <= '0';
                                    i2c_phase <= 0;
                                    state <= SEND_BIT;
                                    bit_count <= 7;
                                when others =>
                                    i2c_phase <= 0;
                            end case;
                        
                        when SEND_BIT =>
                            case i2c_phase is
                                when 0 =>
                                    scl_out <= '0';
                                    sda_out <= shift_reg(bit_count);
                                    i2c_phase <= 1;
                                when 1 =>
                                    scl_out <= '1';  -- Clock high
                                    i2c_phase <= 2;
                                when 2 =>
                                    scl_out <= '1';
                                    i2c_phase <= 3;
                                when 3 =>
                                    scl_out <= '0';
                                    i2c_phase <= 0;
                                    
                                    if bit_count = 0 then
                                        state <= ACK_BIT;
                                    else
                                        bit_count <= bit_count - 1;
                                    end if;
                                when others =>
                                    i2c_phase <= 0;
                            end case;
                        
                        when ACK_BIT =>
                            case i2c_phase is
                                when 0 =>
                                    scl_out <= '0';
                                    sda_out <= '1';  -- Release SDA
                                    i2c_phase <= 1;
                                when 1 =>
                                    scl_out <= '1';  -- Clock high
                                    i2c_phase <= 2;
                                when 2 =>
                                    scl_out <= '1';
                                    ack_out <= not sda_in;  -- Read ACK (0 = ACK)
                                    i2c_phase <= 3;
                                when 3 =>
                                    scl_out <= '0';
                                    i2c_phase <= 0;
                                    
                                    if stop = '1' then
                                        state <= STOP_COND;
                                    else
                                        state <= IDLE;
                                    end if;
                                when others =>
                                    i2c_phase <= 0;
                            end case;
                        
                        when STOP_COND =>
                            case i2c_phase is
                                when 0 =>
                                    scl_out <= '0';
                                    sda_out <= '0';
                                    i2c_phase <= 1;
                                when 1 =>
                                    scl_out <= '1';
                                    sda_out <= '0';
                                    i2c_phase <= 2;
                                when 2 =>
                                    scl_out <= '1';
                                    sda_out <= '1';  -- Stop: SDA rises while SCL high
                                    i2c_phase <= 3;
                                when 3 =>
                                    scl_out <= '1';
                                    sda_out <= '1';
                                    i2c_phase <= 0;
                                    state <= IDLE;
                                when others =>
                                    i2c_phase <= 0;
                            end case;
                    end case;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
