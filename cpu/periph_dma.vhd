library ieee, lpm;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.cpu_types.ALL;
use work.memory_channel_types.ALL;

entity periph_dma is
port(
    clk:                        in std_logic;
    mc_in:                      out mem_channel_in_t;
    mc_out:                     in mem_channel_out_t;
    sdc_data_out:               in std_logic_vector(15 downto 0);
    pdma_in:                    in periph_dma_channel_in_t;
    pdma_out:                   out periph_dma_channel_out_t
    );
end entity;

architecture synth of periph_dma is
signal read_ack_r:      std_logic := '0';
signal write_ack_r:     std_logic := '0';
signal mem_op_start:    std_logic := '0';
signal mem_op_strobe_save: std_logic;

type mem_state_t is (
    MS_RUNNING,
    MS_WAIT);

signal mem_state: mem_state_t := MS_RUNNING;

begin

mc_in.op_start <= mem_op_start;
mc_in.op_burst <= '0';

pdma_out.write_ack <= write_ack_r;
pdma_out.read_ack <= read_ack_r;

process(clk)
begin
    if (rising_edge(clk)) then
        case mem_state is
            when MS_RUNNING =>
                -- read check must have priority as we don't set
                -- read ack in MS_WAIT and set in below instead
                if (pdma_in.read /= read_ack_r) then
                    mc_in.op_addr <= pdma_in.read_addr(24 downto 1);
                    mem_op_start <= not mem_op_start;
                    mc_in.op_wren <= '0';
                    mc_in.op_dqm <= "00";
                    mem_op_strobe_save <= mc_out.op_strobe;
                    mem_state <= MS_WAIT;
                elsif (pdma_in.write /= write_ack_r) then
                    mc_in.op_addr <= pdma_in.write_addr(24 downto 1);
                    mem_op_start <= not mem_op_start;
                    mc_in.op_wren <= '1';
                    mc_in.write_data <= pdma_in.write_data & pdma_in.write_data;
                    mc_in.op_dqm(0) <= pdma_in.write_addr(0);
                    mc_in.op_dqm(1) <= not pdma_in.write_addr(0);
                    mem_op_strobe_save <= mc_out.op_strobe;
                    mem_state <= MS_WAIT;
                end if;
            when MS_WAIT =>
                if (mc_out.op_strobe /= mem_op_strobe_save) then
                    if (mc_in.op_wren = '1') then
                        write_ack_r <= not write_ack_r;
                    else
                        read_ack_r <= not read_ack_r;
                        if (pdma_in.read_addr(0) = '0') then
                            pdma_out.read_data <= sdc_data_out(7 downto 0);
                        else
                            pdma_out.read_data <= sdc_data_out(15 downto 8);
                        end if;
                    end if;
                    mem_state <= MS_RUNNING;
                end if;
        end case;
    end if;
end process;

end architecture;
