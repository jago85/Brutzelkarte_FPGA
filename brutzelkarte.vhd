library	ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lattice;
use lattice.all;

entity brutzelkarte is
port (
    CLK_I               : in std_logic;
    RST_I               : in std_logic;
    
    N64_ALEH_I          : in std_logic;
    N64_ALEL_I          : in std_logic;
    N64_READn_I         : in std_logic;
    N64_WRITEn_I        : in std_logic;
    
    N64_AD_IO           : inout std_logic_vector(15 downto 0);
    
    CIC_FAST_CLOCK_I    : in std_logic;
    CIC_REGION_I        : in std_logic;
    N64_CIC_DCLK_I      : in std_logic;
    N64_CIC_D_IO        : inout std_logic;
    
	N64_SI_CLK_I        : in std_logic;
    N64_S_DAT_IO        : inout std_logic;
    
    N64_COLD_RESET_I    : in std_logic;
    N64_NMI_I           : in std_logic;
    
    -- QSPI
    BOOT_CSN_O          : out std_logic;
    BOOT_SCK_O          : out std_logic;
    BOOT_DQ_IO          : inout std_logic_vector (3 downto 0);
    
    ROM_CSN_O           : out std_logic_vector(1 downto 0);
    ROM_SCK_O           : out std_logic;
    ROM_DQ_IO           : inout std_logic_vector (3 downto 0);
    
    -- SRAM
    RAM_ADDR_O          : out std_logic_vector(16 downto 0);
    RAM_DATA_IO         : inout std_logic_vector(15 downto 0);
    RAM_CE_O            : out std_logic;
    RAM_NWE_O           : out std_logic;
    RAM_NOE_O           : out std_logic;
    
    -- USB-UART
    USB_DETECT_I        : in std_logic;
    UART_RTS_I          : in std_logic;
    UART_RX_I           : in std_logic;
    UART_TX_O           : out std_logic;
    
    -- RTC (I2C)
    RTC_SDA_IO          : inout std_logic;
    RTC_SCL_IO          : inout std_logic;
    
    -- Testpoints
    TP1_O               : out std_logic;
    TP2_O               : out std_logic;
    TP3_O               : out std_logic;
    TP4_O               : out std_logic;
    
    -- LEDs
    LED_O               : out std_logic_vector(3 downto 0)
);
end entity brutzelkarte;

