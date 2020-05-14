library IEEE;
use IEEE.std_logic_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity uart_access is
generic (
    clock_frequency         : positive := 100_000_000;
    fpga_Version            : std_logic_vector(31 downto 0) := (others => '0')
);
port (
    CLK_I                   : in std_logic;
    RESET_I                 : in std_logic;
        
    FLASH_CMD_O             : out std_logic_vector(1 downto 0);
    FLASH_CMD_ADDR_O        : out std_logic_vector(23 downto 0);
    FLASH_CMD_EN_BOOT_O     : out std_logic;
    FLASH_CMD_RDY_BOOT_I    : in std_logic;
    FLASH_CMD_EN_ROM_O      : out std_logic;	  
    FLASH_CMD_RDY_ROM_I     : in std_logic;
    FLASH_CMD_ACK_I         : in std_logic;
    FLASH_DATA_BOOT_I       : in std_logic_vector (31 downto 0);
    FLASH_DATA_ROM_I        : in std_logic_vector (31 downto 0);
    FLASH_DATA_VALID_BOOT_I : in std_logic;
    FLASH_DATA_VALID_ROM_I  : in std_logic;
    
    WRITE_FIFO_EMPTY_O      : out std_logic;
    WRITE_FIFO_DATA_O       : out std_logic_vector(7 downto 0);
    WRITE_FIFO_RDEN_BOOT_I  : in std_logic;
    WRITE_FIFO_RDEN_ROM_I   : in std_logic;
    
    MEM_CYC_O               : out std_logic;
    MEM_STB_O               : out std_logic;
    MEM_WE_O                : out std_logic;
    MEM_ACK_I               : in std_logic;
    MEM_ADR_O               : out std_logic_vector(16 downto 0);    
    MEM_DAT_O               : out std_logic_vector(15 downto 0);    
    MEM_DAT_I               : in std_logic_vector(15 downto 0);
    
    EFB_CYC_O               : out std_logic;
    EFB_STB_O               : out std_logic;
    EFB_WE_O                : out std_logic;
    EFB_ACK_I               : in std_logic;
    EFB_ADR_O               : out std_logic_vector(7 downto 0);    
    EFB_DAT_O               : out std_logic_vector(7 downto 0);    
    EFB_DAT_I               : in std_logic_vector(7 downto 0);
    
    -- data to RTC
    RTC_TIME_SET_O          : out std_logic;
    RTC_TIME_ACK_I          : in std_logic;
    RTC_SEC_O               : out std_logic_vector(6 downto 0);
    RTC_MIN_O               : out std_logic_vector(6 downto 0);
    RTC_HOUR_O              : out std_logic_vector(5 downto 0);
    RTC_WEEKDAY_O           : out std_logic_vector(2 downto 0);
    RTC_DATE_O              : out std_logic_vector(5 downto 0);
    RTC_MONTH_O             : out std_logic_vector(4 downto 0);
    RTC_YEAR_O              : out std_logic_vector(7 downto 0);
    
    -- bypass mode
    BYP_ENABLE_I            : in std_logic;
    BYP_TX_VALID_I          : in std_logic;
    BYP_TX_ACK_O            : out std_logic;
    BYP_TX_DATA_I           : in std_logic_vector(7 downto 0);
    BYP_RX_DATA_O           : out std_logic_vector(7 downto 0);
    BYP_RX_VALID_O          : out std_logic;
    
    USB_DETECT_I            : in std_logic;
    UART_TX_O               : out std_logic;
    UART_RX_I               : in std_logic
    
);
end entity uart_access;

