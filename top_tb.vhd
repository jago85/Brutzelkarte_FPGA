--********************************************************************************************************************--
--! @file
--! @brief File Description
--! Copyright&copy - YOUR COMPANY NAME
--********************************************************************************************************************--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Local libraries
library work;

library machxo2;
use machxo2.components.all;

--! Entity/Package Description
entity tb_top is
end entity tb_top;

architecture tb of tb_top is

-- Signal declarations
signal   ALEH_I       : std_logic;
signal   ALEL_I       : std_logic;
signal   READn_I      : std_logic;
signal   WRITEn_I     : std_logic;
signal   AD_IO        : std_logic_vector(15 downto 0);
signal   CIC_CLK_I    : std_logic;
signal   CIC_DCLK_I   : std_logic;
signal   CIC_D_IO     : std_logic;
signal   S_DAT_IO     : std_logic;
signal   COLD_RESET_I : std_logic;
signal   CSN_O        : std_logic;
signal   SCK_O        : std_logic;
signal   DQ_IO        : std_logic_vector (3 downto 0);
signal   LED_O        : std_logic_vector(7 downto 0);

--! Component declaration for top
component top
port (
    
    ALEH_I : in std_logic;
    ALEL_I : in std_logic;
    READn_I : in std_logic;
    WRITEn_I : in std_logic;
    
    AD_IO : inout std_logic_vector(15 downto 0);
    
    CIC_CLK_I : in std_logic;
    CIC_DCLK_I : in std_logic;
    CIC_D_IO : inout std_logic;
	S_DAT_IO : inout std_logic;
    
    COLD_RESET_I : in std_logic;
    
    
    CSN_O               : out std_logic;
    SCK_O               : out std_logic;
    DQ_IO               : inout std_logic_vector (3 downto 0);
            
    LED_O : out std_logic_vector(7 downto 0)
);
end component;			   

begin

   --! Port map declaration for top
   uut : top
      port map (
                ALEH_I       => ALEH_I,
                ALEL_I       => ALEL_I,
                READn_I      => READn_I,
                WRITEn_I     => WRITEn_I,
                AD_IO        => AD_IO,
                CIC_CLK_I    => CIC_CLK_I,
                CIC_DCLK_I   => CIC_DCLK_I,
                CIC_D_IO     => CIC_D_IO,
                S_DAT_IO     => S_DAT_IO,
                COLD_RESET_I => COLD_RESET_I,
                CSN_O        => CSN_O,
                SCK_O        => SCK_O,
                DQ_IO        => DQ_IO,
                LED_O        => LED_O
   );
    
    process
    begin
        COLD_RESET_I <= '0';
        ALEH_I <= '1';
        ALEL_I <= '0';
        READn_I <= '1';
        WRITEn_I <= '1';
        AD_IO <= (others => 'Z');
        wait for 10 us;
        
        COLD_RESET_I <= '1';
        wait for 10 us;
        
        ALEL_I <= '1';
        AD_IO <= x"1000";
        wait for 100 ns;
        ALEH_I <= '0';
        AD_IO <= x"0000";
        wait for 100 ns;
        ALEL_I <= '0';
        wait for 100 ns;
        AD_IO <= (others => 'Z');
        wait for 900 ns;
        
        for i in 0 to 255 loop
            READn_I <= '0';
            wait for 300 ns;
            READn_I <= '1';
            wait for 60 ns;
        end loop;
        
        ALEH_I <= '1';
        ALEL_I <= '1';
        AD_IO <= x"1000";
        wait for 100 ns;
        ALEH_I <= '0';
        AD_IO <= x"01F8";
        wait for 100 ns;
        ALEL_I <= '0';
        wait for 100 ns;
        AD_IO <= (others => 'Z');
        wait for 900 ns;
        
        for i in 0 to 255 loop
            READn_I <= '0';
            wait for 300 ns;
            READn_I <= '1';
            wait for 60 ns;
        end loop;
        
        ALEH_I <= '1';
        ALEL_I <= '1';
        AD_IO <= x"1000";
        wait for 100 ns;
        ALEH_I <= '0';
        AD_IO <= x"01F8";
        wait for 100 ns;
        ALEL_I <= '0';
        wait for 100 ns;
        AD_IO <= (others => 'Z');
        wait for 900 ns;
        
        for i in 0 to 0 loop
            READn_I <= '0';
            wait for 300 ns;
            READn_I <= '1';
            wait for 60 ns;
        end loop;
        
        ALEH_I <= '1';
        
        ALEL_I <= '1';
        AD_IO <= x"1000";
        wait for 100 ns;
        ALEH_I <= '0';
        AD_IO <= x"0300";
        wait for 100 ns;
        ALEL_I <= '0';
        wait for 100 ns;
        AD_IO <= (others => 'Z');
        wait for 900 ns;
        
        for i in 0 to 255 loop
            READn_I <= '0';
            wait for 300 ns;
            READn_I <= '1';
            wait for 60 ns;
        end loop;
        
        ALEH_I <= '1';
        
        wait;
    end process;

end architecture tb;