architecture Behavioral of brutzelkarte is
    
    component w25q64
        Port ( 
            CLK_I               : in std_logic;
            RESET_I             : in std_logic;
                
            CMD_I               : in std_logic_vector(1 downto 0);
            CMD_ADDR_I          : in std_logic_vector(20 downto 0);
            CMD_EN_I            : in std_logic;
            CMD_RDY_O           : out std_logic;
            
            DATA_READ_O         : out std_logic_vector(31 downto 0);
            DATA_READ_VALID_O   : out std_logic;
            READ_CONTINUOUS_I   : in std_logic;
            
            WRITE_FIFO_EMPTY_I  : in std_logic;
            WRITE_FIFO_DATA_I   : in std_logic_vector(7 downto 0);
            WRITE_FIFO_RDEN_O   : out std_logic;
            
            -- QSPI
            CSN_O               : out std_logic;
            SCK_O               : out std_logic;
            DQ_IO               : inout std_logic_vector (3 downto 0)
        );
    end component;
    
    component s25fl256s_x2
    Port ( 
        CLK_I               : in std_logic;
        RESET_I             : in std_logic;
            
        CMD_I               : in std_logic_vector(1 downto 0);
        CMD_ADDR_I          : in std_logic_vector(23 downto 0);
        CMD_EN_I            : in std_logic;
        CMD_RDY_O           : out std_logic;
        
        DATA_READ_O         : out std_logic_vector(31 downto 0);
        DATA_READ_VALID_O   : out std_logic;
        READ_CONTINUOUS_I   : in std_logic;
        
        WRITE_FIFO_EMPTY_I  : in std_logic;
        WRITE_FIFO_DATA_I   : in std_logic_vector(7 downto 0);
        WRITE_FIFO_RDEN_O   : out std_logic;
        
        -- QSPI
        CSN_O               : out std_logic_vector (1 downto 0);
        SCK_O               : out std_logic;
        DQ_IO               : inout std_logic_vector (3 downto 0)
    );
    end component;
    
    component rom_buffer
        port (WrAddress: in  std_logic_vector(7 downto 0); 
            RdAddress: in  std_logic_vector(7 downto 0); 
            Data: in  std_logic_vector(15 downto 0); WE: in  std_logic; 
            RdClock: in  std_logic; RdClockEn: in  std_logic; 
            Reset: in  std_logic; WrClock: in  std_logic; 
            WrClockEn: in  std_logic; Q: out  std_logic_vector(15 downto 0));
    end component;
    
    component n64_eeprom
    port (
        CLK_I            : in    std_logic;
        RST_I            : in    std_logic;
        
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
        RTC_SEC_I        : in std_logic_vector(6 downto 0);
        RTC_MIN_I        : in std_logic_vector(6 downto 0);
        RTC_HOUR_I       : in std_logic_vector(5 downto 0);
        RTC_WEEKDAY_I    : in std_logic_vector(2 downto 0);
        RTC_DATE_I       : in std_logic_vector(5 downto 0);
        RTC_MONTH_I      : in std_logic_vector(4 downto 0);
        RTC_YEAR_I       : in std_logic_vector(7 downto 0);
        
        -- data to RTC
        RTC_TIME_SET_O   : out std_logic;
        RTC_TIME_ACK_I   : in std_logic;
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
    end component;
    
    component N64_FlashRam
    Port (
           CLK_I            : in  std_logic;
           RST_I            : in  std_logic;

           N64_ADDR_I       : in  std_logic_vector(31 downto 0);
           N64_ADDR_LATCH_I : in  std_logic_vector(31 downto 0);
           N64_ADDR_VALID_I : in  std_logic;

           N64_ALEH_I       : in  std_logic;
           N64_ALEL_I       : in  std_logic;
           N64_RD_I         : in  std_logic;
           N64_RD_LAST_I    : in  std_logic;
           N64_WR_I         : in  std_logic;
           N64_WR_LAST_I    : in  std_logic;
           N64_AD_I         : in  std_logic_vector(15 downto 0);
           N64_AD_O         : out std_logic_vector(15 downto 0);
           
           MEM_CYC_O        : out std_logic;
           MEM_STB_O        : out std_logic;
           MEM_WE_O         : out std_logic;
           MEM_ACK_I        : in  std_logic;
           MEM_ADDR_O       : out std_logic_vector(15 downto 0);
           MEM_DAT_O        : out std_logic_vector(15 downto 0);
           MEM_DAT_I        : in  std_logic_vector(15 downto 0)
    );
    end component;
	
    component sram_controller_wb
    port (
        CLK_I       : in std_logic;
        RST_I       : in std_logic;
                    
        CYC_I       : in std_logic;
        STB_I       : in std_logic;
        WE_I        : in std_logic;
        ACK_O       : out std_logic;
        ADR_I       : in std_logic_vector(16 downto 0);
        DAT_I       : in std_logic_vector(15 downto 0);
        DAT_O       : out std_logic_vector(15 downto 0);
        
        RAM_ADDR_O  : out std_logic_vector(16 downto 0);
        RAM_DATA_IO : inout std_logic_vector(15 downto 0);
        RAM_CE_O  : out std_logic;
        RAM_NWE_O   : out std_logic;
        RAM_NOE_O   : out std_logic
    );
    end component;
    
    component prio_arbiter_single_slave
    generic (
        NUM_MASTERS : natural := 4;
        ADR_WIDTH   : natural := 32;
        DATA_WIDTH  : natural := 32
    );
    port (
        CLK_I : in std_logic;
        RST_I : in std_logic;
        
        MSTR_CYC_I  : in  std_logic_vector(NUM_MASTERS - 1 downto 0);
        MSTR_STB_I  : in  std_logic_vector(NUM_MASTERS - 1 downto 0);
        MSTR_WE_I   : in  std_logic_vector(NUM_MASTERS - 1 downto 0);
        MSTR_ACK_O  : out std_logic_vector(NUM_MASTERS - 1 downto 0);
        MSTR_ADR_I  : in  std_logic_vector(NUM_MASTERS * ADR_WIDTH - 1 downto 0);
        MSTR_DAT_I  : in  std_logic_vector(NUM_MASTERS * DATA_WIDTH - 1 downto 0);
        
        SLV_CYC_O   : out std_logic;
        SLV_STB_O   : out std_logic;
        SLV_WE_O    : out std_logic;
        SLV_ACK_I   : in  std_logic;
        SLV_ADR_O   : out std_logic_vector(ADR_WIDTH - 1 downto 0);
        SLV_DAT_O   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        
    );
    end component;
    
    component N64_CIC
        Port ( CLK_I : in STD_LOGIC;
               REGION_I : in STD_LOGIC;
               N64_CIC_DCLK_I : in STD_LOGIC;
               N64_CIC_D_IO : inout STD_LOGIC;
               N64_CIC_RESET_I : in STD_LOGIC);
    end component;
    
    component uart_access
    generic (
        clock_frequency         : positive;
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
        FLASH_ADDR_WIDTH_I      : in std_logic_vector(7 downto 0);
        
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
        MEM_ADDR_WIDTH_I        : in std_logic_vector(7 downto 0);
    
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
    
        UART_TX_ACTIVE_O        : out std_logic;
        
        USB_DETECT_I            : in std_logic;
        UART_RTS_I              : in std_logic;
        UART_TX_O               : out std_logic;
        UART_RX_I               : in std_logic
    );
    end component;
    
    component uart_fifo_level_tracking
    port (
        CLK_I           : in std_logic;
        RST_I           : in std_logic;
        RD_EN_I         : in std_logic;
        WR_EN_I         : in std_logic;
        DATA_I          : in std_logic_vector(7 downto 0);
        Q_O             : out std_logic_vector(7 downto 0);
        ALMOST_EMPTY_O  : out std_logic;
        EMPTY_O         : out std_logic;
        ALMOST_FULL_O   : out std_logic;
        FULL_O          : out std_logic;
        
        FREE_COUNT_O    : out std_logic_vector(10 downto 0);
        FULL_COUNT_O    : out std_logic_vector(10 downto 0)
    );
    end component;
    
    component efb0
    port (
        wb_clk_i    : in    std_logic;
        wb_rst_i    : in    std_logic; 
        wb_cyc_i    : in    std_logic;
        wb_stb_i    : in    std_logic; 
        wb_we_i     : in    std_logic; 
        wb_adr_i    : in    std_logic_vector(7 downto 0); 
        wb_dat_i    : in    std_logic_vector(7 downto 0); 
        wb_dat_o    : out   std_logic_vector(7 downto 0); 
        wb_ack_o    : out   std_logic;
        wbc_ufm_irq : out   std_logic
    );
    end component;
    
    component mcp7940n
    port (
        CLK_I        : in std_logic;
        RESET_I      : in std_logic;

        TIME_VALID_O : out std_logic;
        TIME_ACK_O   : out std_logic;
        SEC_O        : out std_logic_vector(6 downto 0);
        MIN_O        : out std_logic_vector(6 downto 0);
        HOUR_O       : out std_logic_vector(5 downto 0);
        WEEKDAY_O    : out std_logic_vector(2 downto 0);
        DATE_O       : out std_logic_vector(5 downto 0);
        MONTH_O      : out std_logic_vector(4 downto 0);
        YEAR_O       : out std_logic_vector(7 downto 0);

        TIME_SET_I   : in std_logic;
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
    end component;
    
    constant FPGA_VERSION   : std_logic_vector(31 downto 0) := x"04000300";
    
    constant FLASH_CMD_NONE   : std_logic_vector(1 downto 0) := "00";
    constant FLASH_CMD_READ   : std_logic_vector(1 downto 0) := "01";
    constant FLASH_CMD_WRITE  : std_logic_vector(1 downto 0) := "10";
    constant FLASH_CMD_ERASE  : std_logic_vector(1 downto 0) := "11";
    
    -- address spaces
    constant CART_ROM_BASE_ADDR       : std_logic_vector(31 downto 0) := x"10000000";
    constant CART_SRAM_BASE_ADDR      : std_logic_vector(31 downto 0) := x"08000000";
    constant CART_REGISTER_BASE_ADDR  : std_logic_vector(31 downto 0) := x"18000000";
    
    -- cart register addresses
    constant CART_CONTROL_REG_ADDR    : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0000#);
    constant CART_CONTROL_REG_W1      : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_CONTROL_REG_ADDR) + 2);
    
    constant CART_VERSION_REG_ADDR    : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0004#);
    constant CART_VERSION_REG_W1      : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_VERSION_REG_ADDR) + 2);
    
    constant CART_ROMOFFSET_REG_ADDR  : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0008#);
    constant CART_ROMOFFSET_REG_W1    : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_ROMOFFSET_REG_ADDR) + 2);
    
    constant CART_SAVEOFFSET_REG_ADDR : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#000C#);
    constant CART_SAVEOFFSET_REG_W1   : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_SAVEOFFSET_REG_ADDR) + 2);
    
    constant CART_BACKUP_REG_ADDR     : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0010#);
    constant CART_BACKUP_REG_W1       : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_BACKUP_REG_ADDR) + 2);
    
    -- UART
    constant CART_UART_STATUS_REG_ADDR : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0014#);
    constant CART_UART_STATUS_REG_W1   : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_UART_STATUS_REG_ADDR) + 2);
    
    constant CART_UART_TX_FREE_REG_ADDR   : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0018#);
    constant CART_UART_TX_FREE_REG_W1     : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_UART_TX_FREE_REG_ADDR) + 2);
    
    constant CART_UART_RX_READY_REG_ADDR  : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#001C#);
    constant CART_UART_RX_READY_REG_W1    : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_UART_RX_READY_REG_ADDR) + 2);
    
    constant CART_UART_DATA_REG_ADDR       : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0020#);
    constant CART_UART_DATA_REG_W1         : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_UART_DATA_REG_ADDR) + 2);
    
    -- TX/RX data DMA address space
    constant CART_UART_DMA_ADDR           : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#1000#);
    
    constant CART_MAPPING0_REG_ADDR   : std_logic_vector(31 downto 0) := std_logic_vector(unsigned(CART_REGISTER_BASE_ADDR) + 16#0080#);
    
    -- Indices of cart control bits
    constant CART_CONTROL_FLASH_SEL         : natural := 0;
    constant CART_CONTROL_EEP_ENABLE        : natural := 1;
    constant CART_CONTROL_EEP_SEL           : natural := 2;
    constant CART_CONTROL_SRAM_ENABLE       : natural := 3;
    constant CART_CONTROL_FLASHRAM_ENABLE   : natural := 4;
    constant CART_CONTROL_MAPPING_ENABLE    : natural := 5;
    
    constant CART_CONTROL_UART_ENABLE       : natural := 6;
    constant CART_CONTROL_UART_FC_ENABLE    : natural := 7;
    
    -- Indices of cart uart status bits
    constant CART_UART_STATUS_TXNF         : natural := 0;
    constant CART_UART_STATUS_TXE          : natural := 1;
    constant CART_UART_STATUS_TXHE         : natural := 2;
    constant CART_UART_STATUS_TXACT        : natural := 3;
    
    constant CART_UART_STATUS_RXNE         : natural := 8;
    constant CART_UART_STATUS_RXF          : natural := 9;
    constant CART_UART_STATUS_RXHF         : natural := 10;
    constant CART_UART_STATUS_RXOF         : natural := 11;
    
    signal usb_detect_ff1, usb_detect_ff2 : std_logic;
    
    signal cold_reset_ff1, cold_reset_ff2 : std_logic;
    signal n64_reset : std_logic;
    signal nmi_ff1, nmi_ff2 : std_logic;
    signal aleh_ff1, aleh_ff2 : std_logic;
    signal alel_ff1, alel_ff2 : std_logic;
    signal read_ff1, read_ff2, read_last : std_logic;
    signal write_ff1, write_ff2, write_last : std_logic;
    signal ad_ff1, ad_ff2 : std_logic_vector(15 downto 0);
    
    signal cart_addr : std_logic_vector(31 downto 0);
    signal cart_addr_latch : std_logic_vector(31 downto 0);
    signal cart_addr_cnt : unsigned(13 downto 0);
    
    signal addr_valid : std_logic;
    
    signal rom_cs : std_logic;
    signal sram_cs : std_logic;
    signal ci_cs : std_logic;
    signal ci_data : std_logic_vector(31 downto 0);
    signal ci_out : std_logic_vector(15 downto 0);
    
    signal flash_cmd            : std_logic_vector(1 downto 0);
    signal flash_cmd_addr       : std_logic_vector(23 downto 0);
    signal flash_cmd_en_boot    : std_logic;
    signal flash_cmd_en_rom     : std_logic;
    signal flash_cmd_rdy        : std_logic;
    signal flash_cmd_rdy_boot   : std_logic;
    signal flash_cmd_rdy_rom    : std_logic;
    signal flash_data           : std_logic_vector(31 downto 0);
    signal flash_data_boot      : std_logic_vector(31 downto 0);
    signal flash_data_rom       : std_logic_vector(31 downto 0);
    signal flash_data_valid     : std_logic;
    signal flash_data_valid_boot: std_logic;
    signal flash_data_valid_rom : std_logic;
    signal flash_read_continous : std_logic;
    
    type rom_state_t is (
        s_idle,
        s_cmd,
        s_data,
        s_done,
        s_uart_cmd,
        s_uart_wait
    );
    
    signal rom_state : rom_state_t;
    signal flash_last_addr : std_logic_vector(23 downto 0);
    signal rom_write_control : std_logic;
    signal rom_write_data   : std_logic_vector(31 downto 0);
    
    signal rom_buffer_wraddr : std_logic_vector(7 downto 0);
    signal rom_buffer_rdaddr : std_logic_vector(7 downto 0);
    signal rom_buffer_data   : std_logic_vector(15 downto 0);
    signal rom_buffer_we     : std_logic;
    signal rom_buffer_q      : std_logic_vector(15 downto 0);
    
    signal mem_cyc : std_logic;
    signal mem_stb : std_logic;    
    signal mem_we : std_logic;    
    signal mem_ack : std_logic;    
    signal mem_adr : std_logic_vector(16 downto 0);
    signal mem_dat_to_ram : std_logic_vector(15 downto 0);
    signal mem_dat_from_ram : std_logic_vector(15 downto 0);
    
    signal eep_cyc : std_logic;
    signal eep_stb : std_logic;    
    signal eep_we : std_logic;    
    signal eep_ack : std_logic;    
    signal eep_adr : std_logic_vector(9 downto 0);
    signal eep_mem_adr : std_logic_vector(16 downto 0);
    signal eep_dat_to_ram : std_logic_vector(15 downto 0);
    
    signal sram_cyc : std_logic;
    signal sram_stb : std_logic;    
    signal sram_we : std_logic;    
    signal sram_ack : std_logic;    
    signal sram_adr : std_logic_vector(15 downto 0);
    signal sram_mem_adr : std_logic_vector(16 downto 0);
    signal sram_dat_to_ram : std_logic_vector(15 downto 0);
    
    signal flashram_reset : std_logic;
    signal flashram_cyc : std_logic;
    signal flashram_stb : std_logic;    
    signal flashram_we : std_logic;    
    signal flashram_ack : std_logic;    
    signal flashram_adr : std_logic_vector(15 downto 0);
    signal flashram_mem_adr : std_logic_vector(16 downto 0);
    signal flashram_dat_to_ram : std_logic_vector(15 downto 0);
    
    signal uart_cyc : std_logic;
    signal uart_stb : std_logic;    
    signal uart_we : std_logic;    
    signal uart_ack : std_logic;    
    signal uart_adr : std_logic_vector(16 downto 0);
    signal uart_dat_to_ram : std_logic_vector(15 downto 0);
    
    signal ram_read_start : std_logic;
    signal ram_write_start : std_logic;
    signal sram_ad_out : std_logic_vector(15 downto 0);
    
    signal flashram_ad_out : std_logic_vector(15 downto 0);
    
    signal mstr_cyc     : std_logic_vector(3 downto 0);
    signal mstr_stb     : std_logic_vector(3 downto 0);
    signal mstr_we      : std_logic_vector(3 downto 0);
    signal mstr_ack     : std_logic_vector(3 downto 0);
    signal mstr_adr     : std_logic_vector(4 * 17 - 1 downto 0);
    signal mstr_dat_in  : std_logic_vector(4 * 16 - 1 downto 0);
    
    signal uart_flash_cmd               : std_logic_vector(1 downto 0);
    signal uart_flash_cmd_addr          : std_logic_vector(23 downto 0);
    signal uart_flash_cmd_en_boot       : std_logic;
    signal uart_flash_cmd_en_rom        : std_logic;
    signal uart_flash_cmd_ack           : std_logic;

    signal flash_write_fifo_empty       : std_logic;
    signal flash_write_fifo_data        : std_logic_vector(7 downto 0);
    signal flash_write_fifo_rden_boot   : std_logic;
    signal flash_write_fifo_rden_rom    : std_logic;
    
    signal efb_cyc : std_logic;
    signal efb_stb : std_logic;
    signal efb_we : std_logic;
    signal efb_ack : std_logic;
    signal efb_adr : std_logic_vector(7 downto 0);
    signal efb_dat_i : std_logic_vector(7 downto 0);
    signal efb_dat_o : std_logic_vector(7 downto 0);
    
    signal cart_control_reg : std_logic_vector(7 downto 0);
        -- [0] Flash select: 0 = BOOT, 1 = ROM
        -- [1] EEP enable: 0 = dis, 1 = en
        -- [2] EEP select: 0 = 4Kb, 1 = 16Kb
        -- [3] SRAM enable: 0 = dis, 1 = en
        -- [4] FLASHRAM enable: 0 = dis, 1 = en
        -- [5] MAPPING enable: 0 = dis, 1 = en
        -- [6] UART Enable: 0 = Disabled, 1 = Enabled
        -- [7] UART Flowcontrol Enable: 0 = Disabled, 1 = Enabled
        
    signal cart_rom_offset : std_logic_vector(5 downto 0);  -- position of the first ROM address in MiB
    signal cart_save_offset : std_logic_vector(7 downto 0); -- position of the first SRAM address in KiB
    signal cart_backup : std_logic_vector(31 downto 0); -- backup register for storing application data
        
    signal cart_uart_txd_reg : std_logic_vector(7 downto 0);
    signal cart_uart_txd_dma_reg : std_logic_vector(31 downto 0);
    signal cart_uart_txd_valid : std_logic;
    signal cart_uart_txd_ack : std_logic;
    
    type uart_tx_state_t is (
        s_uart_tx_idle,
        s_uart_tx_wait,
        s_uart_tx_read,
        s_uart_tx_ack
    );
    signal uart_tx_state : uart_tx_state_t;
    signal uart_tx_active : std_logic;
    signal uart_txfifo_rden : std_logic;
    signal uart_txfifo_wren : std_logic;
    signal uart_txfifo_q : std_logic_vector(7 downto 0);
    signal uart_txfifo_empty : std_logic;
    signal uart_txfifo_full : std_logic;
    signal uart_txfifo_almost_empty : std_logic;
    signal uart_txfifo_free_count : std_logic_vector(10 downto 0);
    
    signal uart_tx_dma_active : std_logic;
    signal uart_tx_dma_count : unsigned(1 downto 0);
    
    signal uart_rxfifo_rden       : std_logic;
    signal uart_rxfifo_wren       : std_logic;
    signal uart_rxfifo_data       : std_logic_vector(7 downto 0);
    signal uart_rxfifo_q          : std_logic_vector(7 downto 0);
    signal uart_rxfifo_empty      : std_logic;
    signal uart_rxfifo_almost_full: std_logic;
    signal uart_rxfifo_full       : std_logic;
    signal uart_rxfifo_overflow   : std_logic;
    signal uart_rxfifo_ready_count : std_logic_vector(10 downto 0);
    
    signal uart_rx_dma_buf        : std_logic_vector(15 downto 0);
    
    type uart_rxfifo_read_state_t is (
        s_uart_rxfifo_read_idle,
        s_uart_rxfifo_read_data0,
        s_uart_rxfifo_read_data1,
        s_uart_rxfifo_read_delay0
    );
    signal uart_rxfifo_read_state : uart_rxfifo_read_state_t;
    signal uart_rts : std_logic;
    
    type cart_mapping_reg_type is array (natural range <>) of std_logic_vector(7 downto 0);
    signal cart_mapping_regs : cart_mapping_reg_type (0 to 31);
    signal current_mapping : std_logic_vector(7 downto 0);
    
    signal rtc_time_valid : std_logic;
    signal rtc_time_ack   : std_logic;
    signal rtc_sec        : std_logic_vector(6 downto 0);
    signal rtc_min        : std_logic_vector(6 downto 0);
    signal rtc_hour       : std_logic_vector(5 downto 0);
    signal rtc_weekday    : std_logic_vector(2 downto 0);
    signal rtc_date       : std_logic_vector(5 downto 0);
    signal rtc_month      : std_logic_vector(4 downto 0);
    signal rtc_year       : std_logic_vector(7 downto 0);
    
    signal rtc_set_enable : std_logic;
    signal rtc_set_sec : std_logic_vector(6 downto 0);
    signal rtc_set_min : std_logic_vector(6 downto 0);
    signal rtc_set_hour : std_logic_vector(5 downto 0);
    signal rtc_set_weekday : std_logic_vector(2 downto 0);
    signal rtc_set_date : std_logic_vector(5 downto 0);
    signal rtc_set_month : std_logic_vector(4 downto 0);
    signal rtc_set_year : std_logic_vector(7 downto 0);
    
    signal n64_to_rtc_set_enable : std_logic;
    signal n64_to_rtc_set_sec : std_logic_vector(6 downto 0);
    signal n64_to_rtc_set_min : std_logic_vector(6 downto 0);
    signal n64_to_rtc_set_hour : std_logic_vector(5 downto 0);
    signal n64_to_rtc_set_weekday : std_logic_vector(2 downto 0);
    signal n64_to_rtc_set_date : std_logic_vector(5 downto 0);
    signal n64_to_rtc_set_month : std_logic_vector(4 downto 0);
    signal n64_to_rtc_set_year : std_logic_vector(7 downto 0);
    
    signal uart_to_rtc_set_enable : std_logic;
    signal uart_to_rtc_set_sec : std_logic_vector(6 downto 0);
    signal uart_to_rtc_set_min : std_logic_vector(6 downto 0);
    signal uart_to_rtc_set_hour : std_logic_vector(5 downto 0);
    signal uart_to_rtc_set_weekday : std_logic_vector(2 downto 0);
    signal uart_to_rtc_set_date : std_logic_vector(5 downto 0);
    signal uart_to_rtc_set_month : std_logic_vector(4 downto 0);
    signal uart_to_rtc_set_year : std_logic_vector(7 downto 0);
    
    attribute syn_state_machine : boolean;
	attribute syn_state_machine of Behavioral : architecture is true;	
	attribute syn_encoding : string;
	attribute syn_encoding of rom_state: signal is "onehot";
    
begin
    
    w25q64_inst : w25q64
    port map (
        CLK_I              => CLK_I,
        RESET_I            => RST_I,
        CMD_I              => flash_cmd,
        CMD_ADDR_I         => flash_cmd_addr(20 downto 0),
        CMD_EN_I           => flash_cmd_en_boot,
        CMD_RDY_O          => flash_cmd_rdy_boot,
        DATA_READ_O        => flash_data_boot,
        DATA_READ_VALID_O  => flash_data_valid_boot,
        READ_CONTINUOUS_I  => flash_read_continous,
        
        WRITE_FIFO_EMPTY_I => flash_write_fifo_empty,
        WRITE_FIFO_DATA_I  => flash_write_fifo_data,
        WRITE_FIFO_RDEN_O  => flash_write_fifo_rden_boot,
        
        CSN_O              => BOOT_CSN_O,
        SCK_O              => BOOT_SCK_O,
        DQ_IO              => BOOT_DQ_IO
    );
    
    s25fl256s_x2_inst : s25fl256s_x2
    port map (
        CLK_I              => CLK_I,
        RESET_I            => RST_I,
        CMD_I              => flash_cmd,
        CMD_ADDR_I         => flash_cmd_addr,
        CMD_EN_I           => flash_cmd_en_rom,
        CMD_RDY_O          => flash_cmd_rdy_rom,
        DATA_READ_O        => flash_data_rom,
        DATA_READ_VALID_O  => flash_data_valid_rom,
        READ_CONTINUOUS_I  => flash_read_continous,
        
        WRITE_FIFO_EMPTY_I => flash_write_fifo_empty,
        WRITE_FIFO_DATA_I  => flash_write_fifo_data,
        WRITE_FIFO_RDEN_O  => flash_write_fifo_rden_rom,
        
        -- QSPI
        CSN_O               => ROM_CSN_O,
        SCK_O               => ROM_SCK_O,
        DQ_IO               => ROM_DQ_IO
    );
    
    rom_buffer_inst : rom_buffer
    port map (
        WrAddress => rom_buffer_wraddr, 
        RdAddress => rom_buffer_rdaddr, 
        Data      => rom_buffer_data, 
        WE        => rom_buffer_we, 
        RdClock   => CLK_I, 
        RdClockEn => rom_cs, 
        Reset     => n64_reset, 
        WrClock   => CLK_I, 
        WrClockEn => '1', 
        Q         => rom_buffer_q
    );
    
    n64_reset <= not cold_reset_ff2;
    
    rom_buffer_rdaddr <= cart_addr(8 downto 1);
    
    n64_eeprom_inst : n64_eeprom
    port map (
        CLK_I            => CLK_I,
        RST_I            => RST_I,
        
        EEPROM_ENABLE_I  => cart_control_reg(CART_CONTROL_EEP_ENABLE),
        TYPE_I           => cart_control_reg(CART_CONTROL_EEP_SEL),
        MEM_CYC_O        => eep_cyc,
        MEM_STB_O        => eep_stb,
        MEM_WE_O         => eep_we,
        MEM_ACK_I        => eep_ack,
        MEM_ADR_O        => eep_adr,
        MEM_DAT_I        => mem_dat_from_ram,
        MEM_DAT_O        => eep_dat_to_ram,
    
        -- data from RTC
        RTC_TIME_VALID_I => rtc_time_valid,
        RTC_SEC_I        => rtc_sec,
        RTC_MIN_I        => rtc_min,
        RTC_HOUR_I       => rtc_hour,
        RTC_WEEKDAY_I    => rtc_weekday,
        RTC_DATE_I       => rtc_date,
        RTC_MONTH_I      => rtc_month,
        RTC_YEAR_I       => rtc_year,
        
        -- data to RTC
        RTC_TIME_SET_O   => n64_to_rtc_set_enable,
        RTC_TIME_ACK_I   => rtc_time_ack,
        RTC_SEC_O        => n64_to_rtc_set_sec,
        RTC_MIN_O        => n64_to_rtc_set_min,
        RTC_HOUR_O       => n64_to_rtc_set_hour,
        RTC_WEEKDAY_O    => n64_to_rtc_set_weekday,
        RTC_DATE_O       => n64_to_rtc_set_date,
        RTC_MONTH_O      => n64_to_rtc_set_month,
        RTC_YEAR_O       => n64_to_rtc_set_year,
        
        N64_S_CLK_I      => N64_SI_CLK_I,
        N64_S_DAT_IO     => N64_S_DAT_IO
    );
    
    N64_FlashRam_inst : N64_FlashRam
    port map (
        CLK_I            => CLK_I,
        RST_I            => flashram_reset,
        N64_ADDR_I       => cart_addr,
        N64_ADDR_LATCH_I => cart_addr_latch,
        N64_ADDR_VALID_I => addr_valid,
        N64_ALEH_I       => aleh_ff2,
        N64_ALEL_I       => alel_ff2,
        N64_RD_I         => read_ff2,
        N64_RD_LAST_I    => read_last,
        N64_WR_I         => write_ff2,
        N64_WR_LAST_I    => write_last,
        N64_AD_I         => ad_ff2,
        N64_AD_O         => flashram_ad_out,
        
        MEM_CYC_O        => flashram_cyc,
        MEM_STB_O        => flashram_stb,
        MEM_WE_O         => flashram_we,
        MEM_ACK_I        => flashram_ack,
        MEM_ADDR_O       => flashram_adr(15 downto 0),
        MEM_DAT_O        => flashram_dat_to_ram,
        MEM_DAT_I        => mem_dat_from_ram
    );
    
    flashram_mem_adr <= std_logic_vector(unsigned(flashram_adr) + (unsigned(cart_save_offset) & unsigned'("000000000")));
    sram_mem_adr <= std_logic_vector(unsigned(sram_adr) + (unsigned(cart_save_offset) & unsigned'("000000000")));
    eep_mem_adr <= std_logic_vector(unsigned(eep_adr) + (unsigned(cart_save_offset) & unsigned'("000000000")));
    
    mstr_cyc <= uart_cyc & flashram_cyc & sram_cyc & eep_cyc;
    mstr_stb <= uart_stb & flashram_stb & sram_stb & eep_stb;
    mstr_we <= uart_we & flashram_we & sram_we & eep_we;
    mstr_adr <= uart_adr & flashram_mem_adr & sram_mem_adr & eep_mem_adr;
    mstr_dat_in <= uart_dat_to_ram & flashram_dat_to_ram & sram_dat_to_ram & eep_dat_to_ram;
    
    uart_ack <= mstr_ack(3);
    flashram_ack <= mstr_ack(2);
    sram_ack <= mstr_ack(1);
    eep_ack <= mstr_ack(0);
    
    arbiter_inst : prio_arbiter_single_slave
    generic map (
        NUM_MASTERS => 4,
        ADR_WIDTH => 17,
        DATA_WIDTH => 16
    )
    port map (
        CLK_I       => CLK_I,
        RST_I       => RST_I,
        
        MSTR_CYC_I  => mstr_cyc,
        MSTR_STB_I  => mstr_stb,
        MSTR_WE_I   => mstr_we,
        MSTR_ACK_O  => mstr_ack,
        MSTR_ADR_I  => mstr_adr,
        MSTR_DAT_I  => mstr_dat_in,
        
        SLV_CYC_O   => mem_cyc,
        SLV_STB_O   => mem_stb,
        SLV_WE_O    => mem_we,
        SLV_ACK_I   => mem_ack,
        SLV_ADR_O   => mem_adr,
        SLV_DAT_O   => mem_dat_to_ram
    );
	
    sram_controller_wb_inst : sram_controller_wb
    port map (
        CLK_I       => CLK_I,
        RST_I       => RST_I,
        CYC_I       => mem_cyc,
        STB_I       => mem_stb,
        WE_I        => mem_we,
        ACK_O       => mem_ack,
        ADR_I       => mem_adr,
        DAT_I       => mem_dat_to_ram,
        DAT_O       => mem_dat_from_ram,
        RAM_ADDR_O  => RAM_ADDR_O,
        RAM_DATA_IO => RAM_DATA_IO,
        RAM_CE_O  => RAM_CE_O,
        RAM_NWE_O   => RAM_NWE_O,
        RAM_NOE_O   => RAM_NOE_O
    );
    
    N64_CIC_D_IO <= 'Z';
    N64_CIC_inst : N64_CIC
    Port Map (
        CLK_I => CIC_FAST_CLOCK_I,
        REGION_I => CIC_REGION_I,
        N64_CIC_DCLK_I => N64_CIC_DCLK_I,
        N64_CIC_D_IO => N64_CIC_D_IO,
        N64_CIC_RESET_I => cold_reset_ff2
    );
    
    uart_rts <= UART_RTS_I when cart_control_reg(CART_CONTROL_UART_FC_ENABLE) = '1' else '0';
    
    uart_access_inst : uart_access
    generic map (
        clock_frequency         => 79_800_000,
        fpga_Version            => FPGA_VERSION
    )
    port map (
        CLK_I                   => CLK_I,
        RESET_I                 => RST_I,

        FLASH_CMD_O             => uart_flash_cmd,
        FLASH_CMD_ADDR_O        => uart_flash_cmd_addr,
        FLASH_CMD_EN_BOOT_O     => uart_flash_cmd_en_boot,
        FLASH_CMD_RDY_BOOT_I    => flash_cmd_rdy_boot,
        FLASH_CMD_EN_ROM_O      => uart_flash_cmd_en_rom,
        FLASH_CMD_RDY_ROM_I     => flash_cmd_rdy_rom,
        FLASH_CMD_ACK_I         => uart_flash_cmd_ack,
        FLASH_DATA_BOOT_I       => flash_data_boot,
        FLASH_DATA_ROM_I        => flash_data_rom,
        FLASH_DATA_VALID_BOOT_I => flash_data_valid_boot,
        FLASH_DATA_VALID_ROM_I  => flash_data_valid_rom,
        FLASH_ADDR_WIDTH_I      => x"1A",

        WRITE_FIFO_EMPTY_O      => flash_write_fifo_empty,
        WRITE_FIFO_DATA_O       => flash_write_fifo_data,
        WRITE_FIFO_RDEN_BOOT_I  => flash_write_fifo_rden_boot,
        WRITE_FIFO_RDEN_ROM_I   => flash_write_fifo_rden_rom,

        MEM_CYC_O               => uart_cyc,
        MEM_STB_O               => uart_stb,
        MEM_WE_O                => uart_we,
        MEM_ACK_I               => uart_ack,
        MEM_ADR_O               => uart_adr,
        MEM_DAT_O               => uart_dat_to_ram,
        MEM_DAT_I               => mem_dat_from_ram,
        MEM_ADDR_WIDTH_I        => x"12",
        
        EFB_CYC_O               => efb_cyc,
        EFB_STB_O               => efb_stb,
        EFB_WE_O                => efb_we,
        EFB_ACK_I               => efb_ack,
        EFB_ADR_O               => efb_adr,
        EFB_DAT_O               => efb_dat_i,
        EFB_DAT_I               => efb_dat_o,
        
        RTC_TIME_SET_O          => uart_to_rtc_set_enable,
        RTC_TIME_ACK_I          => rtc_time_ack,
        RTC_SEC_O               => uart_to_rtc_set_sec,
        RTC_MIN_O               => uart_to_rtc_set_min,
        RTC_HOUR_O              => uart_to_rtc_set_hour,
        RTC_WEEKDAY_O           => uart_to_rtc_set_weekday,
        RTC_DATE_O              => uart_to_rtc_set_date,
        RTC_MONTH_O             => uart_to_rtc_set_month,
        RTC_YEAR_O              => uart_to_rtc_set_year,
    
        -- bypass mode
        BYP_ENABLE_I            => cart_control_reg(CART_CONTROL_UART_ENABLE),
        BYP_TX_VALID_I          => cart_uart_txd_valid,
        BYP_TX_ACK_O            => cart_uart_txd_ack,
        BYP_TX_DATA_I           => uart_txfifo_q,        
        BYP_RX_DATA_O           => uart_rxfifo_data,
        BYP_RX_VALID_O          => uart_rxfifo_wren,
        
        UART_TX_ACTIVE_O        => uart_tx_active,
        
        USB_DETECT_I            => usb_detect_ff2,
        UART_RTS_I              => uart_rts,
        UART_TX_O               => UART_TX_O,
        UART_RX_I               => UART_RX_I
    );
    
    uart_txfifo_inst : uart_fifo_level_tracking
    port map (
        CLK_I           => CLK_I,
        RST_I           => not cart_control_reg(CART_CONTROL_UART_ENABLE),
        RD_EN_I         => uart_txfifo_rden,
        WR_EN_I         => uart_txfifo_wren,
        DATA_I          => cart_uart_txd_reg,
        Q_O             => uart_txfifo_q,
        ALMOST_EMPTY_O  => uart_txfifo_almost_empty,
        EMPTY_O         => uart_txfifo_empty,
        ALMOST_FULL_O   => open,
        FULL_O          => uart_txfifo_full,
        FREE_COUNT_O    => uart_txfifo_free_count,
        FULL_COUNT_O    => open
    );
    
    uart_rxfifo_inst : uart_fifo_level_tracking
    port map (
        CLK_I           => CLK_I,
        RST_I           => not cart_control_reg(CART_CONTROL_UART_ENABLE),
        RD_EN_I         => uart_rxfifo_rden,
        WR_EN_I         => uart_rxfifo_wren,
        DATA_I          => uart_rxfifo_data,
        Q_O             => uart_rxfifo_q,
        ALMOST_EMPTY_O  => open,
        EMPTY_O         => uart_rxfifo_empty,
        ALMOST_FULL_O   => uart_rxfifo_almost_full,
        FULL_O          => uart_rxfifo_full,
        FREE_COUNT_O    => open,
        FULL_COUNT_O    => uart_rxfifo_ready_count
    );
    
    efb0_inst : efb0
    port map (
        wb_clk_i    => CLK_I,
        wb_rst_i    => RST_I,
        wb_cyc_i    => efb_cyc,
        wb_stb_i    => efb_stb,
        wb_we_i     => efb_we,
        wb_adr_i    => efb_adr,
        wb_dat_i    => efb_dat_i,
        wb_dat_o    => efb_dat_o,
        wb_ack_o    => efb_ack,
        wbc_ufm_irq => open
    );
    
    mcp7940n_inst : mcp7940n
    port map (
        CLK_I        => CLK_I,
        RESET_I      => RST_I,

        TIME_VALID_O => rtc_time_valid,
        TIME_ACK_O   => rtc_time_ack,
        SEC_O        => rtc_sec,
        MIN_O        => rtc_min,
        HOUR_O       => rtc_hour,
        WEEKDAY_O    => rtc_weekday,
        DATE_O       => rtc_date,
        MONTH_O      => rtc_month,
        YEAR_O       => rtc_year,

        TIME_SET_I   => rtc_set_enable,
        SEC_I        => rtc_set_sec,
        MIN_I        => rtc_set_min,
        HOUR_I       => rtc_set_hour,
        WEEKDAY_I    => rtc_set_weekday,
        DATE_I       => rtc_set_date,
        MONTH_I      => rtc_set_month,
        YEAR_I       => rtc_set_year,

        I2C_SCL_IO   => RTC_SCL_IO,
        I2C_SDA_IO   => RTC_SDA_IO
    );
    
    LED_O <= write_ff2 & "0" & read_ff2 & n64_reset;
    TP1_O <= '0';
    TP2_O <= '0';
    TP3_O <= '0';
    TP4_O <= '0';
    
    process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if RST_I = '1' then
                cold_reset_ff1 <= '0';
                cold_reset_ff2 <= '0';
                
                usb_detect_ff1 <= '0';
                usb_detect_ff2 <= '0';
            else
                cold_reset_ff1 <= N64_COLD_RESET_I;
                cold_reset_ff2 <= cold_reset_ff1;
                
                usb_detect_ff1 <= USB_DETECT_I;
                usb_detect_ff2 <= usb_detect_ff1;
                
                if n64_reset = '1' then
                    nmi_ff1 <= '0';
                    nmi_ff2 <= '0';
                    aleh_ff1 <= '1';
                    aleh_ff2 <= '1';
                    alel_ff1 <= '0';
                    alel_ff2 <= '0';
                    read_ff1 <= '0';
                    read_ff2 <= '0';
                    write_ff1 <= '0';
                    write_ff2 <= '0';
                    ad_ff1 <= (others => '0');
                    ad_ff2 <= (others => '0');
                else
                    nmi_ff1 <= N64_NMI_I;
                    nmi_ff2 <= nmi_ff1;
                    aleh_ff1 <= N64_ALEH_I;
                    aleh_ff2 <= aleh_ff1;
                    alel_ff1 <= N64_ALEL_I;
                    alel_ff2 <= alel_ff1;
                    read_ff1 <= not N64_READn_I;
                    read_ff2 <= read_ff1;
                    write_ff1 <= not N64_WRITEn_I;
                    write_ff2 <= write_ff1;
                    ad_ff1 <= N64_AD_IO;
                    ad_ff2 <= ad_ff1;
                end if;

            end if;
        end if;
    end process;
    
    rom_buffer_data <= rom_write_data(15 downto 0) when rom_write_control = '1' else rom_write_data(31 downto 16);
    cart_addr <= cart_addr_latch(31 downto 15) & std_logic_vector(cart_addr_cnt) & "0";
    
    with cart_control_reg(CART_CONTROL_FLASH_SEL) select flash_data <=
        flash_data_boot when '0',
        flash_data_rom when others;
    
    with cart_control_reg(CART_CONTROL_FLASH_SEL) select flash_cmd_rdy <=
        flash_cmd_rdy_boot when '0',
        flash_cmd_rdy_rom when others;
    
    with cart_control_reg(CART_CONTROL_FLASH_SEL) select flash_data_valid <=
        flash_data_valid_boot when '0',
        flash_data_valid_rom when others;
    
    flashram_reset <= not cart_control_reg(CART_CONTROL_FLASHRAM_ENABLE);
    
    
    rtc_set_enable <= n64_to_rtc_set_enable or uart_to_rtc_set_enable;
    
    with uart_to_rtc_set_enable select rtc_set_sec <=
        n64_to_rtc_set_sec when '0',
        uart_to_rtc_set_sec when others;
    
    with uart_to_rtc_set_enable select rtc_set_min <=
        n64_to_rtc_set_min when '0',
        uart_to_rtc_set_min when others;
    
    with uart_to_rtc_set_enable select rtc_set_hour <=
        n64_to_rtc_set_hour when '0',
        uart_to_rtc_set_hour when others;
    
    with uart_to_rtc_set_enable select rtc_set_date <=
        n64_to_rtc_set_date when '0',
        uart_to_rtc_set_date when others;
    
    with uart_to_rtc_set_enable select rtc_set_weekday <=
        n64_to_rtc_set_weekday when '0',
        uart_to_rtc_set_weekday when others;
    
    with uart_to_rtc_set_enable select rtc_set_month <=
        n64_to_rtc_set_month when '0',
        uart_to_rtc_set_month when others;
    
    with uart_to_rtc_set_enable select rtc_set_year <=
        n64_to_rtc_set_year when '0',
        uart_to_rtc_set_year when others;
    
    process (CLK_I)
        variable flash_addr_tmp : std_logic_vector(23 downto 0);
        variable mapping_index_tmp : integer range 0 to 31;
    begin
        if rising_edge(CLK_I) then
            if RST_I = '1' then
                cart_addr_latch <= (others => '0');
                cart_addr_cnt <= (others => '0');
                read_last <= '0';
                write_last <= '0';
                
                rom_state <= s_idle;
                flash_cmd_en_boot <= '0';
                flash_cmd_en_rom <= '0';
                rom_write_control <= '0';
                rom_buffer_we <= '0';
                rom_cs <= '0';
                sram_cs <= '0';
                ci_cs <= '0';
                addr_valid <= '0';
                ram_read_start <= '0';
                ram_write_start <= '0';
                sram_cyc <= '0';
                sram_stb <= '0';
                sram_we <= '0';
                sram_adr <= (others => '0');
                cart_control_reg <= (others => '0');
                cart_rom_offset <= (others => '0');
                cart_save_offset <= (others => '0');
                cart_backup <= (others => '0');
                N64_AD_IO <= (others => 'Z');
                
                uart_tx_state <= s_uart_tx_idle;
                uart_txfifo_wren <= '0';
                cart_uart_txd_valid <= '0';
                uart_tx_dma_active <= '0';
                uart_rxfifo_rden <= '0';
                uart_rx_dma_buf <= (others => '0');
                uart_rxfifo_read_state <= s_uart_rxfifo_read_idle;
                uart_rxfifo_overflow <= '0';
            else
                if n64_reset = '1' then
                    read_last <= '0';
                    write_last <= '0';
                    
                    rom_cs <= '0';
                    sram_cs <= '0';
                    ci_cs <= '0';
                    addr_valid <= '0';
                    ram_read_start <= '0';
                    ram_write_start <= '0';
                    sram_cyc <= '0';
                    sram_stb <= '0';
                    sram_we <= '0';
                    cart_control_reg <= (others => '0');
                    N64_AD_IO <= (others => 'Z');
                else
                    read_last <= read_ff2;
                    write_last <= write_ff2;
                    addr_valid <= '0';
                    
                    if addr_valid = '0' then
                        rom_cs <= '0';
                        sram_cs <= '0';
                        ci_cs <= '0';
                    end if;
                    
                    if alel_ff2 = '1' then
                        if aleh_ff2 = '1' then
                            cart_addr_latch(31 downto 16) <= ad_ff2;
                        else
                            cart_addr_latch(15 downto 0) <= ad_ff2(15 downto 1) & "0";
                        end if;
                    end if;
                    
                    if (aleh_ff2 = '0') and (alel_ff2 = '0') then
                        addr_valid <= '1';
                        
                        if addr_valid = '0' then
                            current_mapping <= cart_mapping_regs(to_integer(unsigned(cart_addr_latch(25 downto 21))));
                            cart_addr_cnt <= unsigned(cart_addr_latch(14 downto 1));
                            if (cart_addr_latch(31 downto 27) = CART_ROM_BASE_ADDR(31 downto 27)) then
                                rom_cs <= '1';
                            end if;
                            if (cart_addr_latch(31 downto 27) = CART_REGISTER_BASE_ADDR(31 downto 27)) then
                                ci_cs <= '1';
                            end if;
                            if (cart_addr_latch(31 downto 27) = CART_SRAM_BASE_ADDR(31 downto 27)) then
                                sram_cs <= '1';
                                if cart_control_reg(CART_CONTROL_SRAM_ENABLE) = '1' then
                                    case cart_addr_latch(26 downto 16) is
                                        when "00000000000" =>
                                            sram_adr(15 downto 14) <= "00";
                                            ram_read_start <= '1';
                                            
                                        when "00000000100" =>
                                            sram_adr(15 downto 14) <= "01";
                                            ram_read_start <= '1';
                                            
                                        when "00000001000" =>
                                            sram_adr(15 downto 14) <= "10";
                                            ram_read_start <= '1';
                                            
                                        when others => null;
                                    end case;
                                end if;
                            end if;
                            
                        elsif ((read_last = '1') and (read_ff2 = '0')) or ((write_last = '1') and (write_ff2 = '0')) then
                            if rom_cs = '1' then
                                cart_addr_cnt(7 downto 0) <= cart_addr_cnt(7 downto 0) + 1; 
                            elsif sram_cs = '1' or ci_cs = '1' then
                                cart_addr_cnt <= cart_addr_cnt + 1;
                            end if;
                        end if;
                    end if;
                    
                    N64_AD_IO <= (others => 'Z');
                    if (read_ff2 = '1') then
                        if ci_cs = '1' then
                            N64_AD_IO <= ci_out;
                        elsif sram_cs = '1' then
                            if cart_control_reg(CART_CONTROL_SRAM_ENABLE) = '1' then
                                N64_AD_IO <= sram_ad_out;
                            elsif cart_control_reg(CART_CONTROL_FLASHRAM_ENABLE) ='1' then
                                N64_AD_IO <= flashram_ad_out;
                            end if;
                        elsif rom_cs = '1' then
                            N64_AD_IO <= rom_buffer_q;
                        end if;
                    end if;
                end if;
                
                flash_cmd_en_boot <= '0';
                flash_cmd_en_rom <= '0';
                flash_read_continous <= '0';
                rom_buffer_we <= '0';
                uart_flash_cmd_ack <= '0';
                
                case rom_state is
                when s_idle =>
                    if rom_cs = '1' then
                        flash_addr_tmp := cart_addr_latch(25 downto 2);
                        
                        -- ROM Flash supports offset and mapping
                        -- (BOOT Flash is always directly mapped)
                        if cart_control_reg(CART_CONTROL_FLASH_SEL) = '1' then
                            if cart_control_reg(CART_CONTROL_MAPPING_ENABLE) = '1' then
                                -- map the high bits of the address 
                                flash_addr_tmp(23 downto 19) := current_mapping(4 downto 0);
                            else
                                flash_addr_tmp := std_logic_vector(unsigned(cart_addr_latch(25 downto 2)) + unsigned(std_logic_vector'(cart_rom_offset & "000000000000000000")));
                            end if;
                        end if;
                        flash_last_addr <= flash_addr_tmp;
                        
                        -- rollover to beginning of page not supported
                        flash_last_addr(6 downto 0) <= (others => '1');
                        flash_cmd_addr <= flash_addr_tmp;
                        rom_state <= s_cmd;
                    elsif (uart_flash_cmd_en_boot = '1') or (uart_flash_cmd_en_rom = '1') then
                        flash_cmd_addr <= uart_flash_cmd_addr;
                        flash_cmd <= uart_flash_cmd;
                        rom_state <= s_uart_cmd;
                    end if;
                    
                when s_cmd =>
                    flash_cmd <= FLASH_CMD_READ;
                    if cart_control_reg(CART_CONTROL_FLASH_SEL) = '0' then
                        flash_cmd_en_boot <= '1';
                    else
                        flash_cmd_en_rom <= '1';
                    end if;
                    if flash_cmd_rdy = '1' then
                        rom_state <= s_data;
                    end if;
                    
                when s_data =>
                    if rom_cs = '1' then
                        if (flash_cmd_addr(6 downto 0) /= "1111111")
                            and (flash_cmd_addr /= flash_last_addr)
                        then
                            flash_read_continous <= '1';
                        end if;
                        
                        if flash_data_valid = '1' then
                            if flash_cmd_addr = flash_last_addr then
                                rom_state <= s_done;
                            elsif flash_read_continous = '0' then
                                rom_state <= s_cmd;
                                flash_cmd_addr(6 downto 0) <= (others => '0');
                            else
                                flash_cmd_addr <= std_logic_vector(unsigned(flash_cmd_addr) + 1);
                            end if;
                            
                            rom_write_control <= '1';
                            rom_buffer_wraddr <= flash_cmd_addr(6 downto 0) & "0";
                            
                            rom_write_data <= flash_data;
                            -- rom_write_data <= flash_data(23 downto 16) & flash_data(31 downto 24) & flash_data(7 downto 0) & flash_data(15 downto 8);
                            
                            rom_buffer_we <= '1';
                        end if;
                    else
                        rom_state <= s_idle;
                    end if;
                
                when s_done =>
                    if rom_cs = '0' then
                        rom_state <= s_idle;
                    end if;
                    
                when s_uart_cmd =>
                    flash_cmd_en_boot <= uart_flash_cmd_en_boot;
                    flash_cmd_en_rom <= uart_flash_cmd_en_rom;
                    if flash_cmd_rdy = '1' then
                        uart_flash_cmd_ack <= '1';
                        rom_state <= s_uart_wait;
                    end if;
                    
                when s_uart_wait =>
                    if flash_cmd_rdy = '1' then
                        rom_state <= s_idle;
                    end if;
                    
                when others => null;
                end case;
                
                if rom_write_control = '1' then
                    rom_write_control <= '0';
                    rom_buffer_wraddr(0) <= '1';
                    rom_buffer_we <= '1';
                end if;

                -- N64 SRAM logic
                sram_cyc <= '0';
                sram_stb <= '0';
                sram_we <= '0';
                if sram_cs = '1' and cart_control_reg(CART_CONTROL_SRAM_ENABLE) = '1' then
                    if read_ff2 = '0' and read_last = '1' then
                        ram_read_start <= '1';
                    end if;
                    
                    if write_ff2 = '0' and write_last = '1' then
                        ram_write_start <= '1';
                    end if;
                    
                    if write_ff2 = '1' and ram_write_start = '0' then
                        sram_dat_to_ram <= ad_ff2;
                        sram_adr(13 downto 0) <= cart_addr(14 downto 1);
                    end if;
                end if;
                
                if ram_read_start = '1' then
                    sram_cyc <= '1';
                    sram_stb <= '1';
                    sram_adr(13 downto 0) <= cart_addr(14 downto 1);
                    if sram_ack = '1' then
                        sram_ad_out <= mem_dat_from_ram;
                        sram_cyc <= '0';
                        sram_stb <= '0';
                        ram_read_start <= '0';
                    end if;
                elsif ram_write_start = '1' then
                    sram_cyc <= '1';
                    sram_stb <= '1';
                    sram_we <= '1';
                    if sram_ack = '1' then
                        sram_cyc <= '0';
                        sram_stb <= '0';
                        sram_we <= '0';
                        ram_write_start <= '0';
                    end if;
                end if;
                
                uart_txfifo_wren <= '0';
                uart_rxfifo_rden <= '0';
                
                if (uart_rxfifo_wren = '1') and (uart_rxfifo_full = '1') then
                    uart_rxfifo_overflow <= '1';
                end if;
                
                -- CI (Cart Interface)
                if ci_cs = '1' then
                    if write_ff2 = '1' then
                        if cart_addr(1) = '0' then
                            ci_data(31 downto 16) <= ad_ff2;
                        else
                            ci_data(15 downto 0) <= ad_ff2;
                        end if;
                    end if;
                    if write_ff2 = '0' and write_last = '1' then
                        case cart_addr is
                        when CART_CONTROL_REG_W1 =>
                            cart_control_reg <= ci_data(cart_control_reg'range);
                            
                        when CART_ROMOFFSET_REG_W1 =>
                            cart_rom_offset <= ci_data(cart_rom_offset'range);
                            
                        when CART_SAVEOFFSET_REG_W1 =>
                            cart_save_offset <= ci_data(cart_save_offset'range);
                            
                        when CART_BACKUP_REG_W1 =>
                            cart_backup <= ci_data;
                            
                        when CART_UART_STATUS_REG_W1 =>
                            -- write '1' to reset the flag
                            if ci_data(CART_UART_STATUS_RXOF) = '1' then
                                uart_rxfifo_overflow <= '0';
                            end if;
                            
                        when CART_UART_DATA_REG_W1 =>
                            cart_uart_txd_reg <= ci_data(cart_uart_txd_reg'range);
                            uart_txfifo_wren <= '1';
                        
                        when others => null;
                        end case;
                        
                        -- writes to UART DMA address space (1 KiB) trigger a write to the TX FIFO
                        if cart_addr(31 downto 10) = CART_UART_DMA_ADDR(31 downto 10) and cart_addr(1) = '1' then
                            cart_uart_txd_dma_reg <= ci_data;
                            uart_tx_dma_count <= "11";
                            uart_tx_dma_active <= '1';
                        end if;
                        
                        -- writes to mapping address space (128 B)
                        if cart_addr(31 downto 7) = CART_MAPPING0_REG_ADDR(31 downto 7) and cart_addr(1) = '1' then
                            -- cart_addr(6 downto 2) is the index
                            -- 5 bits => 31 regs
                            mapping_index_tmp := to_integer(unsigned(cart_addr(6 downto 2)));
                            cart_mapping_regs(mapping_index_tmp) <= ci_data(current_mapping'range);
                        end if;
                    end if;
                    
                    ci_out <= (others => '0');
                    case cart_addr is
                        
                    when CART_CONTROL_REG_W1 =>
                        ci_out(cart_control_reg'range) <= cart_control_reg;
                        
                    when CART_VERSION_REG_ADDR =>
                        ci_out <= FPGA_VERSION(31 downto 16);
                        
                    when CART_VERSION_REG_W1 =>
                        ci_out <= FPGA_VERSION(15 downto 0);
                        
                    when CART_ROMOFFSET_REG_W1 =>
                        ci_out(cart_rom_offset'range) <= cart_rom_offset;
                        
                    when CART_SAVEOFFSET_REG_W1 =>
                        ci_out(cart_save_offset'range) <= cart_save_offset;
                        
                    when CART_BACKUP_REG_ADDR =>
                        ci_out <= cart_backup(31 downto 16);
                        
                    when CART_BACKUP_REG_W1 =>
                        ci_out <= cart_backup(15 downto 0);
                    
                    when CART_UART_STATUS_REG_W1 =>
                        ci_out(CART_UART_STATUS_TXNF) <= not uart_txfifo_full;
                        ci_out(CART_UART_STATUS_TXE) <= uart_txfifo_empty;
                        ci_out(CART_UART_STATUS_TXHE) <= uart_txfifo_almost_empty;
                        ci_out(CART_UART_STATUS_TXACT) <= uart_tx_active;
                        
                        ci_out(CART_UART_STATUS_RXNE) <= not uart_rxfifo_empty;
                        ci_out(CART_UART_STATUS_RXF) <= uart_rxfifo_full;
                        ci_out(CART_UART_STATUS_RXHF) <= uart_rxfifo_almost_full;
                        ci_out(CART_UART_STATUS_RXOF) <= uart_rxfifo_overflow;
                        
                    when CART_UART_TX_FREE_REG_W1 =>
                        ci_out(uart_txfifo_free_count'range) <= uart_txfifo_free_count;
                            
                    when CART_UART_RX_READY_REG_W1 =>
                        ci_out(uart_rxfifo_ready_count'range) <= uart_rxfifo_ready_count;
                            
                    when CART_UART_DATA_REG_W1 =>
                        -- trigger fifo read
                        if read_ff2 = '1' and read_last = '0' then
                            uart_rxfifo_rden <= '1';
                        end if;
                        ci_out(7 downto 0) <= uart_rxfifo_q;
                            
                    when others => null;
                    end case;
                    
                    if cart_addr(31 downto 10) = CART_UART_DMA_ADDR(31 downto 10) then
                        ci_out <= uart_rx_dma_buf;
                    end if;
                    
                end if;
                
                -- switch the rom back to BOOT on NMI
                if nmi_ff2 = '0' then
                    cart_control_reg(CART_CONTROL_FLASH_SEL) <= '0';
                end if;
                
                if cart_control_reg(CART_CONTROL_UART_ENABLE) = '0' then
                    uart_tx_state <= s_uart_tx_idle;
                    cart_uart_txd_valid <= '0';
                    uart_tx_dma_active <= '0';
                    uart_rxfifo_overflow <= '0';
                end if;
                
                uart_txfifo_rden <= '0';
                case uart_tx_state is
                when s_uart_tx_idle =>
                    if cart_control_reg(CART_CONTROL_UART_ENABLE) = '1' then
                        uart_tx_state <= s_uart_tx_wait;
                    end if;
                    
                when s_uart_tx_wait =>
                    cart_uart_txd_valid <= '0';
                    if uart_txfifo_empty = '0' then
                        uart_txfifo_rden <= '1';
                        uart_tx_state <= s_uart_tx_read;
                    end if;
                    
                when s_uart_tx_read =>
                    cart_uart_txd_valid <= '1';
                    uart_tx_state <= s_uart_tx_ack;
                
                when s_uart_tx_ack =>
                    if cart_uart_txd_ack = '1' then
                        cart_uart_txd_valid <= '0';
                        uart_tx_state <= s_uart_tx_wait;
                    end if;
                
                when others =>
                    uart_tx_state <= s_uart_tx_wait;
                end case;
                
                if uart_tx_dma_active = '1' then
                    cart_uart_txd_reg <= cart_uart_txd_dma_reg(31 downto 24);
                    uart_txfifo_wren <= '1';
                    cart_uart_txd_dma_reg <= cart_uart_txd_dma_reg(23 downto 0) & x"00";
                    uart_tx_dma_count <= uart_tx_dma_count - 1;
                    if uart_tx_dma_count = 0 then
                    	uart_tx_dma_active <= '0';
                    end if;
                end if;
                
                case uart_rxfifo_read_state is
                when s_uart_rxfifo_read_idle =>
                    if cart_addr(31 downto 10) = CART_UART_DMA_ADDR(31 downto 10) then
                        -- read to UART DMA address space (1 KiB) trigger a read from the RX FIFO
                        if read_ff2 = '1' and read_last = '0' then
                            uart_rxfifo_read_state <= s_uart_rxfifo_read_data0;
                            uart_rxfifo_rden <= '1';
                        end if;
                    end if;
                    
                when s_uart_rxfifo_read_data0 =>
                    uart_rxfifo_rden <= '1';
                    uart_rxfifo_read_state <= s_uart_rxfifo_read_data1;
                    
                when s_uart_rxfifo_read_data1=>
                    uart_rx_dma_buf(15 downto 8) <= uart_rxfifo_q;
                    uart_rxfifo_read_state <= s_uart_rxfifo_read_delay0;
                
                when s_uart_rxfifo_read_delay0 =>
                    uart_rx_dma_buf(7 downto 0) <= uart_rxfifo_q;
                    uart_rxfifo_read_state <= s_uart_rxfifo_read_idle;
                
                when others => null;
                end case;
            end if;
        end if;
    end process;

end architecture Behavioral;