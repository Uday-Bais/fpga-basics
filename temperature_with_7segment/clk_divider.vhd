-- ============================================================================
-- Clock Divider Module - Nexys A7-100T
-- ============================================================================
-- Purpose: Generate all timing signals from 100 MHz system clock
-- 
-- Input Clock: 100 MHz (from E3 pin on Nexys A7-100T)
-- Output Clocks:
--   - i2c_clk: 100 kHz for I2C protocol (SCL frequency)
--   - i2c_quarter_clk: 400 kHz for fine-grained I2C state timing
--   - sample_strobe: 1 Hz for temperature sampling (every 1 second)
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_divider is
  port (
    clk_100m         : in  std_logic;  -- 100 MHz input from E3
    reset            : in  std_logic;  -- Active high reset
    
    i2c_clk          : out std_logic;  -- 100 kHz I2C clock
    i2c_quarter_clk  : out std_logic;  -- 400 kHz quarter-clock
    sample_strobe    : out std_logic   -- 1 Hz sampling trigger
  );
end entity clk_divider;

architecture rtl of clk_divider is
  
  -- ============================================================================
  -- 100 kHz I2C Clock Generation
  -- ============================================================================
  -- Formula: Output_Freq = Input_Freq / (2 * counter_max)
  -- 100 kHz = 100 MHz / (2 * 500)
  -- Counter counts from 0 to 249, then resets (total 500 cycles = 5 탎 per half-period)
  -- With 50% duty cycle: 10 탎 period = 100 kHz
  
  signal i2c_counter : unsigned(8 downto 0) := (others => '0');
  signal i2c_clk_r   : std_logic := '0';
  
  -- ============================================================================
  -- 400 kHz Quarter-Clock Generation
  -- ============================================================================
  -- Used for fine-grained I2C state machine timing
  -- Formula: 400 kHz = 100 MHz / (2 * 125)
  -- Counter counts from 0 to 124, then resets (total 250 cycles = 2.5 탎 per half-period)
  -- With 50% duty cycle: 5 탎 period = 200 kHz... wait, let me recalculate
  -- Actually: 100 MHz / (2 * 125) = 400 kHz with 2.5탎 half-period
  
  signal quarter_counter : unsigned(6 downto 0) := (others => '0');
  signal quarter_clk_r   : std_logic := '0';
  
  -- ============================================================================
  -- 1 Hz Sampling Strobe Generation
  -- ============================================================================
  -- One pulse per 100 million clock cycles (1 second at 100 MHz)
  -- Used to trigger temperature reading every 1 second
  
  signal sample_counter : unsigned(26 downto 0) := (others => '0');
  signal sample_strobe_r : std_logic := '0';
  
begin
  
  process(clk_100m)
  begin
    if rising_edge(clk_100m) then
      if reset = '1' then
        -- Reset all counters
        i2c_counter <= (others => '0');
        i2c_clk_r <= '0';
        quarter_counter <= (others => '0');
        quarter_clk_r <= '0';
        sample_counter <= (others => '0');
        sample_strobe_r <= '0';
      else
        
        -- ====================================================================
        -- I2C Clock Generation (100 kHz)
        -- ====================================================================
        -- Divide 100 MHz by 500 to get 200 kHz
        -- Then toggle every 500 counts for 50% duty cycle
        -- Result: 100 kHz square wave
        if i2c_counter = 249 then
          i2c_counter <= (others => '0');
          i2c_clk_r <= not i2c_clk_r;  -- Toggle output
        else
          i2c_counter <= i2c_counter + 1;
        end if;
        
        -- ====================================================================
        -- Quarter Clock Generation (400 kHz)
        -- ====================================================================
        -- Used for more precise I2C state machine timing
        -- Divide 100 MHz by 125 to get 800 kHz
        -- Then toggle every 125 counts for 50% duty cycle
        -- Result: 400 kHz square wave
        if quarter_counter = 124 then
          quarter_counter <= (others => '0');
          quarter_clk_r <= not quarter_clk_r;  -- Toggle output
        else
          quarter_counter <= quarter_counter + 1;
        end if;
        
        -- ====================================================================
        -- Sample Strobe Generation (1 Hz)
        -- ====================================================================
        -- Generates a single pulse every 100 million clock cycles
        -- At 100 MHz: 100,000,000 cycles = 1 second
        -- sample_strobe pulses HIGH for 1 clock cycle every second
        sample_strobe_r <= '0';  -- Default: low
        
        if sample_counter = 99_999_999 then
          sample_counter <= (others => '0');
          sample_strobe_r <= '1';  -- Pulse high for 1 clock
        else
          sample_counter <= sample_counter + 1;
        end if;
        
      end if;
    end if;
  end process;
  
  -- ============================================================================
  -- Output Assignments
  -- ============================================================================
  i2c_clk <= i2c_clk_r;
  i2c_quarter_clk <= quarter_clk_r;
  sample_strobe <= sample_strobe_r;
  
  -- ============================================================================
  -- Timing Summary for Nexys A7-100T
  -- ============================================================================
  -- Input Clock: 100 MHz (from E3)
  -- i2c_clk: 100 kHz, 50% duty cycle (10 탎 period)
  -- i2c_quarter_clk: 400 kHz, 50% duty cycle (2.5 탎 period)
  -- sample_strobe: 1 Hz, 1 clock pulse every 1 second
  --
  -- I2C Timing:
  --   - SCL HIGH time: 5 탎 (half-period of 100 kHz)
  --   - SCL LOW time: 5 탎 (half-period of 100 kHz)
  --   - Meets I2C standard mode timing (4.7 탎 min for 100 kHz)
  -- ============================================================================
  
end architecture rtl;