architecture Behavioral of uart_access is

    component cmd_fifo
    port (Data: in  std_logic_vector(7 downto 0); WrClock: in  std_logic; 
        RdClock: in  std_logic; WrEn: in  std_logic; RdEn: in  std_logic; 
        Reset: in  std_logic; RPReset: in  std_logic; 
        Q: out  std_logic_vector(7 downto 0); Empty: out  std_logic; 
        Full: out  std_logic; AlmostEmpty: out  std_logic; 
        AlmostFull: out  std_logic);
    end component;
    
    component uart is
        generic (
            baud                : positive;
            clock_frequency     : positive
        );
        port (  
            -- general
            clock               :   in      std_logic;
            reset               :   in      std_logic;    
            data_stream_in      :   in      std_logic_vector(7 downto 0);
            data_stream_in_stb  :   in      std_logic;
            data_stream_in_ack  :   out     std_logic := '0';
            data_stream_out     :   out     std_logic_vector(7 downto 0);
            data_stream_out_stb :   out     std_logic;
            tx_active           :   out std_logic;
            tx                  :   out     std_logic;
            rx                  :   in      std_logic
        );
    end component;
    
    component stx_etx_rcv
    port (
        CLK_I           : in std_logic;
        RESET_I         : in std_logic;
        
        DATA_I          : in std_logic_vector(7 downto 0);
        DATA_VALID_I    : in std_logic;
        
        RECEIVING_O     : out std_logic;
        DATA_VALID_O    : out std_logic
    );
    end component;
    
    component stx_etx_send
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
    end component;
    
    constant FLASH_CMD_NONE   : std_logic_vector(1 downto 0) := "00";
    constant FLASH_CMD_READ   : std_logic_vector(1 downto 0) := "01";
    constant FLASH_CMD_WRITE  : std_logic_vector(1 downto 0) := "10";
    constant FLASH_CMD_ERASE  : std_logic_vector(1 downto 0) := "11";
    
    constant UART_CMD_SET_ADDR       : std_logic_vector(7 downto 0) := x"01";
    constant UART_CMD_FLASH_ERASE    : std_logic_vector(7 downto 0) := x"02";
    constant UART_CMD_FLASH_WRITE    : std_logic_vector(7 downto 0) := x"03";
    constant UART_CMD_FLASH_READ     : std_logic_vector(7 downto 0) := x"04";
    constant UART_CMD_SRAM_WRITE     : std_logic_vector(7 downto 0) := x"05";
    constant UART_CMD_SRAM_READ      : std_logic_vector(7 downto 0) := x"06";
    constant UART_CMD_EFB_WRITE      : std_logic_vector(7 downto 0) := x"07";
    constant UART_CMD_EFB_READ       : std_logic_vector(7 downto 0) := x"08";
    constant UART_CMD_READ_VERSION   : std_logic_vector(7 downto 0) := x"09";
    constant UART_CMD_SET_RTC        : std_logic_vector(7 downto 0) := x"0A";
    
    type uart_com_state_t is (
        s_wait_start,
        s_get_cmd,
        s_get_addr,
        s_get_flash_data,
        s_write_flash,
        s_erase_flash,
        s_wait_flash,
        s_read_flash,
        s_read_sram,
        s_get_sram_data,
        s_write_sram,
        
        s_send_flash_data,
        s_send_sram_data,
        s_send_ack,
        
        s_get_efb_len,
        s_get_efb_data,
        s_write_efb,
        s_read_efb,
        s_send_efb_data,
        
        s_send_version,
        
        s_set_rtc,
        
        s_byp_mode,
        
        s_invalid
    );
    
    signal flash_cmd_rdy : std_logic;
    signal flash_data : std_logic_vector (31 downto 0);
    signal flash_data_valid : std_logic;
    
    signal uart_data_in : std_logic_vector(7 downto 0);
    signal uart_data_out : std_logic_vector(7 downto 0);
    signal uart_data_out_stb : std_logic;
    signal uart_data_in_stb : std_logic;
    signal uart_data_in_ack : std_logic;
    
    signal stxetx_rx_data_valid : std_logic;
    signal stxetx_tx_data_valid : std_logic;
    signal stxetx_tx_data_ack : std_logic;
    signal stxetx_tx_data : std_logic_vector(7 downto 0);
    
    signal uart_receiving : std_logic;
    signal uart_receiving_last : std_logic;
    signal uart_rx_valid : std_logic;
    
    signal uart_tx_enable : std_logic;
    signal uart_tx_line : std_logic;
    signal uart_tx_valid : std_logic;
    signal uart_tx_ack : std_logic;
    signal uart_tx_data : std_logic_vector(7 downto 0);
    
    signal uart_com_state : uart_com_state_t;
    signal uart_com_addr : std_logic_vector(24 downto 0);
    signal uart_com_counter : unsigned(7 downto 0);
    signal uart_packet_counter : unsigned(3 downto 0);
    signal uart_packet_ack : std_logic;
    
    signal data_counter : unsigned(6 downto 0);
    signal flash_read_data : std_logic_vector(31 downto 0);
    
    signal cmd_fifo_empty : std_logic;
    signal cmd_fifo_q : std_logic_vector(7 downto 0);
    signal cmd_fifo_rden : std_logic;
    signal cmd_fifo_reset : std_logic;
    signal cmd_fifo_data_valid : std_logic_vector(1 downto 0);
    
    signal sram_read_data : std_logic_vector(15 downto 0);
    
    signal efb_we : std_logic;
    
    signal delay_counter : unsigned(24 downto 0);
    
