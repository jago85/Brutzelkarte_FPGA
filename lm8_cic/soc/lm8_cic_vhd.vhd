library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
entity lm8_cic_vhd is
port(
clk_i   : in std_logic
; reset_n : in std_logic
; ioPIO_BOTH_IN : in std_logic_vector(2 downto 0)
; ioPIO_BOTH_OUT : out std_logic_vector(0 downto 0)
);
end lm8_cic_vhd;

architecture lm8_cic_vhd_a of lm8_cic_vhd is

component lm8_cic
   port(
      clk_i   : in std_logic
      ; reset_n : in std_logic
      ; ioPIO_BOTH_IN : in std_logic_vector(2 downto 0)
      ; ioPIO_BOTH_OUT : out std_logic_vector(0 downto 0)
      );
   end component;

begin

lm8_inst : lm8_cic
port map (
   clk_i  => clk_i
   ,reset_n  => reset_n
   ,ioPIO_BOTH_IN  => ioPIO_BOTH_IN
   ,ioPIO_BOTH_OUT  => ioPIO_BOTH_OUT
   );

end lm8_cic_vhd_a;

