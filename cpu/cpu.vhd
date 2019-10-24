library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use work.memory_channel_types.ALL;

entity cpu is
port(
    clk_50m:                    in std_logic;
    btn:                        in std_logic;
    led:                        out std_logic;
    spi0_sck:                   out std_logic;
    spi0_ss:                    out std_logic;
    spi0_mosi:                  out std_logic;
    spi0_miso:                  in std_logic;
    sdram_data:                 inout std_logic_vector(15 downto 0);
    sdram_addr:                 out std_logic_vector(12 downto 0);
    sdram_ba:                   out std_logic_vector(1 downto 0);
    sdram_dqm:                  out std_logic_vector(1 downto 0);
    sdram_ras:                  out std_logic;
    sdram_cas:                  out std_logic;
    sdram_cke:                  out std_logic;
    sdram_clk:                  out std_logic;
    sdram_we:                   out std_logic;
    sdram_cs:                   out std_logic);
end entity;

architecture synth of cpu is
    signal sys_clk:             std_logic;
    signal mem_clk:             std_logic;
    signal reset_n:             std_logic;

    signal pc:                  std_logic_vector(31 downto 0) := x"00000010";

    signal sdc_in:              mem_channel_in_t;
    signal sdc_out:             mem_channel_out_t;
    signal sdc_data_out:        std_logic_vector(15 downto 0);
    signal sdc_busy:            std_logic;

    signal mc0_in:              mem_channel_in_t;
    signal mc0_out:             mem_channel_out_t;

    signal mc1_in:              mem_channel_in_t;
    signal mc1_out:             mem_channel_out_t;

    signal mc2_in:              mem_channel_in_t;
    signal mc2_out:             mem_channel_out_t;

    signal mc3_in:              mem_channel_in_t;
    signal mc3_out:             mem_channel_out_t;

    signal bootcode_load_done:  std_logic;

    signal icache_hit:          std_logic;
    signal icache_data:         std_logic_vector(31 downto 0);

    signal dcache_addr:         std_logic_vector(31 downto 0) := (others => '0');

    signal dcache_start:        std_logic := '0';
    signal dcache_hit:          std_logic;
    signal dcache_data:         std_logic_vector(31 downto 0);
    signal dcache_wren:         std_logic := '0';
    signal dcache_byteena:      std_logic_vector(3 downto 0);
    signal dcache_write_strobe: std_logic;
    signal dcache_write_data:   std_logic_vector(31 downto 0);

    signal chan0_tlb_hit:       std_logic;
    signal chan1_tlb_hit:       std_logic;
    signal chan0_tlb_lastaddr:  std_logic_vector(15 downto 0) := (others => '1');
    signal chan1_tlb_lastaddr:  std_logic_vector(15 downto 0) := (others => '1');

    signal icache_tlb_hit:      std_logic;
    signal icache_tlb_data:     std_logic_vector(15 downto 0);
    signal icache_translated_addr: std_logic_vector(24 downto 0);        
    signal dcache_tlb_hit:      std_logic;
    signal dcache_tlb_data:     std_logic_vector(15 downto 0);
    signal dcache_translated_addr: std_logic_vector(24 downto 0);        
    signal page_table_baseaddr: std_logic_vector(24 downto 0) := (others => '0');

    signal dcache_tlb_enable:   std_logic := '0';

    type state_t is (
        S1,
        S2,
        S3,
        S4);
        
    signal state:               state_t := S1;

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

    sdram_controller: entity work.sdram_controller
        port map(
            sys_clk => sys_clk,
            mem_clk => mem_clk,
            mc_in => sdc_in,
            mc_out => sdc_out,
            data_out => sdc_data_out,
            sdram_data => sdram_data,
            sdram_addr => sdram_addr,
            sdram_ba => sdram_ba,
            sdram_dqm => sdram_dqm,
            sdram_ras => sdram_ras,
            sdram_cas => sdram_cas,
            sdram_cke => sdram_cke,
            sdram_clk => sdram_clk,
            sdram_we => sdram_we,
            sdram_cs => sdram_cs,
            busy => sdc_busy);
            
    memory_arbitrator: entity work.memory_arbitrator
        port map(
            clk => sys_clk,

            sdc_busy => sdc_busy,
            sdc_in => sdc_in,
            sdc_out => sdc_out,

            mc0_in => mc0_in,
            mc0_out => mc0_out,

            mc1_in => mc1_in,
            mc1_out => mc1_out,

            mc2_in => mc2_in,
            mc2_out => mc2_out,

            mc3_in => mc3_in,
            mc3_out => mc3_out
        );

    bootcode_loader: entity work.memory_loader
        generic map(
            DATA_FILE => "BOOTCODE.hex"
        )
        port map(
            sys_clk => sys_clk,
            mem_clk => mem_clk,
            reset_n => reset_n,

            load_done => bootcode_load_done,
            mc_in => mc1_in,
            mc_out => mc1_out);

    page_tlb: entity work.page_tlb
        port map(
            sys_clk => sys_clk,
            cache_clk => mem_clk,

            chan0_tlb_enable => bootcode_load_done,
            chan1_tlb_enable => dcache_tlb_enable,

            chan0_addr => pc(31 downto 16),
            chan0_hit => chan0_tlb_hit,
            chan0_data => icache_tlb_data,

            chan1_addr => dcache_addr(31 downto 16),
            chan1_hit => chan1_tlb_hit,
            chan1_data => dcache_tlb_data,

            page_table_baseaddr => page_table_baseaddr,

            flush => '0',
            flush_line => (others => '0'),

            mc_in => mc3_in,
            mc_out => mc3_out,

            sdc_data_out => sdc_data_out
            );


    icache_tlb_hit <= 
        '1' when (chan0_tlb_lastaddr = pc(31 downto 16) and 
                  chan0_tlb_hit = '1')
        else '0';

    dcache_tlb_hit <= 
        '1' when (chan1_tlb_lastaddr = dcache_addr(31 downto 16) and 
                  chan1_tlb_hit = '1')
        else '0';

    icache_translated_addr <= icache_tlb_data(8 downto 0) & pc(15 downto 0);

    dcache_translated_addr <= 
        dcache_tlb_data(8 downto 0) & dcache_addr(15 downto 0);

    icache: entity work.icache
        port map(
            sys_clk => sys_clk,
            cache_clk => mem_clk,
            enable => icache_tlb_hit,

            addr => icache_translated_addr,
            hit => icache_hit,
            data => icache_data,

            flush => '0',
            flush_line => (others => '0'),

            mc_in => mc0_in,
            mc_out => mc0_out,

            sdc_data_out => sdc_data_out
            );

    dcache: entity work.dcache
        port map(
            sys_clk => sys_clk,
            mem_clk => mem_clk,
            enable => dcache_tlb_hit,

            addr => dcache_translated_addr,
            start => dcache_start,
            
            hit => dcache_hit,
            read_data => dcache_data,

            wren => dcache_wren,
            byteena => dcache_byteena,
            write_strobe => dcache_write_strobe,
            write_data => dcache_write_data,

            mc_in => mc2_in,
            mc_out => mc2_out,
            sdc_data_out => sdc_data_out);

    dcache_wren <= '1';
    dcache_write_data <= x"1CEB00DA";

    led <= '0' when icache_data = x"1CEB00DA" else '1';

    process(sys_clk)
    begin
        if (rising_edge(sys_clk)) then
            if (chan0_tlb_hit) then
                chan0_tlb_lastaddr <= pc(31 downto 16);
            end if;
            if (chan1_tlb_hit) then
                chan1_tlb_lastaddr <= dcache_addr(31 downto 16);
            end if;
            case state is 
                when S1 => 
                    if (icache_hit = '1' and icache_tlb_hit = '1') then
                        dcache_tlb_enable <= '1';
                        dcache_addr <= x"00010000";
                        dcache_start <= not dcache_start;
                        dcache_byteena <= "1111";
                        state <= S2;
                    end if;
                when S2 =>
                    if (dcache_write_strobe = '1') then
                        dcache_addr <= x"00000000";
                        dcache_start <= not dcache_start;
                        dcache_byteena <= "0000";
                        state <= S3;
                    end if;
                when S3 =>
                    if (dcache_write_strobe = '0') then
                        pc <= x"00010000";
                        -- dcache_start <= not dcache_start;
                        state <= S4;
                    end if;
                when S4 =>
                    if (icache_hit = '1' and icache_tlb_hit = '1') then
                        pc <= pc(31 downto 8) & std_logic_vector(unsigned(pc(7 downto 0)) + 4);
                    end if;
            end case;
        end if;
    end process;
end architecture;


