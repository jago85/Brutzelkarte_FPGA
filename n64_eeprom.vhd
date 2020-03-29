library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity n64_eeprom is
port (
    CLK_I            : in    std_logic;
    RST_I            : in    std_logic;
    
    -- EEPROM_ENABLE_I controlls the EEPROM but not the RTC
    -- The RTC is always enabled.
    EEPROM_ENABLE_I  : in    std_logic;
    TYPE_I           : in    std_logic;
    
    MEM_CYC_O        : out   std_logic;
    MEM_STB_O        : out   std_logic;
    MEM_WE_O         : out   std_logic;
    MEM_ACK_I        : in    std_logic;
    MEM_ADR_O        : out   std_logic_vector(9 downto 0);
    MEM_DAT_I        : in    std_logic_vector(15 downto 0);
    MEM_DAT_O        : out   std_logic_vector(15 downto 0);
    
    -- data from RTC
    RTC_TIME_VALID_I : in std_logic;
    RTC_TIME_ACK_I   : in std_logic;
    RTC_SEC_I        : in std_logic_vector(6 downto 0);
    RTC_MIN_I        : in std_logic_vector(6 downto 0);
    RTC_HOUR_I       : in std_logic_vector(5 downto 0);
    RTC_WEEKDAY_I    : in std_logic_vector(2 downto 0);
    RTC_DATE_I       : in std_logic_vector(5 downto 0);
    RTC_MONTH_I      : in std_logic_vector(4 downto 0);
    RTC_YEAR_I       : in std_logic_vector(7 downto 0);
    
    -- data to RTC
    RTC_TIME_SET_O   : out std_logic;
    RTC_SEC_O        : out std_logic_vector(6 downto 0);
    RTC_MIN_O        : out std_logic_vector(6 downto 0);
    RTC_HOUR_O       : out std_logic_vector(5 downto 0);
    RTC_WEEKDAY_O    : out std_logic_vector(2 downto 0);
    RTC_DATE_O       : out std_logic_vector(5 downto 0);
    RTC_MONTH_O      : out std_logic_vector(4 downto 0);
    RTC_YEAR_O       : out std_logic_vector(7 downto 0);
    
    N64_S_CLK_I      : in    std_logic;
    N64_S_DAT_IO     : inout std_logic
);
end entity n64_eeprom;

architecture Behavioral of n64_eeprom is

    constant EEP_CMD_STATUS : std_logic_vector(7 downto 0) := x"00";
    constant EEP_CMD_READ   : std_logic_vector(7 downto 0) := x"04";
    constant EEP_CMD_WRITE  : std_logic_vector(7 downto 0) := x"05";
    
    constant RTC_CMD_STATUS : std_logic_vector(7 downto 0) := x"06";
    constant RTC_CMD_READ   : std_logic_vector(7 downto 0) := x"07";
    constant RTC_CMD_WRITE  : std_logic_vector(7 downto 0) := x"08";
    
    signal sclk_ff1, sclk_ff2 : std_logic;
    signal sdat_ff1, sdat_ff2 : std_logic;
    
    signal sclk_last : std_logic;
    
    signal rxbit_cnt : unsigned(3 downto 0);
    signal rxlow_cnt : unsigned(3 downto 0);
    
    type rx_state_t is (
        s_rx_idle,
        s_rx_low,
        s_rx_high
    );
    signal rx_state : rx_state_t;
    
    signal rx_shift : std_logic_vector(7 downto 0);
    signal rxshift_cnt : unsigned(2 downto 0);
    signal rx_valid : std_logic;
    signal rx_busy : std_logic;
    signal rx_enable : std_logic;
    
    type cmd_state_t is (
        s_cmd_idle,
        s_cmd_addr,
        s_cmd_rxdata,
        s_cmd_exec,
        s_cmd_send,
        s_cmd_done
    );
    signal cmd_state : cmd_state_t;
    type mem8 is array (natural range <>) of std_logic_vector(7 downto 0);
    signal cmd_reg : std_logic_vector(7 downto 0);
    signal cmd_addr : std_logic_vector(7 downto 0);
    signal cmd_buf : mem8(8 downto 0) := (others => (others => '0'));
    signal cmd_buf_cnt : unsigned(3 downto 0);
    signal cmd_tx_cnt : unsigned(3 downto 0);
    
    type tx_state_t is (
        s_tx_idle,
        s_tx_low,
        s_tx_high,
        s_tx_stop
    );
    signal tx_state : tx_state_t;
    signal tx_data : std_logic_vector(7 downto 0);
    signal tx_valid : std_logic;
    signal tx_busy : std_logic;
    signal tx_ack : std_logic;
    signal tx_shift : std_logic_vector(7 downto 0);
    signal txbit_cnt : unsigned(4 downto 0);
    signal txshift_cnt : unsigned(2 downto 0);
    signal tx_drive_low : std_logic;
    
    signal mem_cyc : std_logic;
    
    -- rtc registers
    signal rtc_status  : std_logic_vector(7 downto 0);
    signal rtc_protect : std_logic_vector(1 downto 0);
    signal rtc_stop : std_logic;
    
    signal rtc_set_enable : std_logic;
    signal rtc_set_sec : std_logic_vector(6 downto 0);
    signal rtc_set_min : std_logic_vector(6 downto 0);
    signal rtc_set_hour : std_logic_vector(5 downto 0);
    signal rtc_set_weekday : std_logic_vector(2 downto 0);
    signal rtc_set_date : std_logic_vector(5 downto 0);
    signal rtc_set_month : std_logic_vector(4 downto 0);
    signal rtc_set_year : std_logic_vector(7 downto 0);
    
