-- ============================================================================
-- Top-Level Module - Temperature Logger System
-- ============================================================================
-- Purpose: Integrates all components for complete temperature logging
-- Features:
--   - Samples temperature every 1 second
--   - Sends formatted data via UART at 9600 baud
--   - Manages I2C communication with ADT7420 sensor at pins C14/C15
--   - UART TX on pin C4
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_module is
  port (
    clk_100m         : in  std_logic;  -- E3: 100 MHz system clock
    reset_button     : in  std_logic;  -- N17: Reset button (BTNC - center)
    
    -- I2C Bus (open-drain)
    sda              : inout std_logic;  -- C15: SDA line to ADT7420
    scl              : inout std_logic;  -- C14: SCL line to ADT7420
    
    -- UART Output
    uart_tx          : out std_logic    -- C4: TX to PC
  );
end entity top_module;

architecture rtl of top_module is
  
  component clk_divider is
    port (
      clk_100m         : in  std_logic;
      reset            : in  std_logic;
      i2c_clk          : out std_logic;
      i2c_quarter_clk  : out std_logic;
      sample_strobe    : out std_logic
    );
  end component clk_divider;
  
  component adt7420_interface is
    port (
      clk_100m         : in  std_logic;
      i2c_clk          : in  std_logic;
      i2c_quarter_clk  : in  std_logic;
      reset            : in  std_logic;
      sda_in           : in  std_logic;
      scl_in           : in  std_logic;
      sda_out          : out std_logic;
      scl_out          : out std_logic;
      read_enable      : in  std_logic;
      sensor_busy      : out std_logic;
      sensor_done      : out std_logic;
      temp_raw         : out std_logic_vector(15 downto 0);
      temp_valid       : out std_logic
    );
  end component adt7420_interface;
  
  component temperature_processor is
    port (
      clk_100m         : in  std_logic;
      reset            : in  std_logic;
      temp_raw         : in  std_logic_vector(15 downto 0);
      temp_valid       : in  std_logic;
      temp_integer     : out std_logic_vector(7 downto 0);
      temp_fractional  : out std_logic_vector(3 downto 0);
      is_negative      : out std_logic;
      temp_ascii       : out std_logic_vector(47 downto 0);
      ascii_valid      : out std_logic
    );
  end component temperature_processor;
  
  component uart_transmitter is
    port (
      clk_100m         : in  std_logic;
      reset            : in  std_logic;
      temp_int         : in  std_logic_vector(7 downto 0);
      temp_frac        : in  std_logic_vector(3 downto 0);
      send_enable      : in  std_logic;
      uart_tx          : out std_logic;
      uart_busy        : out std_logic;
      uart_done        : out std_logic
    );
  end component uart_transmitter;
  
  -- Internal signals
  signal i2c_clk : std_logic;
  signal i2c_quarter_clk : std_logic;
  signal sample_strobe : std_logic;
  signal reset : std_logic;
  
  signal sda_out, scl_out : std_logic;
  signal sda_in, scl_in : std_logic;
  
  signal sensor_read_enable : std_logic;
  signal sensor_busy : std_logic;
  signal sensor_done : std_logic;
  signal temp_raw : std_logic_vector(15 downto 0);
  signal temp_valid : std_logic;
  
  signal temp_integer : std_logic_vector(7 downto 0);
  signal temp_fractional : std_logic_vector(3 downto 0);
  signal is_negative : std_logic;
  signal ascii_valid : std_logic;
  
  signal uart_send_enable : std_logic;
  signal uart_busy : std_logic;
  signal uart_done : std_logic;
  
  type system_state is (
    IDLE,
    WAIT_FOR_SAMPLE,
    TRIGGER_I2C_READ,
    WAIT_I2C_DONE,
    WAIT_FOR_UART,
    TRIGGER_UART_SEND,
    WAIT_UART_DONE
  );
  
  signal state : system_state := IDLE;
  
begin
  
  reset <= not reset_button;
  
  clk_div_inst : clk_divider
    port map (
      clk_100m        => clk_100m,
      reset           => reset,
      i2c_clk         => i2c_clk,
      i2c_quarter_clk => i2c_quarter_clk,
      sample_strobe   => sample_strobe
    );
  
  sensor_inst : adt7420_interface
    port map (
      clk_100m        => clk_100m,
      i2c_clk         => i2c_clk,
      i2c_quarter_clk => i2c_quarter_clk,
      reset           => reset,
      sda_in          => sda_in,
      scl_in          => scl_in,
      sda_out         => sda_out,
      scl_out         => scl_out,
      read_enable     => sensor_read_enable,
      sensor_busy     => sensor_busy,
      sensor_done     => sensor_done,
      temp_raw        => temp_raw,
      temp_valid      => temp_valid
    );
  
  processor_inst : temperature_processor
    port map (
      clk_100m        => clk_100m,
      reset           => reset,
      temp_raw        => temp_raw,
      temp_valid      => temp_valid,
      temp_integer    => temp_integer,
      temp_fractional => temp_fractional,
      is_negative     => is_negative,
      temp_ascii      => open,
      ascii_valid     => ascii_valid
    );
  
  uart_inst : uart_transmitter
    port map (
      clk_100m        => clk_100m,
      reset           => reset,
      temp_int        => temp_integer,
      temp_frac       => temp_fractional,
      send_enable     => uart_send_enable,
      uart_tx         => uart_tx,
      uart_busy       => uart_busy,
      uart_done       => uart_done
    );
  
  sda <= '0' when sda_out = '0' else 'Z';
  scl <= '0' when scl_out = '0' else 'Z';
  sda_in <= sda;
  scl_in <= scl;
  
  process(clk_100m)
  begin
    if rising_edge(clk_100m) then
      if reset = '1' then
        state <= IDLE;
        sensor_read_enable <= '0';
        uart_send_enable <= '0';
      else
        
        sensor_read_enable <= '0';
        uart_send_enable <= '0';
        
        case state is
          
          when IDLE =>
            if sample_strobe = '1' then
              state <= TRIGGER_I2C_READ;
            end if;
          
          when TRIGGER_I2C_READ =>
            sensor_read_enable <= '1';
            state <= WAIT_I2C_DONE;
          
          when WAIT_I2C_DONE =>
            if sensor_done = '1' then
              state <= WAIT_FOR_UART;
            end if;
          
          when WAIT_FOR_UART =>
            if ascii_valid = '1' then
              state <= TRIGGER_UART_SEND;
            end if;
          
          when TRIGGER_UART_SEND =>
            uart_send_enable <= '1';
            state <= WAIT_UART_DONE;
          
          when WAIT_UART_DONE =>
            if uart_done = '1' then
              state <= IDLE;
            end if;
          
          when others =>
            state <= IDLE;
          
        end case;
      end if;
    end if;
  end process;
  
end architecture rtl;