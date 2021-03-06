library ieee, lpm;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use lpm.lpm_components.lpm_counter;
use work.memory_channel_types.ALL;


entity sdram_controller_test is
port(
        clk_50m:                in std_logic;
        btn:                    in std_logic;
        led:                    out std_logic;
        spi0_sck:               out std_logic;
        spi0_ss:                out std_logic;
        spi0_mosi:              out std_logic;
        spi0_miso:              in std_logic;
        sdram_data:             inout std_logic_vector(15 downto 0);
        sdram_addr:             out std_logic_vector(12 downto 0);
        sdram_ba:               out std_logic_vector(1 downto 0);
        sdram_dqm:              out std_logic_vector(1 downto 0);
        sdram_ras:              out std_logic;
        sdram_cas:              out std_logic;
        sdram_cke:              out std_logic;
        sdram_clk:              out std_logic;
        sdram_we:               out std_logic;
        sdram_cs:               out std_logic);
end entity;

architecture synth of sdram_controller_test is
        signal sys_clk:         std_logic;
        signal mem_clk:         std_logic;
        signal reset_n:         std_logic;
        signal mc_in:           mem_channel_in_t := ((others => '0'), '0', '0', '0', (others => '0'), (others => '0'));
        signal mc_out:          mem_channel_out_t;
        signal byte_counter:    std_logic_vector(2 downto 0);
        signal r_counter:       std_logic_vector(19 downto 0) := (others => '0');
        signal ram_data_out:    std_logic_vector(15 downto 0);

        type controller_state_t is (
            START,
            WRITE_WAIT,
            WRITE_DATA,
            READ,
            READ_WAIT,
            READ_DATA,
            DONE);

        signal state:           controller_state_t := START;

begin
        spi0_sck <= '0';
        spi0_ss <= '0';
        spi0_mosi <= '0';

        pll: entity work.pll 
                port map(
                        inclk0 => clk_50m,
                        c0 => sys_clk,
                        c1 => mem_clk,
                        locked => reset_n);

        led <= ram_data_out(3);

        sdram_controller: entity work.sdram_controller
                port map(
                        sys_clk => sys_clk,
                        mem_clk => mem_clk,
                        reset_n => reset_n,
                        data_out => ram_data_out,

                        mc_in => mc_in,
                        mc_out => mc_out,
                        sdram_data => sdram_data,
                        sdram_addr => sdram_addr,
                        sdram_ba => sdram_ba,
                        sdram_dqm => sdram_dqm,
                        sdram_ras => sdram_ras,
                        sdram_cas => sdram_cas,
                        sdram_cke => sdram_cke,
                        sdram_clk => sdram_clk,
                        sdram_we => sdram_we,
                        sdram_cs => sdram_cs);

        process(sys_clk)
        begin
            if (rising_edge(sys_clk)) then
                byte_counter <= std_logic_vector(unsigned(byte_counter) - 1);
                case state is
                    when START =>
                        mc_in.op_addr <= r_counter & "0000";
                        mc_in.op_start <= '1';
                        mc_in.op_wren <= '1';
                        mc_in.op_dqm <= "00";
                        mc_in.op_burst <= '0';          -- XXX Set this
                        state <= WRITE_WAIT;
                    when WRITE_WAIT =>
                        mc_in.write_data <= r_counter(15 downto 0);
                        if (mc_out.op_strobe = mc_in.op_start) then
                            if (mc_in.op_burst = '1') then
                                state <= WRITE_DATA;
                                byte_counter <= "110";
                            else
                                state <= READ;
                            end if;
                        end if;
                    when WRITE_DATA =>
                        mc_in.write_data <= r_counter(15 downto 0);
                        if (byte_counter = "000") then
                            state <= READ;
                        end if;
                    when READ =>
                        mc_in.op_start <= '0';
                        mc_in.op_wren <= '0';
                        state <= READ_WAIT;
                    when READ_WAIT =>
                        if (mc_out.op_strobe = mc_in.op_start) then
                            if (mc_in.op_burst = '1') then
                                byte_counter <= "110";
                                state <= READ_DATA;
                            else
                                r_counter <= std_logic_vector(unsigned(r_counter) + 1);
                                state <= START;
                            end if;
                        end if;
                    when READ_DATA =>
                        if (byte_counter = "000") then
                            state <= START;
                            r_counter <= std_logic_vector(unsigned(r_counter) + 1);
                        end if;
                    when DONE =>
                end case;
            end if;
        end process;
end architecture;


