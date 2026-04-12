-- ============================================================================
-- ADT7420 Temperature Sensor Interface - Nexys A7-100T
-- ============================================================================
-- Purpose: Wrapper around I2C master for ADT7420-specific operations
-- 
-- Sensor Details:
--   - Address: 0x48 (default, Nexys A7-100T configuration)
--   - Register: 0x00 (temperature, read-only)
--   - Data Format: 16-bit (MSB + LSB)
--   - Resolution: 0.0625°C per LSB (13-bit mode, default)
--   - Range: -40°C to +125°C
--   - Format: Two's complement
-- 
-- Pins: SDA = C15, SCL = C14 (pre-routed on board)
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adt7420_interface is
  port (
    clk_100m         : in  std_logic;  -- 100 MHz system clock
    i2c_clk          : in  std_logic;  -- 100 kHz I2C clock
    i2c_quarter_clk  : in  std_logic;  -- 400 kHz quarter-clock
    reset            : in  std_logic;  -- Active high reset
    
    -- I2C Bus
    sda_in           : in  std_logic;  -- From C15 (with pull-up)
    scl_in           : in  std_logic;  -- From C14 (with pull-up)
    sda_out          : out std_logic;  -- To C15 (open-drain)
    scl_out          : out std_logic;  -- To C14 (open-drain)
    
    -- Control Interface
    read_enable      : in  std_logic;  -- Trigger temperature read
    sensor_busy      : out std_logic;  -- Read in progress
    sensor_done      : out std_logic;  -- Read complete (pulse)
    
    -- Data Output
    temp_raw         : out std_logic_vector(15 downto 0);  -- 16-bit raw value
    temp_valid       : out std_logic   -- Data valid flag (pulse)
  );
end entity adt7420_interface;

architecture rtl of adt7420_interface is
  
  -- ============================================================================
  -- I2C Master Component
  -- ============================================================================
  component i2c_master is
    port (
      clk_100m         : in  std_logic;
      i2c_clk          : in  std_logic;
      i2c_quarter_clk  : in  std_logic;
      reset            : in  std_logic;
      sda_in           : in  std_logic;
      scl_in           : in  std_logic;
      sda_out          : out std_logic;
      scl_out          : out std_logic;
      start_i2c        : in  std_logic;
      i2c_busy         : out std_logic;
      i2c_done         : out std_logic;
      data_valid       : out std_logic;
      byte_1           : out std_logic_vector(7 downto 0);
      byte_2           : out std_logic_vector(7 downto 0)
    );
  end component i2c_master;
  
  -- Internal signals
  signal i2c_busy_internal : std_logic;
  signal i2c_done_internal : std_logic;
  signal data_valid_internal : std_logic;
  signal byte_1_internal : std_logic_vector(7 downto 0);
  signal byte_2_internal : std_logic_vector(7 downto 0);
  signal temp_raw_r : std_logic_vector(15 downto 0);
  signal temp_valid_r : std_logic;
  
begin
  
  -- ============================================================================
  -- Instantiate I2C Master Module
  -- ============================================================================
  -- Handles all I2C protocol communication with ADT7420
  i2c_inst : i2c_master
    port map (
      clk_100m        => clk_100m,
      i2c_clk         => i2c_clk,
      i2c_quarter_clk => i2c_quarter_clk,
      reset           => reset,
      sda_in          => sda_in,      -- From C15
      scl_in          => scl_in,      -- From C14
      sda_out         => sda_out,     -- To C15 (open-drain)
      scl_out         => scl_out,     -- To C14 (open-drain)
      start_i2c       => read_enable,
      i2c_busy        => i2c_busy_internal,
      i2c_done        => i2c_done_internal,
      data_valid      => data_valid_internal,
      byte_1          => byte_1_internal,  -- MSB (temperature integer)
      byte_2          => byte_2_internal   -- LSB (temperature fractional)
    );
  
  -- ============================================================================
  -- Data Assembly Process
  -- ============================================================================
  -- Combines MSB and LSB into 16-bit raw temperature value
  process(clk_100m)
  begin
    if rising_edge(clk_100m) then
      if reset = '1' then
        temp_raw_r <= (others => '0');
        temp_valid_r <= '0';
      else
        temp_valid_r <= '0';
        
        -- When I2C master finishes with valid data
        if data_valid_internal = '1' then
          -- Combine MSB and LSB into 16-bit value
          -- MSB contains sign bit and upper temperature bits
          -- LSB contains lower temperature bits and fractional part
          temp_raw_r <= byte_1_internal & byte_2_internal;
          temp_valid_r <= '1';  -- Pulse valid flag
        end if;
      end if;
    end if;
  end process;
  
  -- ============================================================================
  -- Output Assignments
  -- ============================================================================
  sensor_busy <= i2c_busy_internal;
  sensor_done <= i2c_done_internal;
  temp_raw <= temp_raw_r;
  temp_valid <= temp_valid_r;
  
  -- ============================================================================
  -- ADT7420 Data Format Reference
  -- ============================================================================
  -- Register 0x00 (Temperature):
  -- 
  -- Byte 1 (MSB):                    Byte 2 (LSB):
  -- ???????????????????????????????? ????????????????????????????????
  -- ? Bit 7  ? Bits 6-0             ? ? Bits 7-4 ? Bits 3-0          ?
  -- ? Sign   ? Integer Part (7 bits)? ? Frac (4)  ? Not Used (4)       ?
  -- ???????????????????????????????? ????????????????????????????????
  --
  -- Example: Temperature = 25.50°C
  --   MSB = 0x19 (00011001 binary)
  --     Bit 7 = 0 (positive)
  --     Bits 6-0 = 0011001 (25 decimal)
  --   LSB = 0x80 (10000000 binary)
  --     Bits 7-4 = 1000 (0.50°C = 8/16)
  --
  -- Two's Complement (negative temps):
  --   -25.50°C would be encoded as two's complement of 25.50
  -- ============================================================================
  
end architecture rtl;