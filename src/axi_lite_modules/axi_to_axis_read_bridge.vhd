----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    AXI_TO_AXIS_READ_BRIDGE - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Read data from a normal AXI4LITE bus and translate it to AXI stream
--		control of the module is done via simple AXI communication
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use work.am_constants.all; --get axi constants from here

entity AXI_TO_AXIS_READ_BRIDGE is
	generic (
		M_AXI_ADDR_WIDTH: positive := 32;
		M_AXI_DATA_BYTE_LOG: positive := 2;
		D_AXIS_DATA_BYTE_LOG: positive := 1
	);
	port (
		--clock and reset for axi and axis buses (connected to memory)
		axi_clk, axi_rst 	: in  std_logic;
		
		--control AXIS bus
		c_s_axis_valid		: in  std_logic;
		c_s_axis_ready		: out std_logic;
		c_s_axis_start		: in  std_logic;
		c_s_axis_stop		: in  std_logic;
		c_s_axis_addr		: in  std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
		c_s_axis_numbytes	: in  std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
		--control response bus (indicate finished transaction)
		c_m_axis_valid		: out std_logic;
		c_m_axis_ready		: in  std_logic;
		
		--data AXIS bus
		d_m_axis_valid		: out std_logic;
		d_m_axis_ready		: in  std_logic;
		d_m_axis_data		: out std_logic_vector((2**D_AXIS_DATA_BYTE_LOG)*8 - 1 downto 0);
		d_m_axis_last		: out std_logic;

		--memory AXI4LITE READ bus
		--adress read channel
		m_m_axi_araddr		: out std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
		m_m_axi_arlen		: out std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
		m_m_axi_arsize		: out std_logic_vector(AXI_SIZE_WIDTH - 1 downto 0);
		m_m_axi_arburst		: out std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);
		m_m_axi_arlock		: out std_logic;
		m_m_axi_arcache		: out std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0);
		m_m_axi_arprot		: out std_logic_vector(AXI_PROT_WIDTH - 1 downto 0);
		m_m_axi_arqos		: out std_logic_vector(AXI_QOS_WIDTH - 1 downto 0);
		m_m_axi_arvalid		: out std_logic;
		m_m_axi_arready		: in  std_logic;
		--read data channel
		m_m_axi_rdata		: in  std_logic_vector((2**M_AXI_DATA_BYTE_LOG)*8 - 1 downto 0);
		m_m_axi_rresp		: in  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		m_m_axi_rlast		: in  std_logic;
		m_m_axi_rvalid		: in  std_logic;
		m_m_axi_rready		: out std_logic;
		
		--debug ports
		dbg_inbyte			: out std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
		dbg_state			: out std_logic_vector(31 downto 0)
	);
end AXI_TO_AXIS_READ_BRIDGE;

architecture AXI_TO_AXIS_READ_BRIDGE_arc of AXI_TO_AXIS_READ_BRIDGE is
	--count number of bytes read so far (for debugging purposes)
	signal dbg_reg_inbyte, dbg_reg_inbyte_next: std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
	signal dbg_state: std_logic_vector(31 downto 0);
	
	--ddr read states
	type read_state_t is (READ_IDLE, READ_READY, READ_REQUEST, READ_TRANSFER, READ_FINISH);
	signal read_state_curr, read_state_next: read_state_t;

	signal read_bytes_remaining_next, read_bytes_remaining_curr: std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
	signal read_addr_next, read_addr_curr: std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
	signal read_align_next, read_align_curr: std_logic_vector(M_AXI_DATA_BYTE_LOG - D_AXIS_DATA_BYTE_LOG - 1 downto 0);
	
	--fifo signals
	signal ififo_input_valid, ififo_input_ready, ififo_output_ready, ififo_output_valid: std_logic;
	signal ififo_input_data: std_logic_vector((2**D_AXIS_DATA_BYTE_LOG)*8 - 1 downto 0);
	signal ififo_input_last: std_logic;
	signal ififo_input_last_data, ififo_output_last_data: std_logic_vector((2**D_AXIS_DATA_BYTE_LOG)*8 downto 0);
	alias  ififo_output_data: std_logic_vector((2**D_AXIS_DATA_BYTE_LOG)*8 - 1 downto 0) is ififo_output_last_data((2**D_AXIS_DATA_BYTE_LOG)*8 downto 0);
	alias  ififo_output_last: std_logic is ififo_output_last_data((2**D_AXIS_DATA_BYTE_LOG)*8);
	signal ififo_almost_empty: std_logic;
	
	signal mem_read_addr_curr, mem_read_addr_next: std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);

