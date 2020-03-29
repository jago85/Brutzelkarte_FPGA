library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity stx_etx_rcv is
port (
    CLK_I           : in std_logic;
    RESET_I         : in std_logic;
    
    DATA_I          : in std_logic_vector(7 downto 0);
    DATA_VALID_I    : in std_logic;
    
    RECEIVING_O     : out std_logic;
    DATA_VALID_O    : out std_logic
);
end entity stx_etx_rcv;

architecture Behavioral of stx_etx_rcv is

    constant STX : std_logic_vector(7 downto 0) := x"02";
    constant ETX : std_logic_vector(7 downto 0) := x"03";
    constant DLE : std_logic_vector(7 downto 0) := x"10";

    signal received_stx : std_logic := '0';
    signal received_dle : std_logic := '0';

begin

    RECEIVING_O <= received_stx;

    process (CLK_I, RESET_I)
    begin
        if RESET_I = '1' then
            received_stx <= '0';
            received_dle <= '0';
            DATA_VALID_O <= '0';
        elsif rising_edge(CLK_I) then
            
            DATA_VALID_O <= '0';
            
            if (DATA_VALID_I = '1') then
                if (received_dle = '1') then
                    received_dle <= '0';
                    if (DATA_I = STX) then
                        received_stx <= '1';
                    elsif (DATA_I = ETX) then
                        received_stx <= '0';
                    elsif (DATA_I /= DLE) then
                        received_stx <= '0'; --Protocol Error
                    else
                        DATA_VALID_O <= '1';
                    end if;
                else
                    if (DATA_I = DLE) then
                        received_dle <= '1';
                    else
                        if received_stx = '1' then
                            DATA_VALID_O <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
