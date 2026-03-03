library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sevenseg_no_clock is
  port (
    SW  : in  std_logic_vector(15 downto 0);
    CA, CB, CC, CD, CE, CF, CG : out std_logic;
    DP  : out std_logic;
    AN  : out std_logic_vector(7 downto 0)
  );
end entity;
--Signals have a concept of time and events – they can change values
-- over simulation time, and other parts of the code can react to those changes
architecture rtl of sevenseg_no_clock is
  signal segs : std_logic_vector(6 downto 0); -- CA..CG active-low
  signal an_s : std_logic_vector(7 downto 0); -- AN active-low
  signal sel  : unsigned(2 downto 0);
  signal hex  : std_logic_vector(3 downto 0);

  function hex_to_7seg_active_low(h : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(6 downto 0);
  begin
    case h is
      when "0000" => r := "0000001"; -- 0
      when "0001" => r := "1001111"; -- 1
      when "0010" => r := "0010010"; -- 2
      when "0011" => r := "0000110"; -- 3
      when "0100" => r := "1001100"; -- 4
      when "0101" => r := "0100100"; -- 5
      when "0110" => r := "0100000"; -- 6
      when "0111" => r := "0001111"; -- 7
      when "1000" => r := "0000000"; -- 8
      when "1001" => r := "0000100"; -- 9
      when "1010" => r := "0001000"; -- A
      when "1011" => r := "1100000"; -- b
      when "1100" => r := "0110001"; -- C
      when "1101" => r := "1000010"; -- d
      when "1110" => r := "0110000"; -- E
      when others => r := "0111000"; -- F
    end case;
    return r;
  end function;

begin
  sel <= unsigned(SW(2 downto 0)); -- digit select 0..7
  hex <= SW(7 downto 4);          -- value 0..F

  -- digit enable (one-hot, active-low)
  process(sel)
    variable i : integer;
  begin
    an_s <= (others => '1');
    i := to_integer(sel);
    an_s(i) <= '0';
  end process;

  -- segments (active-low)
  segs <= hex_to_7seg_active_low(hex);

  -- outputs
  CA <= segs(6);	
  CB <= segs(5);
  CC <= segs(4);
  CD <= segs(3);
  CE <= segs(2);
  CF <= segs(1);
  CG <= segs(0);

  DP <= '1';      -- decimal point off (active-low)
  AN <= an_s;

end architecture;
