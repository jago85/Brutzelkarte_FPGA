library IEEE;
use IEEE.std_logic_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity s25fl256s_x2 is
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
end s25fl256s_x2;

architecture Behavioral of s25fl256s_x2 is

    component BB
    port (
        I : in std_logic;
        T : in std_logic;
        O : out std_logic;
        B : inout std_logic
    );
    end component;
    
    constant CMD_NONE   : std_logic_vector(1 downto 0) := "00";
    constant CMD_READ   : std_logic_vector(1 downto 0) := "01";
    constant CMD_WRITE  : std_logic_vector(1 downto 0) := "10";
    constant CMD_ERASE  : std_logic_vector(1 downto 0) := "11";
    
    
    constant FLASH_CMD_READ_JEDEC_ID            : std_logic_vector(7 downto 0) := x"9F";
    constant FLASH_CMD_FASTREAD_QUADIO          : std_logic_vector(7 downto 0) := x"EC";
    constant FLASH_CMD_WREN                     : std_logic_vector(7 downto 0) := x"06";
    constant FLASH_CMD_ERASE                    : std_logic_vector(7 downto 0) := x"DC";
    constant FLASH_CMD_QUAD_PAGE_PROGRAM        : std_logic_vector(7 downto 0) := x"34";
    constant FLASH_CMD_READ_STATUS_REGISTER1    : std_logic_vector(7 downto 0) := x"05";
    constant FLASH_CMD_WRITE_STATUS_REGISTER1   : std_logic_vector(7 downto 0) := x"01";
    
    type state_t is (
        s_init,
        s_readid,
        s_readid_end,
        s_wren_init_cmd,
        s_wren_init_end,
        s_set_qe_cmd,
        s_set_qe_end,
        s_set_qe_wip_cmd,
        s_set_qe_wip_end,
        s_pause,
        
        s_pre_idle,
        s_idle,
        s_read_cmd,
        s_read_data,
        
        s_wren_cmd,
        s_wren_end,
        
        s_erase_cmd,
        
        s_write_cmd,
        s_write_data,
        s_write_end,
        
        s_read_wip_cmd,
        s_read_wip_data
        
    );
    
    signal spi_sck : std_logic;
    signal spi_dq_in : std_logic_vector(3 downto 0);
    signal spi_dq_out : std_logic_vector(3 downto 0);
    signal spi_dq_tris : std_logic_vector(3 downto 0);
    signal read_data : std_logic_vector(31 downto 0);
    signal state : state_t;
    
    signal cmd_addr : std_logic_vector(23 downto 0);
    signal chip_sel : std_logic_vector(1 downto 0);
    signal cmd : std_logic_vector(1 downto 0);
    signal shift_counter : std_logic_vector(40 downto 0);
    signal spi_shift_out : std_logic_vector(7 downto 0);
    signal spi_shift_in : std_logic_vector(7 downto 0);
    signal spi_clock_en : std_logic;
    signal spi_quad_en : std_logic;
    signal spi_output_tris : std_logic;
    signal fifo_empty : std_logic;
    
    signal manufacturer_id1 : std_logic_vector(7 downto 0);
    signal mem_type_id1 : std_logic_vector(7 downto 0);
    signal capacity_id1 : std_logic_vector(7 downto 0);
    signal manufacturer_id2 : std_logic_vector(7 downto 0);
    signal mem_type_id2 : std_logic_vector(7 downto 0);
    signal capacity_id2 : std_logic_vector(7 downto 0);
    
    
    attribute syn_state_machine : boolean;
    attribute syn_state_machine of Behavioral : architecture is true;
    attribute syn_encoding : string;
    attribute syn_encoding of state: signal is "onehot";
