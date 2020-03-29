library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity N64_FlashRam is
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
       USE_FLASH_O      : out std_logic;
       
       MEM_CYC_O        : out std_logic;
       MEM_STB_O        : out std_logic;
       MEM_WE_O         : out std_logic;
       MEM_ACK_I        : in  std_logic;
       MEM_ADDR_O       : out std_logic_vector(15 downto 0);
       MEM_DAT_O        : out std_logic_vector(15 downto 0);
       MEM_DAT_I        : in  std_logic_vector(15 downto 0)
);
end N64_FlashRam;

architecture Behavioral of N64_FlashRam is

    component flash_write_buffer
        port (DataInA: in  std_logic_vector(15 downto 0); 
            DataInB: in  std_logic_vector(15 downto 0); 
            AddressA: in  std_logic_vector(5 downto 0); 
            AddressB: in  std_logic_vector(5 downto 0); 
            ClockA: in  std_logic; ClockB: in  std_logic; 
            ClockEnA: in  std_logic; ClockEnB: in  std_logic; 
            WrA: in  std_logic; WrB: in  std_logic; ResetA: in  std_logic; 
            ResetB: in  std_logic; QA: out  std_logic_vector(15 downto 0); 
            QB: out  std_logic_vector(15 downto 0));
    end component;

    -- #define FRAM_EXECUTE_CMD		    0xD2000000
    -- #define FRAM_STATUS_MODE_CMD	    0xE1000000
    -- #define FRAM_ERASE_OFFSET_CMD	0x4B000000
    -- #define FRAM_WRITE_OFFSET_CMD	0xA5000000
    -- #define FRAM_ERASE_MODE_CMD		0x78000000
    -- #define FRAM_WRITE_MODE_CMD		0xB4000000
    -- #define FRAM_READ_MODE_CMD		0xF0000000
    constant CMD_EXECUTE        : std_logic_vector(7 downto 0) := x"D2";
    constant CMD_STATUS_MODE    : std_logic_vector(7 downto 0) := x"E1";
    constant CMD_ERASE_OFFSET   : std_logic_vector(7 downto 0) := x"4B";
    constant CMD_ERASE_CHIP     : std_logic_vector(7 downto 0) := x"3C";
    constant CMD_WRITE_OFFSET   : std_logic_vector(7 downto 0) := x"A5";
    constant CMD_ERASE_MODE     : std_logic_vector(7 downto 0) := x"78";
    constant CMD_WRITE_MODE     : std_logic_vector(7 downto 0) := x"B4";
    constant CMD_READ_MODE      : std_logic_vector(7 downto 0) := x"F0";

    constant STATUS_ERASING : std_logic_vector(15 downto 0) := x"0082";
    constant STATUS_ERASE_END : std_logic_vector(15 downto 0) := x"0008";
    constant STATUS_WRITING : std_logic_vector(15 downto 0) := x"0081";
    constant STATUS_WRITE_END : std_logic_vector(15 downto 0) := x"0004";
    constant STATUS_READ_END : std_logic_vector(15 downto 0) := x"0080";

    constant FLASH_ID : std_logic_vector(63 downto 0) := x"001D00C280011111"; --MXL1101

    signal flash_used : std_logic := '0';

    signal cmd_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal cmd_stb : std_logic;
    signal status : std_logic_vector(63 downto 0) := (others => '0');
    signal next_status : std_logic_vector(63 downto 0) := (others => '0');
    signal erase_chip : std_logic := '0';
    signal write_buf_dataa : std_logic_vector(15 downto 0);
    signal write_buf_datab : std_logic_vector(15 downto 0);
    signal write_buf_wea : std_logic;
    signal write_buf_web : std_logic;
    signal write_buf_addrb : std_logic_vector(5 downto 0);
    signal read_data : std_logic_vector(15 downto 0);
    
    signal mem_cyc : std_logic;
    signal counter : unsigned(15 downto 0) := (others => '0');
    signal read_data_valid : std_logic_vector(2 downto 0);
    signal is_read_addr : std_logic;
    signal write_offset : std_logic_vector(9 downto 0) := (others => '0');
    signal write_done : std_logic;
    signal erase_done : std_logic;

    type flash_state_t is (
        s_idle,
        s_status,
        s_write,
        s_writing_start,
        s_writing,
        s_erase,
        s_erasing_start,
        s_erasing,
        s_reading
    );
    signal flash_state : flash_state_t := s_idle;

