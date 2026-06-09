library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity i2c_master is
    Port ( clk_200kHz : in STD_LOGIC;
           reset      : in STD_LOGIC;
           SDA        : inout STD_LOGIC;
           temp_data  : out STD_LOGIC_VECTOR(7 downto 0);
           SDA_dir    : out STD_LOGIC;
           SCL        : inout STD_LOGIC);
end i2c_master;

architecture Behavioral of i2c_master is

    -- Standard I2C Addresses for ADT7420
    constant ADDR_W : std_logic_vector(7 downto 0) := "10010110"; -- 0x4B + Write (0) = 0x96
    constant ADDR_R : std_logic_vector(7 downto 0) := "10010111"; -- 0x4B + Read  (1) = 0x97
    constant REG_00 : std_logic_vector(7 downto 0) := "00000000"; -- Temperature Register

    type state_type is (
        IDLE, START, SEND_ADDR_W, ACK1, SEND_REG, ACK2,
        REP_START_SETUP, REP_START, SEND_ADDR_R, ACK3,
        READ_MSB, ACK4, READ_LSB, NACK_STATE, STOP_SETUP, STOP, PAUSE
    );
    
    signal state : state_type := IDLE;
    
    -- 4-phase clock enable for I2C timing control
    signal clk_en : unsigned(1 downto 0) := "00";
    
    -- Internal signals for open-drain driving
    signal sda_int : std_logic := '1';
    signal scl_int : std_logic := '1';
    
    signal bit_cnt : integer range 0 to 7 := 7;
    signal tMSB : std_logic_vector(7 downto 0) := (others => '0');
    signal tLSB : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_data_reg : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Counter to pause between readings (~0.25 seconds at 200kHz)
    signal pause_cnt : integer range 0 to 50000 := 0;

begin

    -- True Open-Drain buffering for I2C lines
    -- When internal signal is '0', pull the line low. 
    -- When '1', set to 'Z' (High Impedance) and let the board's pull-up resistors pull it high.
    SDA <= '0' when sda_int = '0' else 'Z';
    SCL <= '0' when scl_int = '0' else 'Z';
    
    -- Keep SDA_dir assigned for top.vhd compatibility (not strictly needed for actual I/O)
    SDA_dir <= '1' when sda_int = '0' else '0';
    
    temp_data <= temp_data_reg;

    process(clk_200kHz, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            clk_en <= "00";
            sda_int <= '1';
            scl_int <= '1';
            bit_cnt <= 7;
            pause_cnt <= 0;
            temp_data_reg <= (others => '0');
            
        elsif rising_edge(clk_200kHz) then
            clk_en <= clk_en + 1;

            case state is
                when IDLE =>
                    sda_int <= '1';
                    scl_int <= '1';
                    if clk_en = "11" then
                        state <= START;
                    end if;

                when START =>
                    -- SCL is high, drop SDA to signal START
                    if clk_en = "00" then
                        sda_int <= '0';
                    elsif clk_en = "11" then
                        state <= SEND_ADDR_W;
                        bit_cnt <= 7;
                    end if;

                when SEND_ADDR_W =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= ADDR_W(bit_cnt);
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        if bit_cnt = 0 then
                            state <= ACK1;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when ACK1 =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1'; -- Release SDA to listen for ACK
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        state <= SEND_REG;
                        bit_cnt <= 7;
                    end if;

                when SEND_REG =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= REG_00(bit_cnt);
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        if bit_cnt = 0 then
                            state <= ACK2;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when ACK2 =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1'; -- Release SDA to listen for ACK
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        state <= REP_START_SETUP;
                    end if;

                when REP_START_SETUP =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1'; -- SCL low, set SDA high
                    elsif clk_en = "01" then
                        scl_int <= '1'; -- Allow SCL to rise
                    elsif clk_en = "11" then
                        state <= REP_START;
                    end if;

                when REP_START =>
                    -- Drop SDA while SCL is high to signal Repeated START
                    if clk_en = "00" then
                        sda_int <= '0';
                    elsif clk_en = "11" then
                        state <= SEND_ADDR_R;
                        bit_cnt <= 7;
                    end if;

                when SEND_ADDR_R =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= ADDR_R(bit_cnt);
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        if bit_cnt = 0 then
                            state <= ACK3;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when ACK3 =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1'; -- Release SDA to listen
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        state <= READ_MSB;
                        bit_cnt <= 7;
                    end if;

                when READ_MSB =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1'; -- Keep SDA floating to read
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "10" then
                        tMSB(bit_cnt) <= SDA; -- Sample data while SCL is high
                    elsif clk_en = "11" then
                        if bit_cnt = 0 then
                            state <= ACK4;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when ACK4 =>
                    -- Master pulls low to ACK the first byte
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '0';
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        state <= READ_LSB;
                        bit_cnt <= 7;
                    end if;

                when READ_LSB =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1';
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "10" then
                        tLSB(bit_cnt) <= SDA;
                    elsif clk_en = "11" then
                        if bit_cnt = 0 then
                            state <= NACK_STATE;
                        else
                            bit_cnt <= bit_cnt - 1;
                        end if;
                    end if;

                when NACK_STATE =>
                    -- Master lets SDA float high to NACK the final byte
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '1';
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        state <= STOP_SETUP;
                    end if;

                when STOP_SETUP =>
                    if clk_en = "00" then
                        scl_int <= '0';
                        sda_int <= '0';
                    elsif clk_en = "01" then
                        scl_int <= '1';
                    elsif clk_en = "11" then
                        state <= STOP;
                    end if;

                when STOP =>
                    -- Raise SDA while SCL is high to signal STOP
                    if clk_en = "00" then
                        sda_int <= '1'; 
                    elsif clk_en = "11" then
                        state <= PAUSE;
                        
                        -- Latch the data safely 
                        -- ADT7420 format: MSB(6..0) & LSB(7) gives positive integer Temp in Celsius
                        temp_data_reg <= tMSB(6 downto 0) & tLSB(7);
                        pause_cnt <= 0;
                    end if;

                when PAUSE =>
                    if pause_cnt = 50000 then 
                        state <= START;
                    else
                        pause_cnt <= pause_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

end Behavioral;