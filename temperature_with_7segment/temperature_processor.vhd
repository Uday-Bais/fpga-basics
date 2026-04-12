-- ============================================================================
-- Temperature Data Processor - Nexys A7-100T
-- ============================================================================
-- Purpose: Convert raw I2C data from ADT7420 to Celsius temperature
-- 
-- Input: 16-bit raw value from ADT7420 (MSB concatenated with LSB)
-- Output: Integer part, fractional part, and ASCII string
-- 
-- Features:
--   - Two's complement conversion (for negative temperatures)
--   - 13-bit resolution (0.0625°C per LSB)
--   - Range: -40°C to +125°C
--   - Generates ASCII string for UART transmission (6 chars: "sXX.XXC")
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity temperature_processor is
  port (
    clk_100m         : in  std_logic;  -- 100 MHz system clock
    reset            : in  std_logic;
    
    -- Raw temperature data from ADT7420 (via I2C master)
    temp_raw         : in  std_logic_vector(15 downto 0);
    temp_valid       : in  std_logic;  -- Valid data strobe (pulse)
    
    -- Processed temperature output
    temp_integer     : out std_logic_vector(7 downto 0);   -- Integer part (0-125)
    temp_fractional  : out std_logic_vector(3 downto 0);   -- Fractional part (0-15)
    is_negative      : out std_logic;  -- Sign bit (1 = negative)
    
    -- ASCII string output for UART: "sXX.XXC" (6 characters × 8 bits = 48 bits)
    temp_ascii       : out std_logic_vector(47 downto 0);  -- FIXED: 48 bits
    ascii_valid      : out std_logic   -- ASCII string ready (pulse)
  );
end entity temperature_processor;

architecture rtl of temperature_processor is
  
  signal temp_integer_r : std_logic_vector(7 downto 0);
  signal temp_frac_r : std_logic_vector(3 downto 0);
  signal is_negative_r : std_logic;
  signal ascii_valid_r : std_logic;
  signal temp_ascii_r : std_logic_vector(47 downto 0);
  
begin
  
  process(clk_100m)
    variable temp_signed : signed(15 downto 0);
    variable temp_int_val : integer;
    variable temp_frac_val : integer;
    variable abs_temp : integer;
    variable int_tens : integer;
    variable int_ones : integer;
    variable frac_decimal : integer;
    variable frac_tens : integer;
    variable frac_ones : integer;
  begin
    if rising_edge(clk_100m) then
      if reset = '1' then
        temp_integer_r <= (others => '0');
        temp_frac_r <= (others => '0');
        is_negative_r <= '0';
        ascii_valid_r <= '0';
        temp_ascii_r <= (others => '0');
      else
        ascii_valid_r <= '0';
        
        if temp_valid = '1' then
          
          -- Extract Sign Bit (Bit 15)
          if temp_raw(15) = '1' then
            is_negative_r <= '1';
          else
            is_negative_r <= '0';
          end if;
          
          -- Extract Temperature Components
          -- ADT7420 Data Format (13-bit mode):
          --   Bits [15:13]: Sign extension
          --   Bits [12:4]:  Temperature integer part
          --   Bits [3:0]:   Temperature fractional part (0.0625°C per LSB)
          
          temp_int_val := to_integer(signed(temp_raw(15 downto 4)));
          temp_frac_val := to_integer(unsigned(temp_raw(3 downto 0)));
          
          -- Handle Two's Complement for Negative Temperatures
          if temp_raw(15) = '1' then
            temp_signed := signed(temp_raw);
            temp_int_val := to_integer(-temp_signed(15 downto 4));
            -- Fractional part stays positive
          end if;
          
          -- Validate Temperature Range (-40°C to +125°C)
          if temp_int_val > 125 then
            temp_int_val := 125;
            temp_frac_val := 0;
          elsif temp_int_val < -40 then
            temp_int_val := -40;
            temp_frac_val := 0;
          end if;
          
          -- Handle absolute value for output
          if temp_int_val < 0 then
            abs_temp := -temp_int_val;
            is_negative_r <= '1';
          else
            abs_temp := temp_int_val;
            is_negative_r <= '0';
          end if;
          
          -- Store integer and fractional parts
          temp_integer_r <= std_logic_vector(to_unsigned(abs_temp mod 256, 8));
          temp_frac_r <= std_logic_vector(to_unsigned(temp_frac_val, 4));
          
          -- Generate ASCII String (6 characters = 48 bits)
          -- Format: "sXX.XXC" where s is space or minus
          int_tens := abs_temp / 10;
          int_ones := abs_temp mod 10;
          frac_decimal := (temp_frac_val * 625) / 10000;
          frac_tens := frac_decimal / 10;
          frac_ones := frac_decimal mod 10;
          
          if is_negative_r = '1' then
            temp_ascii_r <= 
              x"2D" &  -- '-'
              std_logic_vector(to_unsigned(48 + int_tens, 8)) &
              std_logic_vector(to_unsigned(48 + int_ones, 8)) &
              x"2E" &  -- '.'
              std_logic_vector(to_unsigned(48 + frac_tens, 8)) &
              std_logic_vector(to_unsigned(48 + frac_ones, 8));
          else
            temp_ascii_r <= 
              x"20" &  -- ' '
              std_logic_vector(to_unsigned(48 + int_tens, 8)) &
              std_logic_vector(to_unsigned(48 + int_ones, 8)) &
              x"2E" &  -- '.'
              std_logic_vector(to_unsigned(48 + frac_tens, 8)) &
              std_logic_vector(to_unsigned(48 + frac_ones, 8));
          end if;
          
          ascii_valid_r <= '1';
          
        end if;
      end if;
    end if;
  end process;
  
  temp_integer <= temp_integer_r;
  temp_fractional <= temp_frac_r;
  is_negative <= is_negative_r;
  temp_ascii <= temp_ascii_r;
  ascii_valid <= ascii_valid_r;
  
end architecture rtl;