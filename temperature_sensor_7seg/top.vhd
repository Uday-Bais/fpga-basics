library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is
    Port ( CLK100MHZ : in STD_LOGIC;
           reset     : in STD_LOGIC;
           TMP_SDA   : inout STD_LOGIC;
           TMP_SCL   : inout STD_LOGIC;
           SEG       : out STD_LOGIC_VECTOR (6 downto 0);
           AN        : out STD_LOGIC_VECTOR (3 downto 0);
           NAN       : out STD_LOGIC_VECTOR (3 downto 0);
           LED       : out STD_LOGIC_VECTOR (7 downto 0));
end top;

architecture Behavioral of top is

    signal w_200kHz : std_logic;
    signal w_data   : std_logic_vector(7 downto 0);
    signal sda_dir  : std_logic;

    component i2c_master
        Port ( clk_200kHz : in STD_LOGIC;
               reset      : in STD_LOGIC;
               SDA        : inout STD_LOGIC;
               temp_data  : out STD_LOGIC_VECTOR(7 downto 0);
               SDA_dir    : out STD_LOGIC;
               SCL        : out STD_LOGIC);
    end component;

    component clkgen_200kHz
        Port ( clk_100MHz : in STD_LOGIC;
               clk_200kHz : out STD_LOGIC);
    end component;

    component seg7
        Port ( clk_100MHz : in STD_LOGIC;
               temp_data  : in STD_LOGIC_VECTOR (7 downto 0);
               SEG        : out STD_LOGIC_VECTOR (6 downto 0);
               NAN        : out STD_LOGIC_VECTOR (3 downto 0);
               AN         : out STD_LOGIC_VECTOR (3 downto 0));
    end component;

begin
    master: i2c_master port map (
        clk_200kHz => w_200kHz,
        reset      => reset,
        SDA        => TMP_SDA,
        temp_data  => w_data,
        SDA_dir    => sda_dir,
        SCL        => TMP_SCL
    );

    cgen: clkgen_200kHz port map (
        clk_100MHz => CLK100MHZ,
        clk_200kHz => w_200kHz
    );

    seg_inst: seg7 port map (
        clk_100MHz => CLK100MHZ,
        temp_data  => w_data,
        SEG        => SEG,
        NAN        => NAN,
        AN         => AN
    );

    LED <= w_data;

end Behavioral;