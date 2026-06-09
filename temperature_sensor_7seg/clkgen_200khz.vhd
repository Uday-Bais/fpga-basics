library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clkgen_200kHz is
    Port ( clk_100MHz : in STD_LOGIC;
           clk_200kHz : out STD_LOGIC);
end clkgen_200kHz;

architecture Behavioral of clkgen_200kHz is
    signal counter : unsigned(7 downto 0) := (others => '0');
    signal clk_reg : std_logic := '1';
begin
    process(clk_100MHz)
    begin
        if rising_edge(clk_100MHz) then
            if counter = 249 then
                counter <= (others => '0');
                clk_reg <= not clk_reg;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    clk_200kHz <= clk_reg;
end Behavioral;