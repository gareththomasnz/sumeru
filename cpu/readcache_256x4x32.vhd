library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use work.memory_channel_types.ALL;

entity read_cache_256x4x32 is
port(
        clk:                    in std_logic;
        clk_n:                  in std_logic;

        addr:                   in std_logic_vector(24 downto 0);

        hit:                    out std_logic;
        data:                   out std_logic_vector(31 downto 0);

        enable:                 in std_logic;
        flush:                  in std_logic;
        flush_ack:              out std_logic;

        mc_in:                  out mem_channel_in_t;
        mc_out:                 in mem_channel_out_t;
        sdc_data_out:           in std_logic_vector(15 downto 0)
    );
end entity;

architecture synth of read_cache_256x4x32 is
    signal meta_wren:           std_logic := '0';

    signal data0:               std_logic_vector(31 downto 0);
    signal data1:               std_logic_vector(31 downto 0);
    signal data2:               std_logic_vector(31 downto 0);
    signal data3:               std_logic_vector(31 downto 0);

    signal data0_wren:          std_logic := '0';
    signal data1_wren:          std_logic := '0';
    signal data2_wren:          std_logic := '0';
    signal data3_wren:          std_logic := '0';

    signal op_start_r:          std_logic := '0';

    type cache_state_t is (
        IDLE,
        FLUSH_CACHE,
        WAIT_B1,
        WAIT_B2,
        WAIT_B3,
        WAIT_B4,
        WAIT_B5,
        WAIT_B6,
        WAIT_B7,
        WAIT_B8
    );

    signal state:               cache_state_t := IDLE;

    signal meta:                std_logic_vector(15 downto 0);
    signal meta_data:           std_logic_vector(15 downto 0);
    signal meta_data_line_valid: std_logic;

    signal write_data:          std_logic_vector(31 downto 0);
    signal meta_addr:           std_logic_vector(7 downto 0);

    signal flush_enable:        std_logic := '0';
    signal flush_ack_r:         std_logic := '0';
    signal flush_addr:          std_logic_vector(7 downto 0);

begin
    flush_ack <= flush_ack_r;

    meta_addr <= 
        addr(11 downto 4) when flush_enable = '0' else flush_addr;

    meta_ram: entity work.ram1p_256x16
        port map(
            clock => clk_n,
            address => meta_addr,
            data => meta_data,
            wren => meta_wren,
            q => meta);

    data0_ram: entity work.ram1p_256x32
        port map(
            clock => clk_n,
            address => addr(11 downto 4),
            data => write_data,
            wren => data0_wren,
            q => data0);

    data1_ram: entity work.ram1p_256x32
        port map(
            clock => clk_n,
            address => addr(11 downto 4),
            data => write_data,
            wren => data1_wren,
            q => data1);

    data2_ram: entity work.ram1p_256x32
        port map(
            clock => clk_n,
            address => addr(11 downto 4),
            data => write_data,
            wren => data2_wren,
            q => data2);

    data3_ram: entity work.ram1p_256x32
        port map(
            clock => clk_n,
            address => addr(11 downto 4),
            data => write_data,
            wren => data3_wren,
            q => data3);

    with addr(3 downto 2) select 
        data <= data0 when "00",
                data1 when "01",
                data2 when "10",
                data3 when others;

    hit <= '1' when meta(13 downto 0) = (addr(24 downto 12) & "1") else '0';

    meta_data <=  "00" & addr(24 downto 12) & meta_data_line_valid;
 
    mc_in.op_start <= op_start_r;
    mc_in.op_wren <= '0';
    mc_in.op_dqm <= "00";
    mc_in.op_burst <= '1';
    mc_in.op_addr <= addr(24 downto 4) & "000"; -- read only at 16 byte boundary
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            data0_wren <= '0';
            data1_wren <= '0';
            data2_wren <= '0';
            data3_wren <= '0';
            meta_wren <= '0';
            meta_data_line_valid <= '1';
            write_data(15 downto 0) <= write_data(31 downto 16);
            write_data(31 downto 16) <= sdc_data_out;

            case state is
                when IDLE =>
                    if (flush /= flush_ack_r) then
                        flush_enable <= '1';
                        flush_addr <= (others => '1');
                        meta_data_line_valid <= '0';
                        meta_wren <= '1';
                        state <= FLUSH_CACHE;
                    elsif (enable = '1' and hit = '0') then
                        op_start_r <= not op_start_r;
                        state <= WAIT_B1;
                        -- Invalidate line till it is fully loaded
                        meta_data_line_valid <= '0';
                        meta_wren <= '1';
                    end if;
                when FLUSH_CACHE =>
                    meta_data_line_valid <= '0';
                    meta_wren <= '1';
                    if (flush_addr = x"00") then
                        flush_enable <= '0';
                        flush_ack_r <= not flush_ack_r;
                        state <= IDLE;
                    else
                        flush_addr <= std_logic_vector(unsigned(flush_addr) - 1);
                    end if;
                when WAIT_B1 =>
                    -- Invariant mc_out.op_strobe will be equal to op_start_r
                    -- after each transaction.
                    if (mc_out.op_strobe = op_start_r) then
                        state <= WAIT_B2;
                    end if;
                when WAIT_B2 =>
                    state <= WAIT_B3;
                    data0_wren <= '1';
                when WAIT_B3 =>
                    state <= WAIT_B4;
                when WAIT_B4 =>
                    state <= WAIT_B5;
                    data1_wren <= '1';
                when WAIT_B5 =>
                    state <= WAIT_B6;
                when WAIT_B6 =>
                    state <= WAIT_B7;
                    data2_wren <= '1';
                when WAIT_B7 =>
                    state <= WAIT_B8;
                when WAIT_B8 =>
                    state <= IDLE;
                    data3_wren <= '1';
                    meta_wren <= '1';
            end case;
        end if;
    end process;

end architecture;


