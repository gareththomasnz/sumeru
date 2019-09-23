LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY alt_ram_byteena IS
        GENERIC
        (
                AWIDTH          : INTEGER;
                DWIDTH          : INTEGER
        );
	PORT
	(
		address		: IN STD_LOGIC_VECTOR ((AWIDTH - 1) DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR ((DWIDTH - 1) DOWNTO 0);
		wren		: IN STD_LOGIC ;
                byteena         : IN STD_LOGIC_VECTOR (((DWIDTH / 8) - 1) DOWNTO 0);
		q		: OUT STD_LOGIC_VECTOR ((DWIDTH - 1) DOWNTO 0)
	);
END alt_ram_byteena;


ARCHITECTURE SYN OF alt_ram_byteena IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (31 DOWNTO 0);

BEGIN
	q    <= sub_wire0(31 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		intended_device_family => "Cyclone IV E",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => (2**AWIDTH),
		operation_mode => "SINGLE_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		ram_block_type => "M9K",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		widthad_a => AWIDTH,
		width_a => DWIDTH,
		width_byteena_a => 4
	)
	PORT MAP (
		address_a => address,
		clock0 => clock,
		data_a => data,
		wren_a => wren,
		q_a => sub_wire0,
                byteena_a => byteena

	);



END SYN;