begin
    
    SCK_O <= spi_sck;
    
    DQ_BUFFER : for index in 0 to 3 generate
        DQ_BB : BB
        port map (
            I => spi_dq_out(index),
            T => spi_dq_tris(index),
            O => spi_dq_in(index),
            B => DQ_IO(index)
        );
    end generate DQ_BUFFER;
    
    process (spi_output_tris, spi_quad_en, spi_shift_out)
    begin
        
        if spi_quad_en = '0' then
            spi_dq_out <= "000" & spi_shift_out(spi_shift_out'high);
            spi_dq_tris <= "1110";
        else
            spi_dq_out <= spi_shift_out(spi_shift_out'high downto spi_shift_out'high - 3);
            if spi_output_tris = '0' then
                spi_dq_tris <= "0000";
            else
                spi_dq_tris <= "1111";
            end if;
        end if;
        
    end process;
    
    DATA_READ_O <= read_data;
    
    CMD_RDY_O <= '1' when state = s_idle else '0';
    
    chip_sel <= not cmd_addr(23) & cmd_addr(23);
    
    process (CLK_I, RESET_I)
    begin
        if RESET_I = '1' then
            spi_sck <= '0';
            CSN_O <= "11";
            state <= s_init;
            spi_shift_out <= (others => '0');
            spi_shift_in <= (others => '0');
            spi_clock_en <= '0';
            spi_quad_en <= '0';
            spi_output_tris <= '0';
            shift_counter <= (others => '0');
            read_data <= (others => '0');
            DATA_READ_VALID_O <= '0';
            WRITE_FIFO_RDEN_O <= '0';
        elsif rising_edge(CLK_I) then
            
            DATA_READ_VALID_O <= '0';
            WRITE_FIFO_RDEN_O <= '0';
            
            if spi_clock_en = '1' then
                
                spi_sck <= not spi_sck;
                
                if spi_sck = '1' then
                    if spi_quad_en = '1' then
                        spi_shift_out <= spi_shift_out(spi_shift_out'high - 4 downto spi_shift_out'low) & "0000";
                        spi_shift_in <= spi_shift_in(spi_shift_in'high - 4 downto spi_shift_in'low) & spi_dq_in;
                    else
                        spi_shift_out <= spi_shift_out(spi_shift_out'high - 1 downto spi_shift_out'low) & '0';
                        spi_shift_in <= spi_shift_in(spi_shift_in'high - 1 downto spi_shift_in'low) & spi_dq_in(1);
                    end if;
                    shift_counter <= shift_counter(shift_counter'high - 1 downto shift_counter'low) & '0';
                end if;
                
            else
                spi_sck <= '0';
            end if;
            
            case state is
            when s_init =>
                -- state <= s_idle;
                state <= s_readid;
                spi_shift_out <= FLASH_CMD_READ_JEDEC_ID;
                spi_clock_en <= '1';
                CSN_O <= "10";
                shift_counter <= "00000000000000000000000000000000000000001";
                cmd_addr <= (others => '0');
                
            when s_readid =>
                if spi_sck = '0' then
                    if shift_counter(16) = '1' then
                        if cmd_addr(23) = '0' then
                            manufacturer_id1 <= spi_shift_in;
                        else
                            manufacturer_id2 <= spi_shift_in;
                        end if;
                    end if;
                    
                    if shift_counter(24) = '1' then
                        if cmd_addr(23) = '0' then
                            mem_type_id1 <= spi_shift_in;
                        else
                            mem_type_id2 <= spi_shift_in;
                        end if;
                    end if;
                    
                    if shift_counter(40) = '1' then
                        if cmd_addr(23) = '0' then
                            capacity_id1 <= spi_shift_in;
                        else
                            capacity_id2 <= spi_shift_in;
                        end if;
                        CSN_O <= "11";
                        spi_clock_en <= '0';
                        spi_sck <= '0';
                        state <= s_readid_end;
                        shift_counter <= "00100000000000000000000000000000000000000";
                    end if;
                end if;
                
            when s_readid_end =>
                spi_shift_out <= FLASH_CMD_WREN;
                spi_clock_en <= '1';
                CSN_O <= chip_sel;
                shift_counter <= "00000000000000000000000000000000000000001";
                state <= s_wren_init_cmd;
                
            when s_wren_init_cmd =>
                if spi_sck = '0' then
                    if shift_counter(8) = '1' then
                        CSN_O <= "11";
                        spi_clock_en <= '0';
                        spi_sck <= '0';
                        state <= s_wren_init_end;
                        shift_counter <= "00000100000000000000000000000000000000000";
                    end if;
                end if;
                
            when s_wren_init_end =>
                shift_counter <= shift_counter(shift_counter'high - 1 downto shift_counter'low) & '0';
                if shift_counter(40) = '1' then
                    spi_shift_out <= FLASH_CMD_WRITE_STATUS_REGISTER1;
                    spi_clock_en <= '1';
                    CSN_O <= chip_sel;
                    shift_counter <= "00000000000000000000000000000000000000001";
                    state <= s_set_qe_cmd;
                end if;
                
            when s_set_qe_cmd =>
                if spi_sck = '0' then
                    if shift_counter(24) = '1' then
                        CSN_O <= "11";
                        spi_clock_en <= '0';
                        spi_sck <= '0';
                        state <= s_set_qe_end;
                    end if;
                else
                    if shift_counter(15) = '1' then
                        spi_shift_out <= x"02";
                    end if;
                end if;
                
            when s_set_qe_end =>
                state <= s_set_qe_wip_cmd;
                spi_shift_out <= FLASH_CMD_READ_STATUS_REGISTER1;
                spi_clock_en <= '1';
                CSN_O <= chip_sel;
                shift_counter <= "00000000000000000000000000000000000000001";
                    
            when s_set_qe_wip_cmd =>
                if spi_sck = '1' then
                    if shift_counter(7) = '1' then
                        shift_counter <= "00000000000000000000000000000000000000001";
                        state <= s_set_qe_wip_end;                       
                    end if;
                end if;
                
            when s_set_qe_wip_end =>
                if spi_sck = '0' then
                    if shift_counter(8) = '1' then
                        if spi_shift_in(0) = '1' then
                            shift_counter <= "00000000000000000000000000000000000000001";
                        else
                            spi_sck <= '0';
                            spi_clock_en <= '0';
                            spi_sck <= '0';
                            CSN_O <= "11";
                            
                            -- was this the first chip?
                            if cmd_addr(23) = '0' then
                                -- repeat the procedure for the second chip
                                cmd_addr(23) <= '1';
                                shift_counter <= "00001000000000000000000000000000000000000";
                                state <= s_pause;
                            else
                                -- second chip done
                                state <= s_pre_idle;
                                shift_counter <= "00000100000000000000000000000000000000000";
                            end if;
                        end if;
                    end if;
                end if;
                
            when s_pause =>
                shift_counter <= shift_counter(shift_counter'high - 1 downto shift_counter'low) & '0';
                if shift_counter(40) = '1' then
                    spi_shift_out <= FLASH_CMD_READ_JEDEC_ID;
                    spi_clock_en <= '1';
                    CSN_O <= chip_sel;
                    shift_counter <= "00000000000000000000000000000000000000001";
                    state <= s_readid;
                end if;
                
            when s_pre_idle =>
                -- this state is used to garantee the device deselect time
                shift_counter <= shift_counter(shift_counter'high - 1 downto shift_counter'low) & '0';
                if shift_counter(40) = '1' then
                    state <= s_idle;
                end if;
            
            when s_idle =>
                spi_output_tris <= '0';
                spi_quad_en <= '0';
                if CMD_EN_I = '1' then
                    spi_clock_en <= '1';
                    if CMD_ADDR_I(23) = '0' then
                        CSN_O <= "10";
                    else
                        CSN_O <= "01";
                    end if;
                    shift_counter <= "00000000000000000000000000000000000000001";
                    
                    cmd <= CMD_I;
                    cmd_addr <= CMD_ADDR_I;
                    
                    case CMD_I is
                    when CMD_READ =>
                        spi_shift_out <= FLASH_CMD_FASTREAD_QUADIO;
                        state <= s_read_cmd;
                        
                    when CMD_ERASE =>
                        spi_shift_out <= FLASH_CMD_WREN;
                        state <= s_wren_cmd;
                        
                    when CMD_WRITE =>
                        spi_shift_out <= FLASH_CMD_WREN;
                        state <= s_wren_cmd;
                        
                    when others =>
                        spi_clock_en <= '0';
                        CSN_O <= "11";
                    end case;
                end if;
                
            when s_read_cmd =>
                if spi_sck = '1' then
                    if shift_counter(7) = '1' then
                        spi_quad_en <= '1';
                        spi_shift_out <= "0000000" & cmd_addr(22);
                    end if;
                    if shift_counter(9) = '1' then
                        spi_shift_out <= cmd_addr(21 downto 14);
                    end if;
                    if shift_counter(11) = '1' then
                        spi_shift_out <= cmd_addr(13 downto 6);
                    end if;
                    if shift_counter(13) = '1' then
                        spi_shift_out <= cmd_addr(5 downto 0) & "00";
                    end if;
                    if shift_counter(15) = '1' then
                        spi_shift_out <= x"FF";
                    end if;
                    if shift_counter(17) = '1' then
                        spi_output_tris <= '1';
                    end if;
                    if shift_counter(22) = '1' then
                        state <= s_read_data;
                        shift_counter <= "00000000000000000000000000000000000000001";
                    end if;
                end if;
                
            when s_read_data =>
                if spi_sck = '0' then
                    if shift_counter(1) = '1' then
                        read_data(7 downto 0) <= spi_shift_in;
                    end if;
                    if shift_counter(3) = '1' then
                        read_data(15 downto 8) <= spi_shift_in;
                    end if;
                    if shift_counter(5) = '1' then
                        read_data(23 downto 16) <= spi_shift_in;
                    end if;
                    if shift_counter(7) = '1' then
                        read_data(31 downto 24) <= spi_shift_in;
                        
                        DATA_READ_VALID_O <= '1';
                        if READ_CONTINUOUS_I = '0' then
                            spi_clock_en <= '0';
                            spi_sck <= '0';
                            CSN_O <= "11";
                            shift_counter <= "10000000000000000000000000000000000000000";
                            state <= s_pre_idle;
                        end if;
                    end if;
                else
                    if shift_counter(7) = '1' then
                        -- we will only get here if READ_CONTINUOUS_I was '1' in the last cycle
                        shift_counter <= "00000000000000000000000000000000000000001";
                    end if;
                end if;
                
            when s_wren_cmd =>
                if spi_sck = '0' then
                    if shift_counter(8) = '1' then
                        CSN_O <= "11";
                        spi_clock_en <= '0';
                        spi_sck <= '0';
                        state <= s_wren_end;
                    end if;
                end if;
                
            when s_wren_end =>
                spi_clock_en <= '1';
                CSN_O <= chip_sel;
                shift_counter <= "00000000000000000000000000000000000000001";
                if cmd = CMD_ERASE then
                    spi_shift_out <= FLASH_CMD_ERASE;
                    state <= s_erase_cmd;
                else
                    spi_shift_out <= FLASH_CMD_QUAD_PAGE_PROGRAM;
                    state <= s_write_cmd;
                end if;
                
            when s_erase_cmd =>
                if spi_sck = '0' then
                    if shift_counter(40) = '1' then
                        CSN_O <= "11";
                        spi_clock_en <= '0';
                        spi_sck <= '0';
                        state <= s_write_end;
                        shift_counter <= "00000100000000000000000000000000000000000";
                    end if;
                else
                    if shift_counter(7) = '1' then
                        spi_shift_out <= "0000000" & cmd_addr(22);
                    end if;
                    if shift_counter(15) = '1' then
                        spi_shift_out <= cmd_addr(21 downto 14);
                    end if;
                    if shift_counter(23) = '1' then
                        spi_shift_out <= cmd_addr(13 downto 6);
                    end if;
                    if shift_counter(31) = '1' then
                        spi_shift_out <= cmd_addr(5 downto 0) & "00";
                    end if;
                end if;
                
            when s_write_cmd =>
                if spi_sck = '1' then
                    if shift_counter(7) = '1' then
                        spi_shift_out <= "0000000" & cmd_addr(22);
                    end if;
                    if shift_counter(15) = '1' then
                        spi_shift_out <= cmd_addr(21 downto 14);
                    end if;
                    if shift_counter(23) = '1' then
                        spi_shift_out <= cmd_addr(13 downto 6);
                    end if;
                    if shift_counter(31) = '1' then
                        spi_shift_out <= cmd_addr(5 downto 0) & "00";
                        
                        -- make the first data available
                        WRITE_FIFO_RDEN_O <= '1';
                    end if;
                    if shift_counter(39) = '1' then
                        state <= s_write_data;
                        spi_quad_en <= '1';
                        spi_shift_out <= WRITE_FIFO_DATA_I;
                        
                        -- make the next data available
                        WRITE_FIFO_RDEN_O <= '1';
                        fifo_empty <= WRITE_FIFO_EMPTY_I;
                        shift_counter <= "00000000000000000000000000000000000000001";
                    end if;
                end if;
                
            when s_write_data =>
                if spi_sck = '1' then
                    if shift_counter(1) = '1' then
                        if fifo_empty = '0' then
                            spi_shift_out <= WRITE_FIFO_DATA_I;
                            
                            -- make the next data available
                            WRITE_FIFO_RDEN_O <= '1';                                
                            fifo_empty <= WRITE_FIFO_EMPTY_I;
                            shift_counter <= "00000000000000000000000000000000000000001";
                        else
                            CSN_O <= "11";
                            spi_clock_en <= '0';
                            spi_quad_en <= '0';
                            state <= s_write_end;
                            shift_counter <= "00000100000000000000000000000000000000000";
                        end if;
                    end if;
                end if;
                
            when s_write_end =>
                shift_counter <= shift_counter(shift_counter'high - 1 downto shift_counter'low) & '0';
                if shift_counter(40) = '1' then
                    state <= s_read_wip_cmd;
                    spi_shift_out <= FLASH_CMD_READ_STATUS_REGISTER1;
                    spi_clock_en <= '1';
                    CSN_O <= chip_sel;
                    shift_counter <= "00000000000000000000000000000000000000001";
                end if;
                
            when s_read_wip_cmd =>
                if spi_sck = '1' then
                    if shift_counter(7) = '1' then
                        shift_counter <= "00000000000000000000000000000000000000001";
                        state <= s_read_wip_data;                       
                    end if;
                end if;
            
            when s_read_wip_data =>
                if spi_sck = '0' then
                    if shift_counter(8) = '1' then
                        if spi_shift_in(0) = '1' then
                            shift_counter <= "00000000000000000000000000000000000000001";
                        else
                            spi_sck <= '0';
                            spi_clock_en <= '0';
                            spi_sck <= '0';
                            CSN_O <= "11";
                            state <= s_idle;
                        end if;
                    end if;
                end if;
                
            when others => state <= s_init;
            end case;
        end if;
    end process;

end Behavioral;