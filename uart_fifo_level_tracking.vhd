library IEEE;
use IEEE.std_logic_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity uart_fifo_level_tracking is
port (
    CLK_I           : in std_logic;
    RST_I           : in std_logic;
    RD_EN_I         : in std_logic;
    WR_EN_I         : in std_logic;
    DATA_I          : in std_logic_vector(7 downto 0);
    Q_O             : out std_logic_vector(7 downto 0);
    EMPTY_O         : out std_logic;
    ALMOST_FULL_O   : out std_logic;
    FULL_O          : out std_logic;
    
    FREE_COUNT_O    : out std_logic_vector(10 downto 0);
    FULL_COUNT_O    : out std_logic_vector(10 downto 0)
);
end entity uart_fifo_level_tracking;

architecture Behavioral of uart_fifo_level_tracking is

    constant FIFO_SIZE : integer := 1024;

    component uart_fifo
        port (Data: in  std_logic_vector(7 downto 0); WrClock: in  std_logic; 
            RdClock: in  std_logic; WrEn: in  std_logic; RdEn: in  std_logic; 
            Reset: in  std_logic; RPReset: in  std_logic; 
            Q: out  std_logic_vector(7 downto 0); Empty: out  std_logic; 
            Full: out  std_logic; AlmostEmpty: out  std_logic; 
            AlmostFull: out  std_logic);
    end component;
    
    signal fill_counter : unsigned(10 downto 0);
    signal fifo_empty : std_logic;
    signal fifo_full : std_logic;
    signal fifo_almost_full : std_logic;

begin

    uart_fifo_inst : uart_fifo
        port map (
            Data(7 downto 0) => DATA_I, 
            WrClock          => CLK_I, 
            RdClock          => CLK_I, 
            WrEn             => WR_EN_I, 
            RdEn             => RD_EN_I, 
            Reset            => RST_I, 
            RPReset          => RST_I, 
            Q(7 downto 0)    => Q_O, 
            Empty            => fifo_empty, 
            Full             => fifo_full, 
            AlmostEmpty      => open, 
            AlmostFull       => fifo_almost_full);
            
    FREE_COUNT_O <= std_logic_vector(to_unsigned(FIFO_SIZE, fill_counter'length) - fill_counter);
    FULL_COUNT_O <= std_logic_vector(fill_counter);
    EMPTY_O <= fifo_empty;
    FULL_O <= fifo_full;
    ALMOST_FULL_O <= fifo_almost_full;
    
    process (CLK_I, RST_I)
    variable tmp : unsigned(10 downto 0);
    begin
        if RST_I = '1' then
            fill_counter <= to_unsigned(0, fill_counter'length);
        elsif rising_edge(CLK_I) then
            tmp := fill_counter;
            
            if WR_EN_I = '1' and fifo_full = '0' then
                tmp := tmp + 1;
            end if;
            
            if RD_EN_I = '1' and fifo_empty = '0' then
                tmp := tmp - 1;
            end if;
            
            fill_counter <= tmp;
            
        end if;
    end process;

end architecture Behavioral;