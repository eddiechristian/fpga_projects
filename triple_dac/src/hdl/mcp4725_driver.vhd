library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mcp4725_driver is
    Generic (
        CLK_FREQ    : integer := 100_000_000;
        I2C_FREQ    : integer := 100_000;
        I2C_ADDR    : std_logic_vector(6 downto 0) := "1100000"  -- 0x60 default
    );
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- DAC value input
        dac_value   : in  std_logic_vector(11 downto 0);
        update      : in  std_logic;  -- Pulse to update DAC
        busy        : out std_logic;
        done        : out std_logic;
        -- I2C bus
        scl         : inout std_logic;
        sda         : inout std_logic
    );
end mcp4725_driver;

architecture Behavioral of mcp4725_driver is
    component i2c_master is
        Generic (
            CLK_FREQ    : integer;
            I2C_FREQ    : integer
        );
        Port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            start       : in  std_logic;
            stop        : in  std_logic;
            write_data  : in  std_logic_vector(7 downto 0);
            read_data   : out std_logic_vector(7 downto 0);
            ack_out     : out std_logic;
            busy        : out std_logic;
            scl         : inout std_logic;
            sda         : inout std_logic
        );
    end component;
    
    type state_type is (IDLE, SEND_ADDR, SEND_CMD, SEND_DATA_HIGH, SEND_DATA_LOW, WAIT_DONE);
    signal state : state_type := IDLE;
    
    signal i2c_start    : std_logic := '0';
    signal i2c_stop     : std_logic := '0';
    signal i2c_write    : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_ack      : std_logic;
    signal i2c_busy     : std_logic;
    signal i2c_busy_prev : std_logic := '0';
    
    signal dac_value_reg : std_logic_vector(11 downto 0) := (others => '0');
    signal busy_int     : std_logic := '0';

begin
    busy <= busy_int;
    
    i2c_inst : i2c_master
        generic map (
            CLK_FREQ => CLK_FREQ,
            I2C_FREQ => I2C_FREQ
        )
        port map (
            clk        => clk,
            rst        => rst,
            start      => i2c_start,
            stop       => i2c_stop,
            write_data => i2c_write,
            read_data  => open,
            ack_out    => i2c_ack,
            busy       => i2c_busy,
            scl        => scl,
            sda        => sda
        );
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                i2c_start <= '0';
                i2c_stop <= '0';
                busy_int <= '0';
                done <= '0';
                i2c_busy_prev <= '0';
            else
                i2c_busy_prev <= i2c_busy;
                done <= '0';
                
                case state is
                    when IDLE =>
                        busy_int <= '0';
                        i2c_start <= '0';
                        i2c_stop <= '0';
                        
                        if update = '1' then
                            dac_value_reg <= dac_value;
                            state <= SEND_ADDR;
                            busy_int <= '1';
                        end if;
                    
                    when SEND_ADDR =>
                        -- Send I2C address with write bit (0)
                        i2c_write <= I2C_ADDR & '0';
                        i2c_start <= '1';
                        i2c_stop <= '0';
                        state <= WAIT_DONE;
                        -- Next state will be SEND_CMD after transaction completes
                    
                    when SEND_CMD =>
                        -- Send command byte: Fast mode (C2:C1:C0 = 000, write DAC register)
                        -- PD1:PD0 = 00 (normal mode)
                        -- Format: 0 1 0 0 0 0 0 0 = 0x40
                        i2c_write <= "01000000";
                        i2c_start <= '1';
                        i2c_stop <= '0';
                        state <= WAIT_DONE;
                    
                    when SEND_DATA_HIGH =>
                        -- Send upper 8 bits of 12-bit DAC value
                        i2c_write <= dac_value_reg(11 downto 4);
                        i2c_start <= '1';
                        i2c_stop <= '0';
                        state <= WAIT_DONE;
                    
                    when SEND_DATA_LOW =>
                        -- Send lower 4 bits of DAC value (left-aligned in byte)
                        i2c_write <= dac_value_reg(3 downto 0) & "0000";
                        i2c_start <= '1';
                        i2c_stop <= '1';  -- Generate stop after this byte
                        state <= WAIT_DONE;
                    
                    when WAIT_DONE =>
                        -- Wait for I2C transaction to complete
                        if i2c_busy_prev = '1' and i2c_busy = '0' then
                            i2c_start <= '0';
                            
                            -- Determine next state based on where we came from
                            if i2c_write(7 downto 1) = I2C_ADDR then
                                state <= SEND_CMD;
                            elsif i2c_write = "01000000" then
                                state <= SEND_DATA_HIGH;
                            elsif i2c_write(7 downto 4) = dac_value_reg(11 downto 8) then
                                state <= SEND_DATA_LOW;
                            else
                                -- All bytes sent, return to idle
                                state <= IDLE;
                                busy_int <= '0';
                                done <= '1';
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
