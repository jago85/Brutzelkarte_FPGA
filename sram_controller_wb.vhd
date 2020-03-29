library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sram_controller_wb is
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
end entity sram_controller_wb;

architecture Behavioral of sram_controller_wb is

    type sram_controller_wb_state_t is (
        s_ready,
        s_read0,
        s_write0,
        s_write_end0,
        s_read_end -- for bus turnaround
    );

    signal state, next_state : sram_controller_wb_state_t;
    signal data_read_reg : std_logic_vector(15 downto 0);
    signal data_write_reg : std_logic_vector(15 downto 0);
    signal ack : std_logic;
    signal addr_reg : std_logic_vector(16 downto 0);
    
    signal ram_addr : std_logic_vector(16 downto 0);
    signal ram_data : std_logic_vector(15 downto 0);
    signal ram_data_reg : std_logic_vector(15 downto 0);
    signal ram_cs : std_logic;
    signal ram_we : std_logic;
    signal ram_oe : std_logic;
    signal ram_data_tris : std_logic;
    
    signal counter : unsigned(5 downto 0);
    signal capture_enable : std_logic;
    
begin
    
    DAT_O <= data_read_reg;
    RAM_DATA_IO <= ram_data_reg when ram_data_tris = '0' else (others => 'Z');
    ACK_O <= ack;
    
    reg_proc : process (CLK_I, RST_I)
    begin
        if RST_I = '1' then
            state <= s_ready;
            data_read_reg <= (others => '0');
            ram_data_tris <= '1';
            capture_enable <= '0';
            ack <= '0';
            
            RAM_CE_O <= '0';
            RAM_NWE_O <= '1';
            RAM_NOE_O <= '1';
            
        elsif rising_edge(CLK_I) then
            
            counter <= counter - 1;
            state <= next_state;
            ram_data_tris <= '1';
            capture_enable <= '0';
            ack <= '0';
            
            case state is
            when s_ready =>
                addr_reg <= ADR_I;
                data_write_reg <= DAT_I;
                counter <= to_unsigned(5, counter'length);
                
            when s_read0 =>
                if counter = 0 then
                    capture_enable <= '1';
                end if;
                
            when s_read_end =>
            
            when s_write0 =>
                ram_data_tris <= '0';
            
            when s_write_end0 =>
                ram_data_tris <= '0';
				ack <= '1';
                
            when others => null;
            end case;
            
            if capture_enable = '1' then
                data_read_reg <= RAM_DATA_IO;
				ack <= '1';
            end if;
            
            RAM_ADDR_O <= ram_addr;
            ram_data_reg <= ram_data;
            RAM_CE_O <= ram_cs;
            RAM_NOE_O <= ram_oe;
            RAM_NWE_O <= ram_we;
            
        end if;
    end process;
    
    comb_proc : process (state, CYC_I, STB_I, counter, WE_I, addr_reg, ADR_I, data_write_reg)
    begin
        ram_cs <= '0';
        ram_oe <= '1';
        ram_we <= '1';
        ram_addr <= (others => '0');
        ram_data <= (others => '0');
        
        case state is
        when s_ready =>
            next_state <= s_ready;
            if (CYC_I = '1') and (STB_I = '1') and (ack = '0') then
                if WE_I = '1' then
                    next_state <= s_write0;
                else
                    next_state <= s_read0;
                    ram_cs <= '1';
                end if;
                
                ram_addr <= ADR_I;
            end if;
            
        when s_read0 =>
            next_state <= s_read0;
            if counter = 0 then
                next_state <= s_read_end;
            end if;
            
            ram_addr <= addr_reg;
            ram_cs <= '1';
            ram_oe <= '0';
            
        when s_read_end =>
            -- one additional clock for bus turnaround
            -- needed if the next command is a write because the sram needs 20 ns to High-Z the data lines
            -- this could be done better by only adding a delay if there is an immidiate write after read
            next_state <= s_ready;
        
        when s_write0 =>
            next_state <= s_write0;
            if counter = 0 then
                next_state <= s_write_end0;
            end if;
            
            ram_addr <= addr_reg;
            ram_data <= data_write_reg;
            ram_cs <= '1';
            ram_we <= '0';
            
        when s_write_end0 =>
            next_state <= s_ready;
            ram_addr <= addr_reg;
            ram_data <= data_write_reg;
            ram_cs <= '1';
        
        when others => next_state <= s_ready;
        end case;
    end process;


end architecture Behavioral;