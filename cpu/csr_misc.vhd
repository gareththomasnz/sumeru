library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.sumeru_constants.ALL;
use work.cpu_types.ALL;

entity csr_misc is
port(
    clk:                        in std_logic;
    csr_in:                     in csr_channel_in_t;
    ivector_addr:               out std_logic_vector(23 downto 0)
    );
end entity;

architecture synth of csr_misc is
    signal ivector_addr_r:      std_logic_vector(31 downto 0) := (others => '0');
begin

ivector_addr <= ivector_addr_r(31 downto 8);

process(clk)
begin
    if (rising_edge(clk)) then
        if (csr_in.csr_op_valid = '1' and 
            csr_in.csr_op_reg = CSR_REG_IVECTOR_ADDR) 
        then
            ivector_addr_r <= csr_in.csr_op_data;
        end if;
    end if;
end process;

end architecture;
