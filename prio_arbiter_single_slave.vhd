library	ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prio_arbiter_single_slave is
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
end entity prio_arbiter_single_slave;

architecture Behavioral of prio_arbiter_single_slave is

    signal selected_master : integer range 0 to NUM_MASTERS - 1;
    signal transaction_active : std_logic;
    
begin

    process (transaction_active, selected_master, SLV_ACK_I)
    begin
        MSTR_ACK_O <= (others => '0');
        if transaction_active = '1' then
            MSTR_ACK_O(selected_master) <= SLV_ACK_I;
        end if;
    end process;

    process (CLK_I, RST_I)
    begin
        if RST_I = '1' then
            transaction_active <= '0';
            SLV_CYC_O <= '0';
            SLV_STB_O <= '0';
            SLV_WE_O <= '0';
            SLV_ADR_O <= (others => '0');
            SLV_DAT_O <= (others => '0');
        elsif rising_edge(CLK_I) then
            if transaction_active = '0' then
                for I in (NUM_MASTERS - 1) downto 0 loop
                    if MSTR_CYC_I(I) = '1' and MSTR_STB_I(I) = '1' then
                        selected_master <= I;
                        transaction_active <= '1';
                        SLV_CYC_O <= '1';
                        SLV_STB_O <= '1';
                        SLV_WE_O <= MSTR_WE_I(I);
                        SLV_ADR_O <= MSTR_ADR_I(((I + 1) * ADR_WIDTH - 1) downto (I * ADR_WIDTH));
                        SLV_DAT_O <= MSTR_DAT_I(((I + 1) * DATA_WIDTH - 1) downto (I * DATA_WIDTH));
                    end if;
                end loop;
            else
                if SLV_ACK_I = '1' then
                    transaction_active <= '0';
                    SLV_CYC_O <= '0';
                    SLV_STB_O <= '0';
                    SLV_WE_O <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture Behavioral;