begin

	assert M_AXI_DATA_BYTE_LOG >= D_AXIS_DATA_BYTE_LOG
	report "MASTER AXI DATA WIDTH HAS TO BE WIDER THAN MASTER AXIS DATA WIDTH"
	severity failure;

	dbg_inbyte <= dbg_reg_inbyte;
	
	-------------------------------
	--DDR TO CORE INPUT PROCESSES--
	-------------------------------
	read_seq: process(axi_clk)
	begin
		if rising_edge(axi_clk) then
			if axi_rst = '1' then
				read_state_curr 			<= READ_IDLE;
				dbg_reg_inbyte				<= (others => '0');
			else
				read_state_curr				<= read_state_next;
				read_bytes_remaining_curr	<= read_bytes_remaining_next;
				read_addr_curr 				<= read_addr_next;
				read_align_curr 			<= read_align_next;
				dbg_reg_inbyte 				<= dbg_reg_inbyte_next;
			end if;
		end if;
	end process;


	--fixed AXI signals
	m_m_axi_arsize	<= std_logic_vector(to_unsigned(D_AXIS_DATA_BYTE_LOG, m_m_axi_arsize'length));
	m_m_axi_arburst	<= AXI_BURST_INCR;
	m_m_axi_arlock  <= AXI_LOCK_UNLOCKED;
	m_m_axi_arcache <= AXI_CACHE_NORMAL_NONCACHE_NONBUFF;
	m_m_axi_arprot  <= AXI_PROT_UNPRIVILEDGED_NONSECURE_DATA;
	m_m_axi_arqos   <= AXI_QOS_EIGHT;
	m_m_axi_araddr	<= read_addr_curr;
	--end fixed AXI signals
	read_comb: process(
		read_state_curr, read_bytes_remaining_curr, read_addr_curr, read_align_curr,
		c_m_axis_ready, c_s_axis_valid, c_s_axis_start, c_s_axis_stop, c_s_axis_numbytes, c_s_axis_addr, 
		dbg_reg_inbyte,
		m_m_axi_arready, m_m_axi_rvalid, m_m_axi_rlast, ififo_input_ready, ififo_almost_empty)
	begin
		--control
		c_s_axis_ready 				<= '0';
		c_m_axis_valid 				<= '0';
	
		--signals defaults
		read_state_next 			<= read_state_curr;
		read_bytes_remaining_next 	<= read_bytes_remaining_curr;
		read_addr_next 				<= read_addr_curr;
		read_align_next 			<= read_align_curr;
		--axi defaults
		m_m_axi_arvalid				<= '0';
		m_m_axi_arlen				<= (others => '0');
		m_m_axi_rready 				<= '0';
		--
		ififo_input_valid 			<= '0';
		ififo_input_last 			<= '0';
		--
		dbg_reg_inbyte_next 		<= dbg_reg_inbyte;
		dbg_state					<= "00000000";

		if read_state_curr = READ_IDLE then
			dbg_state <= x"00000001";
			c_s_axis_ready <= '1';
			--wait for central control to enable us
			if c_s_axis_valid = '1' and c_s_axis_start = '1' and c_s_axis_stop = '0' then
				read_state_next <= READ_REQUEST;
				read_bytes_remaining_next <= c_s_axis_numbytes;
				read_addr_next <= c_s_axis_addr;
			end if;
		elsif read_state_curr = READ_READY then
			dbg_state <= x"00000010";
			c_s_axis_ready <= '1';
			if c_s_axis_valid = '0' then
				--check if we still have bytes left
				if read_bytes_remaining_curr = (read_bytes_remaining_curr'high downto 0 => '0') then
					read_state_next <= READ_FINISH;
				else
					--still have bytes left, only initiate transaction if fifo is almost empty
					if ififo_almost_empty = '1' then
						read_state_next <= READ_REQUEST;
					end if;
				end if;
			else
				--early (in-flight) signal. check what it is
				if c_s_axis_stop = '1' then
					read_state_next <= READ_FINISH;
				elsif c_s_axis_start = '1' then
					--restart reading from new position
					read_state_next <= READ_REQUEST;
					read_bytes_remaining_next <= c_s_axis_numbytes;
					read_addr_next <= c_s_axis_addr;
				end if;
			end if;
		elsif read_state_curr = READ_REQUEST then
			dbg_state <= x"00000100";
			--align for read mux
			read_align_next			  <= read_addr_curr(M_AXI_DATA_BYTE_LOG - 1 downto D_AXIS_DATA_BYTE_LOG);
			--if we still have more than the max transaction of bytes left, perform a transaction
			if read_bytes_remaining_curr(read_bytes_remaining_curr'high downto AXI_LEN_WIDTH + D_AXIS_DATA_BYTE_LOG)
					/= (read_bytes_remaining_curr'high downto AXI_LEN_WIDTH + D_AXIS_DATA_BYTE_LOG => '0') then
				m_m_axi_arvalid 		<= '1';
				m_m_axi_arlen 			<= (others => '1');
				if m_m_axi_arready = '1' then
					read_bytes_remaining_next <= std_logic_vector(unsigned(read_bytes_remaining_curr) - to_unsigned(2**(AXI_LEN_WIDTH+D_AXIS_DATA_BYTE_LOG), read_bytes_remaining_curr'length));
					read_addr_next			  <= std_logic_vector(unsigned(read_addr_curr) 			  + to_unsigned(2**(AXI_LEN_WIDTH+D_AXIS_DATA_BYTE_LOG), 			read_addr_curr'length));
					read_state_next 		  <= READ_TRANSFER;
				end if;
			--we have less than max, but still have some
			else --if read_bytes_remaining_curr(AXI_LEN_WIDTH + D_AXIS_DATA_BYTE_LOG - 1 downto D_AXIS_DATA_BYTE_LOG) /= (AXI_LEN_WIDTH - 1 downto 0 => '0') then
				m_m_axi_arvalid 		<= '1';
				m_m_axi_arlen 			<= std_logic_vector(unsigned(read_bytes_remaining_curr(AXI_LEN_WIDTH + D_AXIS_DATA_BYTE_LOG - 1 downto D_AXIS_DATA_BYTE_LOG)) - to_unsigned(1, AXI_LEN_WIDTH));
				if m_m_axi_arready = '1' then
					read_bytes_remaining_next <= (others => '0');
					read_state_next 		  <= READ_TRANSFER;
				end if;
				--read_addr_next; --don't care for this value since it won't be used again
			end if;
		elsif read_state_curr = READ_TRANSFER then
			dbg_state <= x"00001000";
			ififo_input_valid <= m_m_axi_rvalid;
			m_m_axi_rready <= ififo_input_ready;
			if read_bytes_remaining_curr = (read_bytes_remaining_curr'high downto 0 => '0') then
				ififo_input_last <= '1';
			end if;
			if m_m_axi_rvalid = '1' and ififo_input_ready = '1' then
				dbg_reg_inbyte_next <= std_logic_vector(unsigned(dbg_reg_inbyte) + to_unsigned(2**D_AXIS_DATA_BYTE_LOG, dbg_reg_inbyte'length));
				read_align_next	<= std_logic_vector(unsigned(read_align_curr) + to_unsigned(1, read_align_curr'length));
				if m_m_axi_rlast = '1' then
					--burst is finished, go back to requesting transactions
					read_state_next <= READ_READY;
				end if;
			end if;
		elsif read_state_curr = READ_FINISH then
			dbg_state <= x"00010000";
			--no more bytes left, goto idle state when we can (wait to sync with master fsm)
			c_m_axis_valid <= '1';
			if c_m_axis_ready = '1' then
				read_state_next <= READ_IDLE;
			else
				--just in case the master is not waiting for ack, bypass it and start next read transaction
				c_s_axis_ready <= '1';
				--wait for central control to enable us
				if c_s_axis_valid = '1' and c_s_axis_start = '1' and c_s_axis_stop = '0' then
					read_state_next <= READ_REQUEST;
					read_bytes_remaining_next <= c_s_axis_numbytes;
					read_addr_next <= c_s_axis_addr;
				end if;
			end if;
		end if;
	end process;

	gen_ififo_input: if M_AXI_DATA_BYTE_LOG > D_AXIS_DATA_BYTE_LOG generate
		assign_ififo_input_data: process(m_m_axi_rdata, read_align_curr)
		begin
			ififo_input_data <= m_m_axi_rdata((2**D_AXIS_DATA_BYTE_LOG)*8 - 1 downto 0);
			for i in 0 to 2**(M_AXI_DATA_BYTE_LOG - D_AXIS_DATA_BYTE_LOG) - 1 loop	
				if unsigned(read_align_curr) = to_unsigned(i, read_align_curr'length) then
					ififo_input_data <= m_m_axi_rdata((2**D_AXIS_DATA_BYTE_LOG)*8*(i+1) - 1 downto (2**D_AXIS_DATA_BYTE_LOG)*8*i);
					exit;
				end if;
			end loop;
		end process;
	end generate;
	gen_ififo_input_equal_length: if M_AXI_DATA_BYTE_LOG = D_AXIS_DATA_BYTE_LOG generate
		ififo_input_data <= m_m_axi_rdata;
	end generate;

	--FIFO buffer to allow for BURST transactions
	ififo_input_last_data <= ififo_input_last & ififo_input_data;
	input_sample_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => (2**D_AXIS_DATA_BYTE_LOG)*8 + 1,
			FIFO_DEPTH => 2*(2**AXI_LEN_WIDTH),
			ALMOST_EMPTY_THRESHOLD => 2**AXI_LEN_WIDTH
		)
		Port map (
			clk => axi_clk, rst => axi_rst,
			input_valid			=> ififo_input_valid,
			input_ready			=> ififo_input_ready,
			input_data			=> ififo_input_last_data,
			--out axi port
			output_ready		=> ififo_output_ready,
			output_data			=> ififo_output_last_data,
			output_valid		=> ififo_output_valid,
			--output flags
			flag_almost_empty 	=> ififo_almost_empty
		);
		
	
	d_m_axis_valid 		<= ififo_output_valid;
	ififo_output_ready 	<= d_m_axis_ready;
	d_m_axis_data		<= ififo_output_data;
	d_m_axis_last		<= ififo_output_last; 

end AXI_TO_AXIS_READ_BRIDGE_arc;