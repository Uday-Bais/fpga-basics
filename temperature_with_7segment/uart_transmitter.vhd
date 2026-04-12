-- ============================================================================
-- UART Transmitter Module - Nexys A7-100T
-- ============================================================================
-- Purpose: Send temperature data to PC via UART serial interface
-- Pin: C4 (UART_TXD_IN - FPGA output to PC)
-- Baud rate: 9600, 8 data bits, 1 stop bit, no parity
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_transmitter is
  port (
    clk_100m         : in  std_logic;  -- 100 MHz system clock
    reset            : in  std_logic;
    
    -- Temperature data input (from temperature_processor)
    temp_int         : in  std_logic_vector(7 downto 0);   -- Integer part
    temp_frac        : in  std_logic_vector(3 downto 0);   -- Fractional part
    send_enable      : in  std_logic;  -- Trigger UART transmission
    
    -- UART output
    uart_tx          : out std_logic;  -- Serial TX line to PC (C4)
    uart_busy        : out std_logic;  -- Transmission in progress
    uart_done        : out std_logic   -- Transmission complete (pulse)
  );
end entity uart_transmitter;

architecture rtl of uart_transmitter is
  
  constant BAUD_COUNTER_MAX : integer := 10416;
  
  type uart_state is (
    IDLE,
    START_BIT,
    DATA_BIT_0, DATA_BIT_1, DATA_BIT_2, DATA_BIT_3,
    DATA_BIT_4, DATA_BIT_5, DATA_BIT_6, DATA_BIT_7,
    STOP_BIT
  );
  
  signal state : uart_state := IDLE;
  signal baud_counter : unsigned(13 downto 0);
  signal bit_data : std_logic_vector(7 downto 0);
  signal char_index : unsigned(3 downto 0);
  signal uart_tx_r : std_logic;
  signal uart_busy_r : std_logic;
  signal uart_done_r : std_logic;
  
  type char_array is array(0 to 14) of std_logic_vector(7 downto 0);
  
  function format_temperature(int_val : std_logic_vector(7 downto 0);
                              frac_val : std_logic_vector(3 downto 0))
    return char_array is
    variable result : char_array;
    variable int_tens, int_ones : integer;
    variable frac_decimal : integer;
    variable frac_tens, frac_ones : integer;
  begin
    int_tens := to_integer(unsigned(int_val)) / 10;
    int_ones := to_integer(unsigned(int_val)) mod 10;
    frac_decimal := (to_integer(unsigned(frac_val)) * 625) / 10000;
    frac_tens := frac_decimal / 10;
    frac_ones := frac_decimal mod 10;
    
    result(0)  := x"54";  -- 'T'
    result(1)  := x"65";  -- 'e'
    result(2)  := x"6D";  -- 'm'
    result(3)  := x"70";  -- 'p'
    result(4)  := x"3A";  -- ':'
    result(5)  := x"20";  -- ' '
    result(6)  := std_logic_vector(to_unsigned(48 + int_tens, 8));
    result(7)  := std_logic_vector(to_unsigned(48 + int_ones, 8));
    result(8)  := x"2E";  -- '.'
    result(9)  := std_logic_vector(to_unsigned(48 + frac_tens, 8));
    result(10) := std_logic_vector(to_unsigned(48 + frac_ones, 8));
    result(11) := x"20";  -- ' '
    result(12) := x"43";  -- 'C'
    result(13) := x"0D";  -- '\r'
    result(14) := x"0A";  -- '\n'
    
    return result;
  end function format_temperature;
  
begin
  
  process(clk_100m)
    variable char_array_v : char_array;
  begin
    if rising_edge(clk_100m) then
      if reset = '1' then
        state <= IDLE;
        baud_counter <= (others => '0');
        uart_tx_r <= '1';
        uart_busy_r <= '0';
        uart_done_r <= '0';
        char_index <= (others => '0');
        bit_data <= (others => '0');
      else
        
        uart_done_r <= '0';
        
        case state is
          
          when IDLE =>
            uart_tx_r <= '1';
            uart_busy_r <= '0';
            if send_enable = '1' then
              char_array_v := format_temperature(temp_int, temp_frac);
              bit_data <= char_array_v(0);
              char_index <= (others => '0');
              state <= START_BIT;
              uart_busy_r <= '1';
            end if;
          
          when START_BIT =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(0);
              state <= DATA_BIT_0;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= '0';
            end if;
          
          when DATA_BIT_0 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(1);
              state <= DATA_BIT_1;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(0);
            end if;
          
          when DATA_BIT_1 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(2);
              state <= DATA_BIT_2;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(1);
            end if;
          
          when DATA_BIT_2 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(3);
              state <= DATA_BIT_3;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(2);
            end if;
          
          when DATA_BIT_3 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(4);
              state <= DATA_BIT_4;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(3);
            end if;
          
          when DATA_BIT_4 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(5);
              state <= DATA_BIT_5;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(4);
            end if;
          
          when DATA_BIT_5 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(6);
              state <= DATA_BIT_6;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(5);
            end if;
          
          when DATA_BIT_6 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= bit_data(7);
              state <= DATA_BIT_7;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(6);
            end if;
          
          when DATA_BIT_7 =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              uart_tx_r <= '1';
              state <= STOP_BIT;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= bit_data(7);
            end if;
          
          when STOP_BIT =>
            if baud_counter = BAUD_COUNTER_MAX then
              baud_counter <= (others => '0');
              
              if char_index < 14 then
                char_index <= char_index + 1;
                char_array_v := format_temperature(temp_int, temp_frac);
                bit_data <= char_array_v(to_integer(char_index + 1));
                state <= START_BIT;
              else
                state <= IDLE;
                uart_busy_r <= '0';
                uart_done_r <= '1';
              end if;
            else
              baud_counter <= baud_counter + 1;
              uart_tx_r <= '1';
            end if;
          
        end case;
      end if;
    end if;
  end process;
  
  uart_tx <= uart_tx_r;
  uart_busy <= uart_busy_r;
  uart_done <= uart_done_r;
  
end architecture rtl;