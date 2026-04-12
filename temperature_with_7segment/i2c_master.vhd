-- ============================================================================
-- I2C Master Controller - Nexys A7-100T
-- ============================================================================
-- Purpose: Implements complete I2C protocol for ADT7420 sensor communication
-- Pins: SDA = C15, SCL = C14 (to ADT7420 at address 0x48)
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master is
  port (
    clk_100m         : in  std_logic;  -- 100 MHz system clock (E3)
    i2c_clk          : in  std_logic;  -- 100 kHz I2C clock
    i2c_quarter_clk  : in  std_logic;  -- 400 kHz quarter-clock
    reset            : in  std_logic;  -- Active high reset
    
    -- I2C Bus (open-drain: '0' drives low, 'Z' releases to pull-up)
    sda_in           : in  std_logic;  -- SDA line input (with external pull-up)
    scl_in           : in  std_logic;  -- SCL line input (with external pull-up)
    sda_out          : out std_logic;  -- SDA line output ('0' or 'Z')
    scl_out          : out std_logic;  -- SCL line output ('0' or 'Z')
    
    -- Control Interface
    start_i2c        : in  std_logic;  -- Trigger I2C transaction
    i2c_busy         : out std_logic;  -- Transaction in progress
    i2c_done         : out std_logic;  -- Transaction complete (pulse)
    
    -- Data Interface
    data_valid       : out std_logic;  -- Data ready flag (pulse)
    byte_1           : out std_logic_vector(7 downto 0);  -- MSB
    byte_2           : out std_logic_vector(7 downto 0)   -- LSB
  );
end entity i2c_master;

architecture rtl of i2c_master is
  
  type i2c_state is (
    IDLE, START, WRITE_ADDR, WRITE_ADDR_ACK, WRITE_REG, WRITE_REG_ACK,
    RESTART, READ_ADDR, READ_ADDR_ACK, READ_BYTE1, READ_BYTE1_ACK,
    READ_BYTE2, READ_BYTE2_NACK, STOP
  );
  
  signal state : i2c_state := IDLE;
  signal bit_count : unsigned(2 downto 0);
  signal shift_reg : std_logic_vector(7 downto 0);
  signal byte1_r, byte2_r : std_logic_vector(7 downto 0);
  signal sda_out_r, scl_out_r : std_logic;
  signal i2c_busy_r : std_logic;
  signal i2c_done_r : std_logic;
  signal data_valid_r : std_logic;
  
begin
  
  process(clk_100m)
  begin
    if rising_edge(clk_100m) then
      if reset = '1' then
        state <= IDLE;
        bit_count <= (others => '0');
        shift_reg <= (others => '0');
        byte1_r <= (others => '0');
        byte2_r <= (others => '0');
        sda_out_r <= 'Z';
        scl_out_r <= 'Z';
        i2c_busy_r <= '0';
        i2c_done_r <= '0';
        data_valid_r <= '0';
      else
        
        i2c_done_r <= '0';
        data_valid_r <= '0';
        
        case state is
          
          when IDLE =>
            sda_out_r <= 'Z';
            scl_out_r <= 'Z';
            i2c_busy_r <= '0';
            if start_i2c = '1' then
              state <= START;
              i2c_busy_r <= '1';
            end if;
          
          when START =>
            if i2c_clk = '0' then
              scl_out_r <= 'Z';
              sda_out_r <= '0';
              state <= WRITE_ADDR;
              bit_count <= (others => '0');
              shift_reg <= x"90";
            end if;
          
          when WRITE_ADDR =>
            if i2c_clk = '0' then
              if bit_count < 8 then
                sda_out_r <= not shift_reg(7);
                bit_count <= bit_count + 1;
                shift_reg <= shift_reg(6 downto 0) & '0';
              else
                sda_out_r <= 'Z';
                state <= WRITE_ADDR_ACK;
                bit_count <= (others => '0');
              end if;
            end if;
          
          when WRITE_ADDR_ACK =>
            if i2c_clk = '0' then
              if sda_in = '0' then
                shift_reg <= x"00";
                state <= WRITE_REG;
                bit_count <= (others => '0');
              end if;
            end if;
          
          when WRITE_REG =>
            if i2c_clk = '0' then
              if bit_count < 8 then
                sda_out_r <= not shift_reg(7);
                bit_count <= bit_count + 1;
                shift_reg <= shift_reg(6 downto 0) & '0';
              else
                sda_out_r <= 'Z';
                state <= WRITE_REG_ACK;
                bit_count <= (others => '0');
              end if;
            end if;
          
          when WRITE_REG_ACK =>
            if i2c_clk = '0' then
              if sda_in = '0' then
                state <= RESTART;
              end if;
            end if;
          
          when RESTART =>
            if i2c_clk = '0' then
              scl_out_r <= 'Z';
              if scl_in = '1' then
                sda_out_r <= '0';
                state <= READ_ADDR;
                bit_count <= (others => '0');
                shift_reg <= x"91";
              end if;
            end if;
          
          when READ_ADDR =>
            if i2c_clk = '0' then
              if bit_count < 8 then
                sda_out_r <= not shift_reg(7);
                bit_count <= bit_count + 1;
                shift_reg <= shift_reg(6 downto 0) & '0';
              else
                sda_out_r <= 'Z';
                state <= READ_ADDR_ACK;
                bit_count <= (others => '0');
              end if;
            end if;
          
          when READ_ADDR_ACK =>
            if i2c_clk = '0' then
              if sda_in = '0' then
                state <= READ_BYTE1;
                bit_count <= (others => '0');
                shift_reg <= (others => '0');
              end if;
            end if;
          
          when READ_BYTE1 =>
            if i2c_clk = '1' then
              if bit_count < 8 then
                shift_reg <= shift_reg(6 downto 0) & sda_in;
                bit_count <= bit_count + 1;
              else
                byte1_r <= shift_reg;
                state <= READ_BYTE1_ACK;
                bit_count <= (others => '0');
              end if;
            end if;
          
          when READ_BYTE1_ACK =>
            if i2c_clk = '0' then
              sda_out_r <= '0';
              state <= READ_BYTE2;
              bit_count <= (others => '0');
              shift_reg <= (others => '0');
            end if;
          
          when READ_BYTE2 =>
            if i2c_clk = '1' then
              if bit_count < 8 then
                shift_reg <= shift_reg(6 downto 0) & sda_in;
                bit_count <= bit_count + 1;
              else
                byte2_r <= shift_reg;
                state <= READ_BYTE2_NACK;
                bit_count <= (others => '0');
              end if;
            end if;
          
          when READ_BYTE2_NACK =>
            if i2c_clk = '0' then
              sda_out_r <= 'Z';
              state <= STOP;
            end if;
          
          when STOP =>
            if i2c_clk = '0' then
              scl_out_r <= 'Z';
              if scl_in = '1' then
                sda_out_r <= 'Z';
                state <= IDLE;
                i2c_busy_r <= '0';
                i2c_done_r <= '1';
                data_valid_r <= '1';
              end if;
            end if;
          
        end case;
      end if;
    end if;
  end process;
  
  sda_out <= sda_out_r;
  scl_out <= scl_out_r;
  i2c_busy <= i2c_busy_r;
  i2c_done <= i2c_done_r;
  data_valid <= data_valid_r;
  byte_1 <= byte1_r;
  byte_2 <= byte2_r;
  
end architecture rtl;