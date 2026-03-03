----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/09/2026 10:28:47 PM
-- Design Name: 
-- Module Name: full_adder - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity full_adder is
    Port(
        SW : in std_logic_vector(2 downto 0);--3 bit input
        LED : out std_logic_vector(1 downto 0)--2 bit output
    );
end full_adder;

architecture Behavioral of full_adder is

begin
    LED(0) <= (SW(0) xor SW(1)) xor SW(2);
    LED(1) <= (SW(0) and SW(1)) or ((SW(0) xor SW(1)) and SW(2));


end Behavioral;