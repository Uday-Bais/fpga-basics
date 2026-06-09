library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seg7 is
    Port ( clk_100MHz : in STD_LOGIC;
           temp_data  : in STD_LOGIC_VECTOR (7 downto 0);
           SEG        : out STD_LOGIC_VECTOR (6 downto 0);
           NAN        : out STD_LOGIC_VECTOR (3 downto 0) := "1111";
           AN         : out STD_LOGIC_VECTOR (3 downto 0));
end seg7;

architecture Behavioral of seg7 is
    signal tens : integer range 0 to 255;
    signal ones : integer range 0 to 255;
    signal anode_select : unsigned(1 downto 0) := "00";
    signal anode_timer : unsigned(16 downto 0) := (others => '0');
    signal temp_int : integer;

    constant ZERO  : std_logic_vector(6 downto 0) := "0000001";
    constant ONE   : std_logic_vector(6 downto 0) := "1001111";
    constant TWO   : std_logic_vector(6 downto 0) := "0010010";
    constant THREE : std_logic_vector(6 downto 0) := "0000110";
    constant FOUR  : std_logic_vector(6 downto 0) := "1001100";
    constant FIVE  : std_logic_vector(6 downto 0) := "0100100";
    constant SIX   : std_logic_vector(6 downto 0) := "0100000";
    constant SEVEN : std_logic_vector(6 downto 0) := "0001111";
    constant EIGHT : std_logic_vector(6 downto 0) := "0000000";
    constant NINE  : std_logic_vector(6 downto 0) := "0000100";
    constant DEG   : std_logic_vector(6 downto 0) := "0011100";
    constant C_char: std_logic_vector(6 downto 0) := "0110001";

begin
    temp_int <= to_integer(unsigned(temp_data));
    tens <= temp_int / 10;
    ones <= temp_int mod 10;
    NAN <= "1111";

    process(clk_100MHz)
    begin
        if rising_edge(clk_100MHz) then
            if anode_timer = 99999 then
                anode_timer <= (others => '0');
                anode_select <= anode_select + 1;
            else
                anode_timer <= anode_timer + 1;
            end if;
        end if;
    end process;

    process(anode_select)
    begin
        case anode_select is
            when "00" => AN <= "1110";
            when "01" => AN <= "1101";
            when "10" => AN <= "1011";
            when "11" => AN <= "0111";
            when others => AN <= "1111";
        end case;
    end process;

    process(anode_select, ones, tens)
    begin
        case anode_select is
            when "00" => SEG <= C_char;
            when "01" => SEG <= DEG;
            when "10" => 
                case ones is
                    when 0 => SEG <= ZERO;
                    when 1 => SEG <= ONE;
                    when 2 => SEG <= TWO;
                    when 3 => SEG <= THREE;
                    when 4 => SEG <= FOUR;
                    when 5 => SEG <= FIVE;
                    when 6 => SEG <= SIX;
                    when 7 => SEG <= SEVEN;
                    when 8 => SEG <= EIGHT;
                    when 9 => SEG <= NINE;
                    when others => SEG <= ZERO;
                end case;
            when "11" => 
                case tens is
                    when 0 => SEG <= ZERO;
                    when 1 => SEG <= ONE;
                    when 2 => SEG <= TWO;
                    when 3 => SEG <= THREE;
                    when 4 => SEG <= FOUR;
                    when 5 => SEG <= FIVE;
                    when 6 => SEG <= SIX;
                    when 7 => SEG <= SEVEN;
                    when 8 => SEG <= EIGHT;
                    when 9 => SEG <= NINE;
                    when others => SEG <= ZERO;
                end case;
            when others => SEG <= ZERO;
        end case;
    end process;

end Behavioral;