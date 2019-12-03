library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use work.memory_channel_types.ALL;
use work.cpu_types.ALL;
use work.sumeru_constants.ALL;

entity cpu_stage_ifetch is
port(
    sys_clk:            in std_logic;
    cache_clk:          in std_logic;
    enable:             in std_logic;
    fifo_full:          in std_logic;
    fifo_wren:          out std_logic;
    fifo_write_data:    out std_logic_vector(31 downto 0);
    tlb_mc_in:          out mem_channel_in_t;
    tlb_mc_out:         in mem_channel_out_t;
    cache_mc_in:        out mem_channel_in_t;
    cache_mc_out:       in mem_channel_out_t;
    sdc_data_out:       in std_logic_vector(15 downto 0)
    );
end entity;

architecture synth of cpu_stage_ifetch is
    signal pc:                  std_logic_vector(31 downto 0) := IVECTOR_RESET_ADDR(31 downto 8) & BOOT_OFFSET; 

    signal icache_tlb_meta:     std_logic_vector(7 downto 0);
    signal icache_tlb_data:     std_logic_vector(15 downto 0);
    signal icache_tlb_last:     std_logic_vector(14 downto 0) := (others => '1');
    signal icache_tlb_load:     std_logic := '0';
    signal icache_tlb_busy:     std_logic := '0';

    signal icache_translated_addr: std_logic_vector(30 downto 0);
    alias icache_tlb_present:   std_logic is icache_tlb_data(15);

    signal icache_meta:         std_logic_vector(31 downto 0);
    signal icache_data:         std_logic_vector(31 downto 0);
    signal icache_load:         std_logic := '0';
    signal icache_busy:         std_logic := '0';

    signal page_table_baseaddr: std_logic_vector(24 downto 0) := (others => '0');

    type state_t is (
        RUNNING
        );

    signal state:               state_t := RUNNING;

begin
icache_tlb: entity work.read_cache_8x16x256
    port map(
        sys_clk => sys_clk,
        cache_clk => cache_clk,
        addr => pc(31 downto 16),
        meta => icache_tlb_meta,
        data => icache_tlb_data,
        load => icache_tlb_load,
        flush => '0',
        -- flush_strobe =>
        mc_in => tlb_mc_in,
        mc_out => tlb_mc_out,
        sdc_data_out => sdc_data_out,
        page_table_baseaddr => page_table_baseaddr);

-- Bit 31 of page address is reserved as 'present' bit
icache_translated_addr <= icache_tlb_data(14 downto 0) & pc(15 downto 0); 

icache: entity work.read_cache_16x32x256
    port map(
        sys_clk => sys_clk,
        cache_clk => cache_clk,
        addr => icache_translated_addr,
        meta => icache_meta,
        data => icache_data,
        load => icache_load,
        flush => '0',
        -- flush_strobe =>
        mc_in => cache_mc_in,
        mc_out => cache_mc_out,
        sdc_data_out => sdc_data_out);

process(sys_clk)
begin
    if (rising_edge(sys_clk)) then
        icache_load <= '0';
        icache_tlb_load <= '0';
        fifo_wren <= '0';
        case state is 
            when RUNNING =>
                if (icache_tlb_meta = (pc(22 downto 16) & "1")) then
                    -- it takes one cycle delay to switch tlb entries
                    -- hence this check and delay
                    if (icache_tlb_last = pc(30 downto 16)) then
                        -- TLB HIT
                        icache_tlb_busy <= '0';
                        if (icache_meta(31 downto 12) = (pc(30 downto 12) & "1")) 
                        then 
                            -- ICACHE HIT
                            icache_busy <= '0';
                            if (fifo_full /= '1') then
                                fifo_wren <= '1';
                                fifo_write_data <= icache_data;
                                pc <= std_logic_vector(unsigned(pc) + 4);
                                case
                                 (JAL)
                                 (JALR)
                                 (BRANCH)
                                 (EXCEPTION)
                                 (INTERRUPT)
                                 (FENCE.I)
                                 (TLB FLUSH)
                                end
                            end if;
                        else
                            -- LOAD CACHE LINE
                            if (icache_busy = '0') then
                                icache_load <= '1';
                                icache_busy <= '1';
                            end if;
                        end if;
                    -- else
                        -- if (icache_tlb_present = '0') then
                            -- RAISE PAGE NOT PRESENT EXCEPTION
                        -- end if;
                    end if;
                    icache_tlb_last <= pc(30 downto 16);
                else
                    -- LOAD TLB ENTRY
                    if (icache_tlb_busy = '0' and enable = '1') then
                        icache_tlb_load <= '1';
                        icache_tlb_busy <= '1';
                    end if;
                end if;
        end case;
    end if;
end process;
end architecture;