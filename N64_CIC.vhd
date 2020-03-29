library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity N64_CIC is
port ( 
    CLK_I            : in    STD_LOGIC;
    REGION_I         : in    STD_LOGIC;
    N64_CIC_DCLK_I   : in    STD_LOGIC;
    N64_CIC_D_IO     : inout STD_LOGIC;
    N64_CIC_RESET_I  : in    STD_LOGIC
);
end N64_CIC;

architecture Behavioral of N64_CIC is

    component lm8_cic
    port (
      clk_i   : in std_logic
      ; reset_n : in std_logic
      ; ioPIO_BOTH_IN : in std_logic_vector(2 downto 0)
      ; ioPIO_BOTH_OUT : out std_logic_vector(0 downto 0)
    );
    end component;
    
    signal cic_in : std_logic_vector(2 downto 0);
    signal cic_out : std_logic_vector(0 downto 0);

begin

    lm8_inst : lm8_cic
    port map (
       clk_i  => CLK_I
       ,reset_n  => N64_CIC_RESET_I
       ,ioPIO_BOTH_IN  => cic_in
       ,ioPIO_BOTH_OUT  => cic_out
    );
    cic_in <= REGION_I & N64_CIC_DCLK_I & N64_CIC_D_IO;
    
    process (cic_out, N64_CIC_RESET_I)
    begin
        if N64_CIC_RESET_I = '0' then
            N64_CIC_D_IO <= 'Z';
        else
            if cic_out(0) = '1' then
                N64_CIC_D_IO <= '0';
            else
                N64_CIC_D_IO <= 'Z';
            end if;
        end if;
    end process;  

end Behavioral;