begin

    cmd_fifo_inst : cmd_fifo
    port map (
        Data(7 downto 0) => uart_data_out,
        WrClock => CLK_I,
        RdClock => CLK_I,
        WrEn => uart_rx_valid,

        RdEn => cmd_fifo_rden,
        Reset => cmd_fifo_reset,
        RPReset => '0',
        Q(7 downto 0) => cmd_fifo_q,
        Empty => cmd_fifo_empty,

        Full => open,
        AlmostEmpty => open,
        AlmostFull => open
    );
    
    uart_inst : uart
    generic map(
        baud                => 3_000_000,
        clock_frequency     => clock_frequency
    )
    port map(
        -- general
        clock               => CLK_I,
        reset               => cmd_fifo_reset,
        
        data_stream_in      => uart_data_in,
        data_stream_in_stb  => uart_data_in_stb,
        data_stream_in_ack  => uart_data_in_ack,
        data_stream_out     => uart_data_out,
        data_stream_out_stb => uart_data_out_stb,
        tx_active           => open,
        tx                  => uart_tx_line,
        rx                  => UART_RX_I
    );
    
    UART_TX_O <= uart_tx_line when USB_DETECT_I = '1' else 'Z';
    
    stx_etx_rcv_inst : stx_etx_rcv
    port map (
        CLK_I        => CLK_I,
        RESET_I      => cmd_fifo_reset,
        DATA_I       => uart_data_out,
        DATA_VALID_I => stxetx_rx_data_valid,
        RECEIVING_O  => uart_receiving,
        DATA_VALID_O => uart_rx_valid
    );
    
    stx_etx_send_inst : stx_etx_send
    port map (
        CLK_I        => CLK_I,
        RESET_I      => cmd_fifo_reset,
        
        ACTIVE_I     => uart_tx_enable,
        ACTIVE_O     => open,
        
        DATA_I       => uart_tx_data,
        DATA_VALID_I => uart_tx_valid,
        DATA_ACK_O   => uart_tx_ack,
        
        DATA_O       => stxetx_tx_data,
        DATA_VALID_O => stxetx_tx_data_valid,
        DATA_ACK_I   => stxetx_tx_data_ack
    );
    
    process (uart_com_state, BYP_TX_DATA_I, BYP_TX_VALID_I, uart_data_in_ack, stxetx_tx_data, stxetx_tx_data_valid, uart_data_out, uart_data_out_stb)
    begin
        if uart_com_state = s_byp_mode then
            uart_data_in <= BYP_TX_DATA_I;
            uart_data_in_stb <= BYP_TX_VALID_I;
            BYP_TX_ACK_O <= uart_data_in_ack;
            BYP_RX_DATA_O <= uart_data_out;
            BYP_RX_VALID_O <= uart_data_out_stb;
            stxetx_tx_data_ack <= '0';
            stxetx_rx_data_valid <= '0';
        else
            uart_data_in <= stxetx_tx_data;
            uart_data_in_stb <= stxetx_tx_data_valid;
            stxetx_tx_data_ack <= uart_data_in_ack;
            stxetx_rx_data_valid <= uart_data_out_stb;
            BYP_TX_ACK_O <= '0';
            BYP_RX_DATA_O <= (others => '0');
            BYP_RX_VALID_O <='0';
        end if;
    end process;
    
    with uart_com_addr(24) select flash_data <=
        FLASH_DATA_ROM_I when '0',
        FLASH_DATA_BOOT_I when others;
    
    with uart_com_addr(24) select flash_data_valid <=
        FLASH_DATA_VALID_ROM_I when '0',
        FLASH_DATA_VALID_BOOT_I when others;
        
    flash_cmd_rdy <= FLASH_CMD_RDY_BOOT_I and FLASH_CMD_RDY_ROM_I;
    
    EFB_WE_O <= efb_we;
    
    process (CLK_I, RESET_I)
    begin
        if RESET_I = '1' then
            uart_com_state <= s_wait_start;
            uart_com_counter <= (others => '0');
            uart_com_addr <= (others => '0');
            cmd_fifo_data_valid <= (others => '0');
            cmd_fifo_reset <= '1';
            uart_tx_valid <= '0';
            uart_tx_enable <= '0';
            uart_receiving_last <= '0';
            uart_packet_counter <= (others => '0');
            uart_packet_ack <= '0';
            data_counter <= (others => '0');
            FLASH_CMD_EN_BOOT_O <= '0';
            FLASH_CMD_EN_ROM_O <= '0';
            FLASH_CMD_ADDR_O <= (others => '0');
            FLASH_CMD_O <= FLASH_CMD_NONE;
            MEM_CYC_O <= '0';
            MEM_STB_O <= '0';
            MEM_WE_O <= '0';
            MEM_ADR_O <= (others => '0');
            MEM_DAT_O <= (others => '0');
            WRITE_FIFO_EMPTY_O <= '1';
            efb_we <= '0';
            delay_counter <= (others => '0');
            RTC_TIME_SET_O <= '0';
        elsif rising_edge(CLK_I) then
            
            cmd_fifo_reset <= '1';
            
            if USB_DETECT_I = '0' then
                delay_counter <= (others => '0');
            else
                -- wait 0.4 s @ 79.8 MHz
                if delay_counter < 31_920_000 then
                    delay_counter <= delay_counter + 1;
                else
                    cmd_fifo_reset <= '0';
                end if;
            end if;
            
            if cmd_fifo_reset = '1' then
                cmd_fifo_data_valid <= (others => '0');
            elsif cmd_fifo_rden = '1' then
                cmd_fifo_data_valid <= not cmd_fifo_empty & cmd_fifo_data_valid(cmd_fifo_data_valid'high downto 1);
            end if;
            
            MEM_CYC_O <= '0';
            MEM_STB_O <= '0';
            MEM_WE_O <= '0';
            MEM_ADR_O <= (others => '0');
            
            uart_receiving_last <= uart_receiving;
            if uart_receiving = '0' and uart_receiving_last = '1' then
                if uart_packet_ack = '0' then
                    uart_packet_counter <= uart_packet_counter + 1;
                end if;
            elsif uart_packet_ack = '1' then
                uart_packet_counter <= uart_packet_counter - 1;
            end if;
            
            uart_packet_ack <= '0';
            
            WRITE_FIFO_EMPTY_O <= '1';
            
            -- when the RTC accepted all data it sets the RTC_TIME_ACK_I signal
            -- so reset the rtc_set_enable request flag
            if RTC_TIME_ACK_I = '1' then
                RTC_TIME_SET_O <= '0';
            end if;
            
            case uart_com_state is
            when s_wait_start =>
                cmd_fifo_rden <= '0';
                if BYP_ENABLE_I = '1' then
                    uart_com_state <= s_byp_mode;
                elsif uart_packet_counter > 0 then
                    uart_com_state <= s_get_cmd;
                    cmd_fifo_rden <= '1';
                    uart_packet_ack <= '1';
                end if;
                
            when s_get_cmd =>
                cmd_fifo_rden <= '1';
                data_counter <= (others => '0');
                uart_com_counter <= (others => '0');
                if cmd_fifo_data_valid(0) = '1' then
                    case cmd_fifo_q is
                    when UART_CMD_SET_ADDR =>
                        uart_com_state <= s_get_addr;
                        
                    when UART_CMD_FLASH_ERASE =>
                        cmd_fifo_rden <= '0';
                        uart_com_state <= s_erase_flash;
                        
                        FLASH_CMD_ADDR_O <= uart_com_addr(FLASH_CMD_ADDR_O'range);
                        FLASH_CMD_O <= FLASH_CMD_ERASE;
                        if uart_com_addr(24) = '1' then
                            FLASH_CMD_EN_BOOT_O <= '1';
                        else
                            FLASH_CMD_EN_ROM_O <= '1';
                        end if;
                        
                    when UART_CMD_FLASH_WRITE =>
                        uart_com_state <= s_write_flash;
                        cmd_fifo_rden <= '0';
                        
                        FLASH_CMD_ADDR_O <= uart_com_addr(FLASH_CMD_ADDR_O'range);
                        FLASH_CMD_O <= FLASH_CMD_WRITE;
                        if uart_com_addr(24) = '1' then
                            FLASH_CMD_EN_BOOT_O <= '1';
                        else
                            FLASH_CMD_EN_ROM_O <= '1';
                        end if;
                        
                        
                    when UART_CMD_FLASH_READ =>
                        cmd_fifo_rden <= '0';
                        uart_com_state <= s_read_flash;
                        
                        FLASH_CMD_ADDR_O <= uart_com_addr(FLASH_CMD_ADDR_O'range);
                        FLASH_CMD_O <= FLASH_CMD_READ;
                        if uart_com_addr(24) = '1' then
                            FLASH_CMD_EN_BOOT_O <= '1';
                        else
                            FLASH_CMD_EN_ROM_O <= '1';
                        end if;
                        
                    when UART_CMD_SRAM_WRITE =>
                        uart_com_state <= s_get_sram_data;
                        
                    when UART_CMD_SRAM_READ =>
                        cmd_fifo_rden <= '0';
                        uart_com_state <= s_read_sram;
                        
                    when UART_CMD_EFB_WRITE =>
                        uart_com_state <= s_get_efb_len;
                        efb_we <= '1';
                        
                    when UART_CMD_EFB_READ =>
                        uart_com_state <= s_get_efb_len;
                        efb_we <= '0';
                        
                    when UART_CMD_READ_VERSION =>
                        uart_com_state <= s_send_version;
                        
                    when UART_CMD_SET_RTC =>
                        uart_com_state <= s_set_rtc;
                        
                    when others =>
                        uart_com_state <= s_invalid;
                        delay_counter <= (others => '0');
                        
                    end case;
                    
                end if;
                
            when s_get_addr =>
                cmd_fifo_rden <= '1';
                if cmd_fifo_data_valid(0) = '1' then
                    case uart_com_counter is
                    when x"00" => uart_com_addr(24) <= cmd_fifo_q(0);
                    when x"01" => uart_com_addr(23 downto 16) <= cmd_fifo_q;
                    when x"02" => uart_com_addr(15 downto 8) <= cmd_fifo_q;
                    when x"03" => uart_com_addr(7 downto 0) <= cmd_fifo_q;
                                  uart_com_state <= s_wait_start;
                                  cmd_fifo_rden <= '0';
                    when others => null;
                    end case;
                    uart_com_counter <= uart_com_counter + 1;
                end if;
                
            when s_get_flash_data =>
                WRITE_FIFO_EMPTY_O <= '0';
                cmd_fifo_rden <= '0';
                if (WRITE_FIFO_RDEN_ROM_I = '1') or (WRITE_FIFO_RDEN_BOOT_I = '1') then
                    WRITE_FIFO_DATA_O <= cmd_fifo_q;
                    cmd_fifo_rden <= '1';
                    uart_com_counter <= uart_com_counter + 1;
                    if uart_com_counter = 255 then
                        uart_com_state <= s_wait_flash;
                        WRITE_FIFO_EMPTY_O <= '1';
                    end if;
                end if;
                
                -- on cycle cmd_fifo_rden high if there are no valid data
                if (cmd_fifo_data_valid(0) = '0') and (cmd_fifo_rden = '0') then
                    cmd_fifo_rden <= '1';
                end if;
                
            when s_write_flash =>
                WRITE_FIFO_EMPTY_O <= '0';
                if FLASH_CMD_ACK_I = '1' then
                    FLASH_CMD_EN_BOOT_O <= '0';
                    FLASH_CMD_EN_ROM_O <= '0';
                    uart_com_state <= s_get_flash_data;
                end if;
                
            when s_erase_flash =>
                if FLASH_CMD_ACK_I = '1' then
                    FLASH_CMD_EN_BOOT_O <= '0';
                    FLASH_CMD_EN_ROM_O <= '0';
                    uart_com_state <= s_wait_flash;
                end if;
            
            when s_wait_flash =>
                cmd_fifo_rden <= '0';
                if flash_cmd_rdy = '1' then
                    uart_com_state <= s_send_ack;
                end if;
                
            when s_read_flash =>
                if FLASH_CMD_ACK_I = '1' then
                    FLASH_CMD_EN_BOOT_O <= '0';
                    FLASH_CMD_EN_ROM_O <= '0';
                end if;
                if flash_data_valid = '1' then
                    uart_com_state <= s_send_flash_data;
                    flash_read_data <= flash_data;
                    uart_com_counter <= (others => '0');
                    uart_com_addr <= std_logic_vector(unsigned(uart_com_addr) + 1);
                end if;
                
            when s_send_flash_data =>
                uart_tx_enable <= '1';
                uart_tx_data <= flash_read_data(7 downto 0);
                uart_tx_valid <= '1';
                if uart_tx_ack = '1' then
                    flash_read_data <= x"00" & flash_read_data(31 downto 8);
                    uart_com_counter <= uart_com_counter + 1;
                    if uart_com_counter = 3 then
                        uart_tx_valid <= '0';
                        data_counter <= data_counter + 1;
                        if data_counter = 63 then
                            uart_tx_enable <= '0';
                            uart_com_state <= s_wait_start;
                        else
                            uart_com_state <= s_read_flash;
                            if uart_com_addr(24) = '1' then
                                FLASH_CMD_EN_BOOT_O <= '1';
                            else
                                FLASH_CMD_EN_ROM_O <= '1';
                            end if;
                            FLASH_CMD_ADDR_O <= uart_com_addr(FLASH_CMD_ADDR_O'range);
                        end if;
                    end if;
                end if;
                
            when s_read_sram =>
                MEM_CYC_O <= '1';
                MEM_STB_O <= '1';
                MEM_ADR_O <= uart_com_addr(MEM_ADR_O'range);
                if MEM_ACK_I = '1' then
                    MEM_CYC_O <= '0';
                    MEM_STB_O <= '0';
                    sram_read_data <= MEM_DAT_I;
                    uart_com_state <= s_send_sram_data;
                    uart_com_counter <= (others => '0');
                    uart_com_addr <= std_logic_vector(unsigned(uart_com_addr) + 1);
                end if;
                
            when s_get_sram_data =>
                cmd_fifo_rden <= '1';
                if cmd_fifo_data_valid(0) = '1' then
                    data_counter <= data_counter + 1;
                    if data_counter = 0 then
                        MEM_DAT_O(7 downto 0) <= cmd_fifo_q;
                    else
                        MEM_DAT_O(15 downto 8) <= cmd_fifo_q;
                        uart_com_state <= s_write_sram;
                        cmd_fifo_rden <= '0';
                    end if;
                end if;
                
            when s_write_sram =>
                MEM_CYC_O <= '1';
                MEM_STB_O <= '1';
                MEM_WE_O <= '1';
                MEM_ADR_O <= uart_com_addr(MEM_ADR_O'range);
                if MEM_ACK_I = '1' then
                    MEM_CYC_O <= '0';
                    MEM_STB_O <= '0';
                    MEM_WE_O <= '0';
                    if uart_com_counter = 127 then
                        uart_com_state <= s_send_ack;
                    else
                        uart_com_state <= s_get_sram_data;
                        cmd_fifo_rden <= '1';
                    end if;
                    uart_com_counter <= uart_com_counter + 1;
                    data_counter <= (others => '0');
                    uart_com_addr <= std_logic_vector(unsigned(uart_com_addr) + 1);
                end if;
            
            when s_send_sram_data =>
                uart_tx_enable <= '1';
                uart_tx_data <= sram_read_data(7 downto 0);
                
                uart_tx_valid <= '1';
                if uart_tx_ack = '1' then
                    sram_read_data <= x"00" & sram_read_data(15 downto 8);
                    uart_com_counter <= uart_com_counter + 1;
                    if uart_com_counter = 1 then
                        uart_tx_valid <= '0';
                        data_counter <= data_counter + 1;
                        if data_counter = 127 then
                            uart_tx_enable <= '0';
                            uart_com_state <= s_wait_start;
                        else
                            uart_com_state <= s_read_sram;
                        end if;
                    end if;
                end if;
                
            when s_send_ack =>
                uart_tx_enable <= '1';
                uart_tx_valid <= '1';
                uart_tx_data <= x"01";
                if uart_tx_ack = '1' then
                    uart_tx_enable <= '0';
                    uart_tx_valid <= '0';
                    uart_com_state <= s_wait_start;
                end if;
                
            when s_get_efb_len =>
                if cmd_fifo_data_valid(0) = '1' then
                    uart_com_counter <= unsigned(cmd_fifo_q);
                    if efb_we = '1' then
                        uart_com_state <= s_get_efb_data;
                    else                    cmd_fifo_rden <= '0';
                        EFB_CYC_O <= '1';
                        EFB_STB_O <= '1';
                        EFB_ADR_O <= uart_com_addr(EFB_ADR_O'range);
                        uart_com_state <= s_read_efb;
                        uart_tx_enable <= '1';
                    end if;
                end if;
                
            when s_get_efb_data =>
                if cmd_fifo_data_valid(0) = '1' then
                    cmd_fifo_rden <= '0';
                    EFB_DAT_O <= cmd_fifo_q;
                    EFB_CYC_O <= '1';
                    EFB_STB_O <= '1';
                    EFB_ADR_O <= uart_com_addr(EFB_ADR_O'range);
                    uart_com_state <= s_write_efb;
                end if;
                
            when s_write_efb =>
                if EFB_ACK_I = '1' then
                    EFB_CYC_O <= '0';
                    EFB_STB_O <= '0';
                    uart_com_counter <= uart_com_counter - 1;
                    if uart_com_counter = 0 then
                        uart_com_state <= s_wait_start;
                    else
                        uart_com_state <= s_get_efb_data;
                        cmd_fifo_rden <= '1';
                    end if;
                end if;
                
            when s_read_efb =>
                if EFB_ACK_I = '1' then
                    EFB_CYC_O <= '0';
                    EFB_STB_O <= '0';
                    uart_tx_valid <= '1';
                    uart_tx_data <= EFB_DAT_I;
                    uart_com_state <= s_send_efb_data;
                end if;
                
            when s_send_efb_data =>
                if uart_tx_ack = '1' then
                    uart_tx_valid <= '0';
                    uart_com_counter <= uart_com_counter - 1;
                    if uart_com_counter = 0 then
                        uart_com_state <= s_wait_start;
                        uart_tx_enable <= '0';
                    else 
                        EFB_CYC_O <= '1';
                        EFB_STB_O <= '1';
                        EFB_ADR_O <= uart_com_addr(EFB_ADR_O'range);
                        uart_com_state <= s_read_efb;
                    end if;
                end if;
                
            when s_send_version =>
                uart_tx_enable <= '1';
                uart_tx_valid <= '1';
                case uart_com_counter is
                when x"00" =>
                    uart_tx_data <= fpga_Version(31 downto 24);
                when x"01" =>
                    uart_tx_data <= fpga_Version(23 downto 16);
                when x"02" =>
                    uart_tx_data <= fpga_Version(15 downto 8);
                when others =>
                    uart_tx_data <= fpga_Version(7 downto 0);
                end case;
                if uart_tx_ack = '1' then
                    uart_com_counter <= uart_com_counter + 1;
                    if uart_com_counter = 3 then
                        uart_com_state <= s_wait_start;
                        uart_tx_enable <= '0';
                        uart_tx_valid <= '0';
                    end if;
                end if;
                
            when s_set_rtc =>
                if cmd_fifo_data_valid(0) = '1' then
                    case uart_com_counter is
                    when x"00" =>
                        RTC_SEC_O <= cmd_fifo_q(RTC_SEC_O'range);
                        
                    when x"01" =>
                        RTC_MIN_O <= cmd_fifo_q(RTC_MIN_O'range);
                        
                    when x"02" =>
                        RTC_HOUR_O <= cmd_fifo_q(RTC_HOUR_O'range);
                        
                    when x"03" =>
                        RTC_WEEKDAY_O <= cmd_fifo_q(RTC_WEEKDAY_O'range);
                        
                    when x"04" =>
                        RTC_DATE_O<= cmd_fifo_q(RTC_DATE_O'range);
                        
                    when x"05" =>
                        RTC_MONTH_O <= cmd_fifo_q(RTC_MONTH_O'range);
                        
                    when x"06" =>
                        RTC_YEAR_O <= cmd_fifo_q;
                        RTC_TIME_SET_O <= '1';
                        cmd_fifo_rden <= '0';
                        uart_com_state <= s_wait_start;
                        
                    when others => null;
                    end case;
                    uart_com_counter <= uart_com_counter + 1;
                end if;
                
            when s_byp_mode =>
                if BYP_ENABLE_I = '0' then
                    uart_com_state <= s_wait_start;
                end if;
                
            when s_invalid =>
                uart_packet_counter <= (others => '0');
                if cmd_fifo_reset = '0' then
                    uart_com_state <= s_wait_start;
                end if;
                
            when others => null;
            end case;
        end if;
    end process;

end Behavioral;