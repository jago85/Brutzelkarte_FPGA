library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity stx_etx_send is
port (
    CLK_I           : in std_logic;
    RESET_I         : in std_logic;
    
    ACTIVE_I        : in std_logic;
    ACTIVE_O        : out std_logic;
    DATA_I          : in std_logic_vector(7 downto 0);
    DATA_VALID_I    : in std_logic;
    DATA_ACK_O      : out std_logic;
    
    DATA_O          : out std_logic_vector(7 downto 0);
    DATA_VALID_O    : out std_logic;
    DATA_ACK_I      : in std_logic
);
end entity stx_etx_send;

architecture Behavioral of stx_etx_send is

    constant STX : std_logic_vector(7 downto 0) := x"02";
    constant ETX : std_logic_vector(7 downto 0) := x"03";
    constant DLE : std_logic_vector(7 downto 0) := x"10";
    
    type state_t is (
        s_idle,
        s_dle_stx,
        s_stx,
        s_active,
        s_data,
        s_dle_data,
        s_dle_etx,
        s_etx
    );
    
    signal state : state_t;
    
begin

    process (CLK_I, RESET_I)
    begin
        if RESET_I = '1' then
            state <= s_idle;
            ACTIVE_O <= '0';
            DATA_VALID_O <= '0';
            DATA_ACK_O <= '0';
            DATA_O <= (others => '0');
        elsif rising_edge(CLK_I) then
            DATA_ACK_O <= '0';
            
            case state is
            when s_idle =>
                if ACTIVE_I = '1' then
                    ACTIVE_O <= '1';
                    DATA_O <= DLE;
                    DATA_VALID_O <= '1';
                    state <= s_dle_stx;
                end if;
                
            when s_dle_stx =>
                if DATA_ACK_I = '1' then
                    DATA_O <= STX;
                    state <= s_stx;
                end if;
                
            when s_stx =>
                if DATA_ACK_I = '1' then
                    DATA_VALID_O <= '0';
                    state <= s_active;
                end if;
                
            when s_active =>
                if ACTIVE_I = '0' then
                    DATA_O <= DLE;
                    DATA_VALID_O <= '1';
                    ACTIVE_O <= '0';
                    state <= s_dle_etx;
                elsif DATA_VALID_I = '1' then
                    DATA_ACK_O <= '1';
                    DATA_O <= DATA_I;
                    DATA_VALID_O <= '1';
                    if DATA_I = DLE then
                        state <= s_dle_data;
                    else
                        state <= s_data;
                    end if;
                end if;
                
            when s_data =>
                if DATA_ACK_I = '1' then
                    DATA_VALID_O <= '0';
                    state <= s_active;
                end if;
                
            when s_dle_data =>
                -- repeat DLE
                if DATA_ACK_I = '1' then
                    state <= s_data;
                end if;
                
            when s_dle_etx =>
                if DATA_ACK_I = '1' then
                    DATA_O <= ETX;
                    state <= s_etx;
                end if;
                
            when s_etx =>
                if DATA_ACK_I = '1' then
                    DATA_VALID_O <= '0';
                    state <= s_idle;
                end if;
                
            when others => state <= s_idle;
            end case;
        end if;
    end process;

end Behavioral;