begin

    write_buf_mem : flash_write_buffer
    port map (
        DataInA(15 downto 0) => N64_AD_I,
        DataInB(15 downto 0) => x"ffff",
        AddressA(5 downto 0) => N64_ADDR_I(6 downto 1),
        AddressB(5 downto 0) => write_buf_addrb,
        ClockA               => CLK_I,
        ClockB               => CLK_I,
        ClockEnA             => '1',
        ClockEnB             => '1',
        WrA                  => write_buf_wea,
        WrB                  => write_buf_web,
        ResetA               => RST_I,
        ResetB               => RST_I,
        QA(15 downto 0)      => write_buf_dataa,
        QB(15 downto 0)      => write_buf_datab
    );

    write_buf_wea <= '1' when (flash_state = s_write)
                               and (N64_ADDR_LATCH_I(31 downto 16) = x"0800")
                               and (N64_WR_I = '1')
                         else '0';

    USE_FLASH_O <= flash_used;

    FLASH_USED_PROC : process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if (RST_I = '1') then
                flash_used <= '0';
            else
                if ((N64_ADDR_VALID_I = '1') and (N64_ADDR_I = x"08010000")) then
                    flash_used <= '1';
                end if;
            end if;
        end if;
    end process FLASH_USED_PROC;

    cmd_stb <= '1' when (N64_ADDR_I = x"08010002") and (N64_ADDR_LATCH_I(31 downto 16) = x"0801") and (N64_WR_I = '0') and (N64_WR_LAST_I = '1') else '0';

    COMMAND_REG_PROC : process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if (RST_I = '1') then
                cmd_reg <= (others => '0');
            else
                if ((N64_ADDR_VALID_I = '1') and (N64_WR_I = '1') and (N64_ADDR_LATCH_I(31 downto 16) = x"0801")) then
                    if (N64_ADDR_I(1) = '0') then
                        cmd_reg(31 downto 16) <= N64_AD_I;
                    else
                        cmd_reg(15 downto 0) <= N64_AD_I;
                    end if;
                end if;
            end if;
        end if;
    end process COMMAND_REG_PROC;

    STATE_LOGIC_PROC : process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if (RST_I = '1') then
                flash_state <= s_idle;
            else
                case flash_state is
                when s_idle =>
                    if (cmd_stb = '1') then
                        case cmd_reg(31 downto 24) is
                        when CMD_EXECUTE => flash_state <= s_idle;
                        when CMD_STATUS_MODE => flash_state <= s_status;
                        when CMD_WRITE_MODE => flash_state <= s_write;
                        when CMD_WRITE_OFFSET => flash_state <= s_writing_start;
                        when CMD_ERASE_OFFSET => flash_state <= s_erase;
                        when CMD_ERASE_CHIP => flash_state <= s_erase;
                        when CMD_READ_MODE => flash_state <= s_reading;
                        when others => null;
                        end case;
                    end if;
                    
                when s_status =>
                    if (cmd_stb = '1') then
                        case cmd_reg(31 downto 24) is
                        when CMD_EXECUTE => flash_state <= s_idle;
                        when CMD_STATUS_MODE => flash_state <= s_status;
                        when CMD_WRITE_MODE => flash_state <= s_write;
                        when CMD_WRITE_OFFSET => flash_state <= s_writing_start;
                        when CMD_ERASE_OFFSET => flash_state <= s_erase;
                        when CMD_ERASE_CHIP => flash_state <= s_erase;
                        when CMD_READ_MODE => flash_state <= s_reading;
                        when others => null;
                        end case;
                    end if;
                
                when s_reading =>
                    if (cmd_stb = '1') then
                        case cmd_reg(31 downto 24) is
                        when CMD_EXECUTE => flash_state <= s_idle;
                        when CMD_STATUS_MODE => flash_state <= s_status;
                        when CMD_WRITE_MODE => flash_state <= s_write;
                        when CMD_WRITE_OFFSET => flash_state <= s_writing_start;
                        when CMD_ERASE_OFFSET => flash_state <= s_erase;
                        when CMD_ERASE_CHIP => flash_state <= s_erase;
                        when CMD_READ_MODE => flash_state <= s_reading;
                        when others => null;
                        end case;
                    end if;
                
                when s_erase =>
                    if (cmd_stb = '1') then
                        case cmd_reg(31 downto 24) is
                        when CMD_EXECUTE => flash_state <= s_idle;
                        when CMD_STATUS_MODE => flash_state <= s_status;
                        when CMD_WRITE_MODE => flash_state <= s_write;
                        when CMD_WRITE_OFFSET => flash_state <= s_writing_start;
                        when CMD_ERASE_OFFSET => flash_state <= s_erase;
                        when CMD_ERASE_CHIP => flash_state <= s_erase;
                        when CMD_ERASE_MODE => flash_state <= s_erasing_start;
                        when CMD_READ_MODE => flash_state <= s_reading;
                        when others => null;
                        end case;
                    end if;
                    
                when s_write =>
                    if (cmd_stb = '1') then
                        case cmd_reg(31 downto 24) is
                        when CMD_EXECUTE => flash_state <= s_idle;
                        when CMD_STATUS_MODE => flash_state <= s_status;
                        when CMD_WRITE_MODE => flash_state <= s_write;
                        when CMD_WRITE_OFFSET => flash_state <= s_writing_start;
                        when CMD_ERASE_OFFSET => flash_state <= s_erase;
                        when CMD_ERASE_CHIP => flash_state <= s_erase;
                        when CMD_READ_MODE => flash_state <= s_reading;
                        when others => null;
                        end case;
                    end if;
                    
                when s_writing_start =>
                    if MEM_ACK_I = '1' then
                        flash_state <= s_writing;
                    end if;
                    
                when s_writing =>
                    if MEM_ACK_I = '1' then
                        flash_state <= s_writing_start;
                    end if;
                    if write_done = '1' then
                        flash_state <= s_idle;
                    end if;
                    
                when s_erasing_start =>
                    flash_state <= s_erasing;
                    
                when s_erasing =>
                    if erase_done = '1' then
                        flash_state <= s_idle;
                    end if;
                
                when others =>
                    flash_state <= s_idle;
                end case;
                
            end if;
        end if;
    end process STATE_LOGIC_PROC;

    WRITE_OFFSET_PROC : process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if (RST_I = '1') then
                write_offset <= (others => '0');
                erase_chip <= '0';
            else
                if (cmd_stb = '1') then
                    case cmd_reg(31 downto 24) is
                    when CMD_WRITE_OFFSET =>
                        write_offset <= cmd_reg(9 downto 0);
                        erase_chip <= '0';
                        
                    when CMD_ERASE_OFFSET =>
                        write_offset <= cmd_reg(9 downto 7) & "0000000";
                        erase_chip <= '0';
                        
                    when CMD_ERASE_CHIP =>
                        write_offset <= (others => '0');
                        erase_chip <= '1';
                        
                    when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process WRITE_OFFSET_PROC;

    STATUS_PROC : process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if RST_I = '1' then
                next_status <= STATUS_READ_END & STATUS_READ_END & STATUS_READ_END & STATUS_READ_END;
            else
                case flash_state is
                
                when s_idle =>
                    if cmd_stb = '1' then
                        next_status <= STATUS_READ_END & STATUS_READ_END & STATUS_READ_END & STATUS_READ_END;
                    end if;
                    
                when s_writing_start =>
                    next_status <= STATUS_WRITING & STATUS_WRITING & STATUS_WRITING & STATUS_WRITING;
                    
                when s_writing =>
                    next_status <= STATUS_WRITING & STATUS_WRITING & STATUS_WRITING & STATUS_WRITING;
                    if write_done = '1' then
                        next_status <= STATUS_WRITE_END & STATUS_WRITE_END & STATUS_WRITE_END & STATUS_WRITE_END;
                    end if;
                    
                when s_erasing_start =>
                    next_status <= STATUS_ERASING & STATUS_ERASING & STATUS_ERASING & STATUS_ERASING;
                    
                when s_erasing =>
                    next_status <= STATUS_ERASING & STATUS_ERASING & STATUS_ERASING & STATUS_ERASING;
                    if erase_done = '1' then
                        next_status <= STATUS_ERASE_END & STATUS_ERASE_END & STATUS_ERASE_END & STATUS_ERASE_END;
                    end if;
                    
                when s_reading =>
                    next_status <= STATUS_READ_END & STATUS_READ_END & STATUS_READ_END & STATUS_READ_END;
                    
                when s_status =>
                    next_status <= FLASH_ID;
                    
                when others => null;
                end case;
            
                if N64_ADDR_VALID_I = '0' then
                    status <= next_status;
                end if;
            end if;
        end if;
    end process STATUS_PROC;

    AD_O_PROC : process (flash_state, status, N64_ADDR_I, read_data, write_buf_dataa, MEM_ACK_I, MEM_DAT_I)
    begin
        case N64_ADDR_I(2 downto 1) is
            when "00" => N64_AD_O <= status(15 downto 0);
            when "01" => N64_AD_O <= status(31 downto 16);
            when "10" => N64_AD_O <= status(47 downto 32);
            when "11" => N64_AD_O <= status(63 downto 48);
            when others => null;
        end case;
        
        if flash_state = s_reading then
            if MEM_ACK_I = '1' then
                N64_AD_O <= MEM_DAT_I;
            else
                N64_AD_O <= read_data;
            end if;
        end if;
        if flash_state = s_write then
            N64_AD_O <= write_buf_dataa;
        end if;
    end process AD_O_PROC;
    
    MEM_CYC_O <= mem_cyc;
    MEM_STB_O <= mem_cyc;
    
    is_read_addr <=  '1' when (N64_ADDR_VALID_I = '1') and (N64_ADDR_I(31 downto 17) = std_logic_vector(to_unsigned(16#0400#, 15))) else '0';
    write_done <= '1' when (flash_state = s_writing and counter = x"003F") and MEM_ACK_I = '1' else '0';
    erase_done <= '1' when (flash_state = s_erasing and ((counter = x"FFFF" and erase_chip = '1') or ((counter(12 downto 0) = x"1FFF" and erase_chip = '0'))) and MEM_ACK_I = '1') else '0';
    
    SRAM_PROC : process (CLK_I)
    begin
        if rising_edge(CLK_I) then
            if RST_I = '1' then
                mem_cyc <= '0';
                MEM_WE_O <= '0';
                MEM_ADDR_O <= (others => '0');
                MEM_DAT_O <= (others => '0');
                counter <= (others => '0');
                read_data_valid <= (others => '0');
                write_buf_web <= '0';
                write_buf_addrb <= (others => '0');
            else
                read_data_valid <= "0" & read_data_valid(read_data_valid'high downto 1);
                write_buf_web <= '0';
                
                case flash_state is
                when s_reading =>
                    if is_read_addr = '1' and N64_RD_I = '1' and N64_RD_LAST_I = '0' then
                        mem_cyc <= '1';
                        MEM_ADDR_O <= N64_ADDR_I(16 downto 1);
                        MEM_WE_O <= '0';
                    end if;
                    if MEM_ACK_I = '1' then
                        mem_cyc <= '0';
                        read_data <= MEM_DAT_I;
                    end if;
                
                when s_writing_start =>
                    -- read the current value
                    mem_cyc <= '1';
                    MEM_WE_O <= '0';
                    MEM_ADDR_O <= write_offset & std_logic_vector(counter(5 downto 0));
                    if MEM_ACK_I = '1' then
                        mem_cyc <= '0';
                        read_data <= MEM_DAT_I;
                    end if;
                    
                    read_data_valid <= "100";
                
                when s_writing =>
                    write_buf_addrb <= std_logic_vector(counter(5 downto 0));
                    if read_data_valid(0) = '1' then
                        mem_cyc <= '1';
                        MEM_WE_O <= '1';
                        MEM_ADDR_O <= write_offset & std_logic_vector(counter(5 downto 0));
                        
                        -- bits can be set from 1 to 0 only
                        MEM_DAT_O <= read_data and write_buf_datab;
                    end if;
                    
                    if MEM_ACK_I = '1' then
                        mem_cyc <= '0';
                        MEM_WE_O <= '0';
                        counter <= counter + 1;
                        write_buf_web <= '1';
                    end if;
                    
                when s_erasing_start =>
                    counter <= unsigned(write_offset(9 downto 7) & "0000000000000");
                
                when s_erasing =>
                    mem_cyc <= '1';
                    MEM_WE_O <= '1';
                    MEM_ADDR_O <= std_logic_vector(counter);
                    MEM_DAT_O <= x"FFFF";
                    if MEM_ACK_I = '1' then
                        mem_cyc <= '0';
                        MEM_WE_O <= '0';
                        counter <= counter + 1;
                    end if;
                    
                when others =>
                    counter <= (others => '0');
                end case;
            end if;
        end if;
    end process;

end Behavioral;
