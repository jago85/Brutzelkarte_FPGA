library	ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mcp7940n is
port (
    CLK_I        : in std_logic;
    RESET_I      : in std_logic;

    TIME_VALID_O : out std_logic;
    SEC_O        : out std_logic_vector(6 downto 0);
    MIN_O        : out std_logic_vector(6 downto 0);
    HOUR_O       : out std_logic_vector(5 downto 0);
    WEEKDAY_O    : out std_logic_vector(2 downto 0);
    DATE_O       : out std_logic_vector(5 downto 0);
    MONTH_O      : out std_logic_vector(4 downto 0);
    YEAR_O       : out std_logic_vector(7 downto 0);

    TIME_SET_I   : in std_logic;
    TIME_ACK_O   : out std_logic;
    SEC_I        : in std_logic_vector(6 downto 0);
    MIN_I        : in std_logic_vector(6 downto 0);
    HOUR_I       : in std_logic_vector(5 downto 0);
    WEEKDAY_I    : in std_logic_vector(2 downto 0);
    DATE_I       : in std_logic_vector(5 downto 0);
    MONTH_I      : in std_logic_vector(4 downto 0);
    YEAR_I       : in std_logic_vector(7 downto 0);

    I2C_SCL_IO   : inout std_logic;
    I2C_SDA_IO   : inout std_logic

);
end entity mcp7940n;