begin

    N64_S_DAT_IO <= '0' when tx_drive_low = '1' else 'Z';
    
    MEM_CYC_O <= mem_cyc;
    MEM_STB_O <= mem_cyc;
    MEM_ADR_O <= cmd_addr & std_logic_vector(cmd_buf_cnt(1 downto 0));
    MEM_DAT_O <= cmd_buf(to_integer(cmd_buf_cnt(1 downto 0) & "1")) & cmd_buf(to_integer(cmd_buf_cnt(1 downto 0) & "0"));
    
    RTC_TIME_SET_O <= rtc_set_enable;
    RTC_SEC_O <= rtc_set_sec;
    RTC_MIN_O <= rtc_set_min;
    RTC_HOUR_O <= rtc_set_hour;
    RTC_WEEKDAY_O <= rtc_set_weekday;
    RTC_DATE_O <= rtc_set_date;
    RTC_MONTH_O <= rtc_set_month;
    RTC_YEAR_O <= rtc_set_year;
    
    rx_busy <= '0' when rx_state = s_rx_idle else '1';
    tx_busy <= '0' when tx_state = s_tx_idle else '1';
    
    rtc_status <= rtc_stop & "0000000";
    
    process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if RST_I = '1' then
                sclk_ff1 <= '1';
                sclk_ff2 <= '1';
                sdat_ff1 <= '1';
                sdat_ff2 <= '1';
                
                sclk_last <= sclk_ff2;
                rx_state <= s_rx_idle;
                rx_valid <= '0';
                rx_enable <= '0';
                
                cmd_state <= s_cmd_idle;
                tx_state <= s_tx_idle;
                tx_ack <= '0';
                tx_valid <= '0';
                tx_drive_low <= '0';
                
                mem_cyc <= '0';
                MEM_WE_O <= '0';
                
                rtc_protect <= (others => '1');
                rtc_stop <= '0';
                rtc_set_enable <= '0';
            else
                -- input synchronization
                sclk_ff1 <= N64_S_CLK_I;
                sclk_ff2 <= sclk_ff1;
                sclk_last <= sclk_ff2;
                sdat_ff1 <= N64_S_DAT_IO;
                if N64_S_DAT_IO = '0' then
                    sdat_ff1 <= '0';
                else
                    sdat_ff1 <= '1';
                end if;
                -- sdat_ff1 <= N64_S_DAT_IO;
                sdat_ff2 <= sdat_ff1;
                
                -- receive logic
                rx_valid <= '0';
                tx_ack <= '0';
                if sclk_ff2 = '1' and sclk_last = '0' then
                    if rx_enable = '0' then
                        rx_state <= s_rx_idle;
                    else
                        case rx_state is
                        when s_rx_idle =>
                            rxshift_cnt <= (others => '0');
                            if sdat_ff2 = '0' then
                                rx_state <= s_rx_low;
                                rxbit_cnt <= (others => '0');
                            end if;
                            
                        when s_rx_low =>
                            rxbit_cnt <= rxbit_cnt + 1;
                            if sdat_ff2 = '1' then
                                rx_state <= s_rx_high;
                                rxlow_cnt <= rxbit_cnt;
                                rxbit_cnt <= (others => '0');
                            end if;
                            
                        when s_rx_high =>
                            rxbit_cnt <= rxbit_cnt + 1;
                            if sdat_ff2 = '0' then
                                rx_state <= s_rx_low;
                                rxbit_cnt <= (others => '0');
                                if rxlow_cnt > rxbit_cnt then
                                    rx_shift <= rx_shift(6 downto 0) & '0';
                                else
                                    rx_shift <= rx_shift(6 downto 0) & '1';
                                end if;
                                
                                rxshift_cnt <= rxshift_cnt + 1;
                                if rxshift_cnt = 7 then
                                    rxshift_cnt <= (others => '0');
                                    rx_valid <= '1';
                                end if;
                            end if;
                            
                            if rxbit_cnt(3) = '1' then
                                rx_state <= s_rx_idle;
                            end if;
                            
                        when others => rx_state <= s_rx_idle;
                        end case;
                    end if;
                    
                    -- transmit logic
                    tx_drive_low <= '0';
                    case tx_state is
                    when s_tx_idle =>
                        txshift_cnt <= (others => '0');
                        if tx_valid = '1' then
                            tx_ack <= '1';
                            tx_shift <= tx_data;
                            txbit_cnt <= (others => '0');
                            tx_state <= s_tx_low;
                        end if;
                        
                    when s_tx_low =>
                        tx_drive_low <= '1';
                        txbit_cnt <= txbit_cnt + 1;
                        if tx_shift(7) = '1' then
                            if txbit_cnt = 1 then
                                tx_state <= s_tx_high;
                            end if;
                        else
                            if txbit_cnt = 5 then
                                tx_state <= s_tx_high;
                            end if;
                        end if;
                        
                    when s_tx_high =>
                        txbit_cnt <= txbit_cnt + 1;
                        if txbit_cnt = 7 then
                            tx_shift <= tx_shift(6 downto 0) & '0';
                            txshift_cnt <= txshift_cnt + 1;
                            txbit_cnt <= (others => '0');
                            tx_state <= s_tx_low;
                            if txshift_cnt = 7 then
                                txshift_cnt <= (others => '0');
                                if tx_valid = '1' then
                                    tx_ack <= '1';
                                    tx_shift <= tx_data;
                                else
                                    tx_state <= s_tx_stop;
                                end if;
                            end if;
                        end if;
                        
                    when s_tx_stop =>
                        tx_drive_low <= '1';
                        txbit_cnt <= txbit_cnt + 1;
                        if txbit_cnt > 1 then
                            tx_drive_low <= '0';
                        end if;
                        if txbit_cnt = 7 then
                            tx_state <= s_tx_idle;
                        end if;
                        
                    when others => tx_state <= s_tx_idle;
                    end case;
                    
                end if;
                
                -- command logic
                tx_valid <= '0';
                
                MEM_WE_O <= '0';
                mem_cyc <= '0';
                case cmd_state is
                when s_cmd_idle =>
                    rx_enable <= '1';
                    if rx_valid = '1' then 
                        cmd_reg <= rx_shift;
                        cmd_state <= s_cmd_addr;
                    end if;
                    
                when s_cmd_addr =>
                    cmd_buf_cnt <= (others => '0');
                    if rx_valid = '1' then
                        cmd_addr <= rx_shift;
                        cmd_state <= s_cmd_rxdata;
                    end if;
                    
                    if rx_busy = '0' then
                        cmd_state <= s_cmd_exec;
                    end if;
                    
                when s_cmd_rxdata =>
                    if rx_valid = '1' then 
                        cmd_buf(to_integer(cmd_buf_cnt)) <= rx_shift;
                        cmd_buf_cnt <= cmd_buf_cnt + 1;
                    end if;
                    
                    if rx_busy = '0' then
                        cmd_buf_cnt <= (others => '0');
                        cmd_state <= s_cmd_exec;
                    end if;
                    
                when s_cmd_exec =>
                    rx_enable <= '0';
                    case cmd_reg is
                    when EEP_CMD_STATUS =>
                        if EEPROM_ENABLE_I = '1' then
                            cmd_buf(0) <= x"00";
                            if TYPE_I = '0' then
                                cmd_buf(1) <= x"80";
                            else
                                cmd_buf(1) <= x"C0";
                            end if;
                            cmd_buf(2) <= x"00";
                            cmd_buf_cnt <= (others => '0');
                            cmd_state <= s_cmd_send;
                            cmd_tx_cnt <= to_unsigned(3 - 1, cmd_tx_cnt'length);
                        else
                            cmd_state <= s_cmd_done;
                        end if;
                        
                    when EEP_CMD_READ =>
                        if EEPROM_ENABLE_I = '1' then
                            mem_cyc <= '1';
                            if  MEM_ACK_I = '1' then
                                mem_cyc <= '0';
                                cmd_buf(to_integer(cmd_buf_cnt & "0")) <= MEM_DAT_I(7 downto 0);
                                cmd_buf(to_integer(cmd_buf_cnt & "1")) <= MEM_DAT_I(15 downto 8);
                                cmd_buf_cnt <= cmd_buf_cnt + 1;
                                if cmd_buf_cnt = 3 then
                                    cmd_buf_cnt <= (others => '0');
                                    cmd_state <= s_cmd_send;
                                end if;
                            end if;
                            cmd_tx_cnt <= to_unsigned(8 - 1, cmd_tx_cnt'length);
                        else
                            cmd_state <= s_cmd_done;
                        end if;
                        
                    when EEP_CMD_WRITE =>
                        if EEPROM_ENABLE_I = '1' then
                            mem_cyc <= '1';
                            MEM_WE_O <= '1';
                            if MEM_ACK_I = '1' then
                                mem_cyc <= '0';
                                MEM_WE_O <= '0';
                                cmd_buf_cnt <= cmd_buf_cnt + 1;
                                if cmd_buf_cnt = 3 then
                                    cmd_buf(0) <= x"00";
                                    cmd_buf_cnt <= (others => '0');
                                    cmd_state <= s_cmd_send;
                                end if;
                            end if;
                            cmd_tx_cnt <= to_unsigned(1 - 1, cmd_tx_cnt'length);
                        else
                            cmd_state <= s_cmd_done;
                        end if;
                        
                    when RTC_CMD_STATUS =>
                        cmd_buf(0) <= x"00";
                        cmd_buf(1) <= x"10";
                        cmd_buf(2) <= rtc_status;
                        cmd_buf_cnt <= (others => '0');
                        cmd_state <= s_cmd_send;
                        cmd_tx_cnt <= to_unsigned(3 - 1, cmd_tx_cnt'length);
                        
                    when RTC_CMD_READ =>
                        case cmd_addr is
                        when x"00" =>
                            cmd_buf(0) <= "000000" & rtc_protect;
                            cmd_buf(1) <= "00000" & rtc_stop & "00";
                            cmd_buf(2) <= (others => '0');
                            cmd_buf(3) <= (others => '0');
                            cmd_buf(4) <= (others => '0');
                            cmd_buf(5) <= (others => '0');
                            cmd_buf(6) <= (others => '0');
                            cmd_buf(7) <= (others => '0');
                            
                        when x"02" =>
                            cmd_buf(0) <= "0" & RTC_SEC_I;
                            cmd_buf(1) <= "0" & RTC_MIN_I;
                            cmd_buf(2) <= "10" & RTC_HOUR_I;
                            cmd_buf(3) <= "00" & RTC_DATE_I;
                            if RTC_WEEKDAY_I = "111" then
                                cmd_buf(4) <= (others => '0');
                            else
                                cmd_buf(4) <= "00000" & RTC_WEEKDAY_I;
                            end if;
                            cmd_buf(5) <= "000" & RTC_MONTH_I;
                            cmd_buf(6) <= RTC_YEAR_I;
                            cmd_buf(7) <= x"01";
                            
                        when others =>
                            cmd_buf(0) <= (others => '0');
                            cmd_buf(1) <= (others => '0');
                            cmd_buf(2) <= (others => '0');
                            cmd_buf(3) <= (others => '0');
                            cmd_buf(4) <= (others => '0');
                            cmd_buf(5) <= (others => '0');
                            cmd_buf(6) <= (others => '0');
                            cmd_buf(7) <= (others => '0');
                            
                        end case;
                        cmd_buf(8) <= rtc_status;
                        cmd_buf_cnt <= (others => '0');
                        cmd_state <= s_cmd_send;
                        cmd_tx_cnt <= to_unsigned(9 - 1, cmd_tx_cnt'length);
                        
                    when RTC_CMD_WRITE =>
                        case cmd_addr is
                        when x"00" =>
                            rtc_protect <= cmd_buf(0)(1 downto 0);
                            rtc_stop <= cmd_buf(1)(2);
                            cmd_buf(0) <= cmd_buf(1)(2) & "0000000";
                            
                        when x"02" =>
                            if rtc_protect(1) = '0' then
                                rtc_set_enable <= '1';
                                rtc_set_sec <= cmd_buf(0)(rtc_set_sec'range);
                                rtc_set_min <= cmd_buf(1)(rtc_set_min'range);
                                rtc_set_hour <= cmd_buf(2)(rtc_set_hour'range);
                                rtc_set_date <= cmd_buf(3)(rtc_set_date'range);
                                if cmd_buf(4) = x"00" then
                                    rtc_set_weekday <= "111";
                                else
                                    rtc_set_weekday <= cmd_buf(4)(rtc_set_weekday'range);
                                end if;
                                rtc_set_month <= cmd_buf(5)(rtc_set_month'range);
                                rtc_set_year <= cmd_buf(6)(rtc_set_year'range);
                            end if;
                            cmd_buf(0) <= rtc_status;
                            
                        when others =>
                            cmd_buf(0) <= rtc_status;
                            
                        end case;
                        cmd_buf_cnt <= (others => '0');
                        cmd_state <= s_cmd_send;
                        cmd_tx_cnt <= to_unsigned(1 - 1, cmd_tx_cnt'length);
                        
                    when others =>
                        cmd_state <= s_cmd_done;
                        
                    end case;
                    
                when s_cmd_send =>
                    tx_valid <= '1';
                    tx_data <= cmd_buf(to_integer(cmd_buf_cnt));
                    if tx_ack = '1' then
                        cmd_buf_cnt <= cmd_buf_cnt + 1;
                        if cmd_buf_cnt = cmd_tx_cnt then
                            cmd_state <= s_cmd_done;
                        end if;
                    end if;
                
                when s_cmd_done =>
                    if tx_busy = '0' then
                        cmd_state <= s_cmd_idle;
                    end if;
                    
                when others => cmd_state <= s_cmd_idle;
                end case;
                
                -- when the RTC accepted all data it sets the RTC_TIME_ACK_I signal
                -- so reset the rtc_set_enable request flag
                if RTC_TIME_ACK_I = '1' then
                    rtc_set_enable <= '0';
                end if;
            end if;
        end if;
    end process;
    
end architecture Behavioral;