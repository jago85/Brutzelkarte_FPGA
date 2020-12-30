library	ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lattice;
use lattice.all;

entity top is
port (
    
    N64_ALEH_I          : in std_logic;
    N64_ALEL_I          : in std_logic;
    N64_READn_I         : in std_logic;
    N64_WRITEn_I        : in std_logic;
    
    N64_AD_IO           : inout std_logic_vector(15 downto 0);
    
    N64_SI_CLK_I        : in std_logic;
    N64_CIC_DCLK_I      : in std_logic;
    N64_CIC_D_IO        : inout std_logic;
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
    
    -- Jumper
    JP1_I               : in std_logic;
    
    -- Testpoints
    -- TP1_O               : out std_logic;
    TP2_O               : out std_logic;
    TP3_O               : out std_logic;
    TP4_O               : out std_logic;
    
    -- LEDs
    LED_O               : out std_logic_vector(3 downto 0)
);
end entity top;

architecture Behavioral of top is

    COMPONENT OSCH
    -- synthesis translate_off
    GENERIC  (NOM_FREQ: string :=  "2.56");
    -- synthesis translate_on
    PORT (STDBY   : IN  std_logic;
          OSC     : OUT std_logic;
          SEDSTDBY: OUT std_logic);
    END COMPONENT;
    
    attribute NOM_FREQ : string;
    attribute NOM_FREQ of OSCinst0 : label is "133.0";
    
    component pll0
        port (CLKI: in  std_logic; CLKOP: out  std_logic; 
            CLKOS: out  std_logic; LOCK: out  std_logic);
    end component;
    
    component brutzelkarte
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
    end component;
    
	
    signal clk_int : std_logic;
    signal clk : std_logic;
    signal clk_cic : std_logic;
    signal pll_locked : std_logic;
    signal reset : std_logic;
    
begin
    
    OSCInst0: OSCH
    -- synthesis translate_off
    GENERIC MAP (NOM_FREQ => "133.0")
    -- synthesis translate_on
    PORT MAP (STDBY => '0',
              OSC   => clk_int,
              SEDSTDBY => open
    );
    
    pll0_inst : pll0
    port map (
        CLKI  => clk_int,
        CLKOP => clk,
        CLKOS => clk_cic,
        LOCK  => pll_locked
    );
    
    reset <= not pll_locked;
    
    brutzelkarte_inst : brutzelkarte
    port map (
        CLK_I               => clk,
        RST_I               => reset,

        N64_ALEH_I          => N64_ALEH_I,
        N64_ALEL_I          => N64_ALEL_I,
        N64_READn_I         => N64_READn_I,
        N64_WRITEn_I        => N64_WRITEn_I,

        N64_AD_IO           => N64_AD_IO,

        CIC_FAST_CLOCK_I    => clk_cic,
        CIC_REGION_I        => JP1_I,
        N64_CIC_DCLK_I      => N64_CIC_DCLK_I,
        N64_CIC_D_IO        => N64_CIC_D_IO,

        N64_SI_CLK_I        => N64_SI_CLK_I,
        N64_S_DAT_IO        => N64_S_DAT_IO,

        N64_COLD_RESET_I    => N64_COLD_RESET_I,
        N64_NMI_I           => N64_NMI_I,

        -- QSPI
        BOOT_CSN_O          => BOOT_CSN_O,
        BOOT_SCK_O          => BOOT_SCK_O,
        BOOT_DQ_IO          => BOOT_DQ_IO,

        ROM_CSN_O           => ROM_CSN_O,
        ROM_SCK_O           => ROM_SCK_O,
        ROM_DQ_IO           => ROM_DQ_IO,

        -- SRAM
        RAM_ADDR_O          => RAM_ADDR_O,
        RAM_DATA_IO         => RAM_DATA_IO,
        RAM_CE_O            => RAM_CE_O,
        RAM_NWE_O           => RAM_NWE_O,
        RAM_NOE_O           => RAM_NOE_O,

        -- USB-UART
        USB_DETECT_I        => USB_DETECT_I,
        UART_RTS_I          => UART_RTS_I,
        UART_RX_I           => UART_RX_I,
        UART_TX_O           => UART_TX_O,

        -- RTC (I2C)
        RTC_SDA_IO          => RTC_SDA_IO,
        RTC_SCL_IO          => RTC_SCL_IO,


        -- Testpoints
        TP1_O               => open,
        TP2_O               => TP2_O,
        TP3_O               => TP3_O,
        TP4_O               => TP4_O,

        -- LEDs
        LED_O               => LED_O
    );

end architecture Behavioral;