architecture Behavioral of mcp7940n is

    component i2c_master
      GENERIC(
      input_clk : INTEGER := 100_000_000; --input clock speed from user logic in Hz
      bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
      PORT(
        clk       : IN     STD_LOGIC;                    --system clock
        reset_n   : IN     STD_LOGIC;                    --active low reset
        ena       : IN     STD_LOGIC;                    --latch in command
        addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
        rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
        data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
        busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
        data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
        ack_error : OUT    STD_LOGIC;                    --flag if improper acknowledge from slave
        sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
        scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
    END component;
    
    constant I2C_DEV_ADDR : std_logic_vector(6 downto 0) := "1101111";
    
    constant REG_RTCSEC   : std_logic_vector(7 downto 0) := x"00";
    constant REG_RTCMIN   : std_logic_vector(7 downto 0) := x"01";
    constant REG_RTCHOUR  : std_logic_vector(7 downto 0) := x"02";
    constant REG_RTCWKDAY : std_logic_vector(7 downto 0) := x"03";
    constant REG_RTCDATE  : std_logic_vector(7 downto 0) := x"04";
    constant REG_RTCMTH   : std_logic_vector(7 downto 0) := x"05";
    constant REG_RTCYEAR  : std_logic_vector(7 downto 0) := x"06";
    
    signal reset_n : std_logic;

    signal i2c_ena : std_logic;
    signal i2c_rw : std_logic;
    signal i2c_data_wr : std_logic_vector(7 downto 0);
    signal i2c_busy : std_logic;
    signal i2c_data_rd : std_logic_vector(7 downto 0);
    signal i2c_ack_error : std_logic;
    
    signal i2c_busy_last : std_logic;
    signal i2c_transfer_started : std_logic;
    signal i2c_transfer_done : std_logic;
    
    -- Init:
    --  Read ST, if clear set it
    --  wait for OSCRUN
    --  start first read
    
    -- Run:
    --  sleep n clocks
    --  read time
    
    -- Setup:
    --  Clear ST
    --  Wait for OSCRUN == 0
    --  Program Min, Hour, VBATEN | Weekday, Date, Month, Year
    --  Program ST | Sec
    --  wait for OSCRUN
    
    
    type state_t is (
        s_init,
        s_init_read_st1,
        s_init_read_st2,
        s_init_set_st1,
        s_init_set_st2,
        
        s_wait_oscrun1,
        s_wait_oscrun2,
        
        s_idle,
        s_read_time1,
        s_read_time2,
        
        s_setup_clear_st1,
        s_setup_clear_st2,
        
        s_setup_wait_oscrun_clear1,
        s_setup_wait_oscrun_clear2,
        s_setup_program1,
        s_setup_program2,
        s_setup_program_sec1,
        s_setup_program_sec2,
        
        s_turnaround,
        s_end_transfer
    );
    
    signal state : state_t;
    signal next_state : state_t;
    
    signal time_valid : std_logic;
    signal reg_num : unsigned(2 downto 0);
    signal idle_counter : unsigned(17 downto 0);
    
    signal sec_reg : std_logic_vector(6 downto 0);
    signal min_reg : std_logic_vector(6 downto 0);
    signal hour_reg : std_logic_vector(5 downto 0);
    signal weekday_reg : std_logic_vector(2 downto 0);
    signal date_reg : std_logic_vector(5 downto 0);
    signal month_reg : std_logic_vector(4 downto 0);
    signal year_reg : std_logic_vector(7 downto 0);
    
    attribute syn_state_machine : boolean;
	attribute syn_state_machine of Behavioral : architecture is true;	
	attribute syn_encoding : string;
	attribute syn_encoding of state: signal is "onehot";
begin

    i2c_master_inst : i2c_master
    generic map (
        input_clk => 79_800_000,
        bus_clk   => 100_000
    )
    port map (
        clk       => CLK_I,
        reset_n   => reset_n,
        
        ena       => i2c_ena,
        addr      => I2C_DEV_ADDR,
        rw        => i2c_rw,
        data_wr   => i2c_data_wr,
        busy      => i2c_busy,
        data_rd   => i2c_data_rd,
        ack_error => i2c_ack_error,

        sda       => I2C_SDA_IO,
        scl       => I2C_SCL_IO
    );

    reset_n <= not RESET_I;
    
    TIME_VALID_O <= time_valid;
    i2c_transfer_started <= '1' when (i2c_busy = '1') and (i2c_busy_last = '0') else '0';
    i2c_transfer_done <= '1' when (i2c_busy = '0') and (i2c_busy_last = '1') else '0';
    
    process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if RESET_I = '1' then
                i2c_ena <= '0';
                i2c_rw <= '0';
                i2c_data_wr <= (others => '0');
                state <= s_init;
                time_valid <= '0';
                idle_counter <= (others => '0');
                i2c_busy_last <= '1';
                TIME_ACK_O <= '0';
            else
                TIME_ACK_O <= '0';
                i2c_busy_last <= i2c_busy;
                case state is
                when s_init =>
                    time_valid <= '0';
                    state <= s_end_transfer;
                    next_state <= s_init_read_st1;
                    
                when s_init_read_st1 =>
                    i2c_data_wr <= REG_RTCSEC;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_turnaround;
                        next_state <= s_init_read_st2;
                    end if;
                    
                when s_init_read_st2 =>
                    i2c_ena <= '0';
                    if i2c_busy = '0' then
                        -- bit 7 is ST
                        if i2c_data_rd(7) = '1' then
                            -- clock already running
                            state <= s_read_time1;
                        else
                            -- clock not running
                            state <= s_init_set_st1;
                        end if;
                    end if;
                    
                when s_init_set_st1 =>
                    i2c_data_wr <= REG_RTCSEC;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_init_set_st2;
                    end if;
                    
                when s_init_set_st2 =>
                    i2c_data_wr <= x"80";
                    if i2c_transfer_started = '1' then
                        state <= s_end_transfer;
                        next_state <= s_wait_oscrun1;
                    end if;
                
                when s_wait_oscrun1 =>
                    i2c_data_wr <= REG_RTCWKDAY;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_turnaround;
                        next_state <= s_wait_oscrun2;
                    end if;
                
                when s_wait_oscrun2 =>
                    i2c_ena <= '0';
                    if i2c_busy = '0' then
                        -- bit 5 is OSCRUN
                        if i2c_data_rd(5) = '1' then
                            state <= s_read_time1;
                        else
                            state <= s_wait_oscrun1;
                        end if;
                    end if;

                when s_idle =>
                    time_valid <= '1';
                    SEC_O <= sec_reg;
                    MIN_O <= min_reg;
                    HOUR_O <= hour_reg;
                    WEEKDAY_O <= weekday_reg;
                    DATE_O <= date_reg;
                    MONTH_O <= month_reg;
                    YEAR_O <= year_reg;
                    
                    idle_counter <= idle_counter + 1;
                    if idle_counter = (idle_counter'range => '1') then
                        state <= s_read_time1;
                    end if;
                    if TIME_SET_I = '1' then
                        state <= s_setup_clear_st1;
                        time_valid <= '0';
                    end if;
                    
                when s_read_time1 =>
                    reg_num <= (others => '0');
                    i2c_data_wr <= REG_RTCSEC;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_turnaround;
                        next_state <= s_read_time2;
                    end if;
                    
                when s_read_time2 =>
                    if reg_num = 6 then
                        i2c_ena <= '0';
                    end if;
                    if i2c_transfer_done = '1' then
                        case reg_num is
                        when to_unsigned(0, reg_num'length) =>
                            sec_reg <= i2c_data_rd(sec_reg'range);
                            
                        when to_unsigned(1, reg_num'length) =>
                            min_reg <= i2c_data_rd(min_reg'range);
                            
                        when to_unsigned(2, reg_num'length) =>
                            hour_reg <= i2c_data_rd(hour_reg'range);
                            
                        when to_unsigned(3, reg_num'length) =>
                            weekday_reg <= i2c_data_rd(weekday_reg'range);
                            
                        when to_unsigned(4, reg_num'length) =>
                            date_reg <= i2c_data_rd(date_reg'range);
                            
                        when to_unsigned(5, reg_num'length) =>
                            month_reg <= i2c_data_rd(month_reg'range);
                            
                        when to_unsigned(6, reg_num'length) =>
                            year_reg <= i2c_data_rd(year_reg'range);
                            state <= s_idle;
                            
                        when others => null;
                        end case;
                        reg_num <= reg_num + 1;
                    end if;

                when s_setup_clear_st1 =>
                    i2c_data_wr <= REG_RTCSEC;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_setup_clear_st2;
                    end if;
                    
                when s_setup_clear_st2 =>
                    i2c_data_wr <= x"00";
                    if i2c_transfer_started = '1' then
                        state <= s_end_transfer;
                        next_state <= s_setup_wait_oscrun_clear1;
                    end if;
                    
                when s_setup_wait_oscrun_clear1 =>
                    i2c_data_wr <= REG_RTCWKDAY;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_turnaround;
                        next_state <= s_setup_wait_oscrun_clear2;
                    end if;
                    
                when s_setup_wait_oscrun_clear2 =>
                    i2c_ena <= '0';
                    if i2c_busy = '0' then
                        -- bit 5 is OSCRUN
                        if i2c_data_rd(5) = '0' then
                            -- clock stopped
                            state <= s_setup_program1;
                        else
                            -- clock still running
                            state <= s_setup_wait_oscrun_clear1;
                        end if;
                    end if;
                    
                when s_setup_program1 =>
                    reg_num <= (others => '0');
                    i2c_data_wr <= REG_RTCMIN;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_setup_program2;
                    end if;
                    
                when s_setup_program2 =>
                    case reg_num is
                    when to_unsigned(0, reg_num'length) =>
                        i2c_data_wr <= "0" & MIN_I;
                    when to_unsigned(1, reg_num'length) =>
                        i2c_data_wr <= "00" & HOUR_I;
                    when to_unsigned(2, reg_num'length) =>
                        -- bit 3 is VBATEN
                        i2c_data_wr <= "00001" & WEEKDAY_I;
                    when to_unsigned(3, reg_num'length) =>
                        i2c_data_wr <= "00" & DATE_I;
                    when to_unsigned(4, reg_num'length) =>
                        i2c_data_wr <= "000" & MONTH_I;
                    when to_unsigned(5, reg_num'length) =>
                        i2c_data_wr <= YEAR_I;
                    when others => null;
                    end case;
                    if i2c_transfer_started = '1' then
                        reg_num <= reg_num + 1;
                        if reg_num = 5 then
                            state <= s_end_transfer;
                            next_state <= s_setup_program_sec1;
                        end if;
                    end if;
                    
                when s_setup_program_sec1 =>
                    reg_num <= (others => '0');
                    i2c_data_wr <= REG_RTCSEC;
                    i2c_rw <= '0';
                    i2c_ena <= '1';
                    if i2c_busy = '1' then
                        state <= s_setup_program_sec2;
                    end if;
                    
                when s_setup_program_sec2 =>
                    i2c_data_wr <= "1" & SEC_I;
                    if i2c_transfer_started = '1' then
                        TIME_ACK_O <= '1';
                        next_state <= s_wait_oscrun1;
                        state <= s_end_transfer;
                    end if;
                
                -- turn around the ongoing transfer from write to read and got to next_state
                when s_turnaround =>
                    i2c_rw <= '1';
                    if i2c_transfer_started = '1' then
                        state <= next_state;
                    end if;
                    
                -- end the ongoing transfer and go to next_state
                when s_end_transfer =>
                    i2c_ena <= '0';
                    if i2c_busy = '0' then
                        state <= next_state;
                    end if;
                    
                when others => state <= s_init;
                end case;
            end if;
        end if;
    end process;

end Behavioral;