----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    AXIS_TO_AXI_WRITE_BRIDGE - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Take an AXI stream and output it into the specified memory region
-- 		via a AXI4LITE stream.
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

entity AXIS_TO_AXI_WRITE_BRIDGE is
	generic (
		M_AXI_ADDR_WIDTH: positive := 32;
		M_AXI_DATA_BYTE_LOG: positive := 2
	);
	port (
		--clock and reset
		axi_clk, axi_rst : std_logic;

		--control AXIS bus
		c_s_axis_valid		: in  std_logic;
		c_s_axis_ready		: out std_logic;
		c_s_axis_start		: in  std_logic;
		c_s_axis_stop		: in  std_logic;
		c_s_axis_addr		: in  std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
		--control response bus (indicate finished transaction)
		c_m_axis_valid		: out std_logic;
		c_m_axis_ready		: in  std_logic;

		--data AXIS bus
		d_s_axis_valid		: in  std_logic;
		d_s_axis_ready		: out std_logic;
		d_s_axis_data		: in  std_logic_vector((2**M_AXI_DATA_BYTE_LOG)*8 - 1 downto 0);
		d_s_axis_last		: in  std_logic;

		--AXI WRITE PORTS
		--address write channel
		m_m_axi_awaddr		: out std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
		m_m_axi_awlen		: out std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
		m_m_axi_awsize		: out std_logic_vector(AXI_SIZE_WIDTH - 1 downto 0);
		m_m_axi_awburst		: out std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);
		m_m_axi_awlock		: out std_logic;
		m_m_axi_awcache		: out std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0);
		m_m_axi_awprot		: out std_logic_vector(AXI_PROT_WIDTH - 1 downto 0);
		m_m_axi_awqos		: out std_logic_vector(AXI_QOS_WIDTH - 1 downto 0);
		m_m_axi_awvalid		: out std_logic;
		m_m_axi_awready		: in  std_logic;
		--data write channel
		m_m_axi_wdata		: out std_logic_vector((2**M_AXI_DATA_BYTE_LOG)*8 - 1 downto 0);
		m_m_axi_wstrb		: out std_logic_vector((2**M_AXI_DATA_BYTE_LOG) - 1 downto 0);
		m_m_axi_wlast		: out std_logic;
		m_m_axi_wvalid		: out std_logic;
		m_m_axi_wready		: in  std_logic;
		--write response channel
		m_m_axi_bresp		: in  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		m_m_axi_bvalid		: in  std_logic;
		m_m_axi_bready		: out std_logic;
		
		--debug
		dbg_outbyt			: out std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0)
	);
end AXIS_TO_AXI_WRITE_BRIDGE;

architecture AXIS_TO_AXI_WRITE_BRIDGE_arc of AXIS_TO_AXI_WRITE_BRIDGE is
	signal d_s_axis_ready_in: std_logic;

	type write_state_t is (WRITE_IDLE, WRITE_READY, WRITE_REQUEST, WRITE_TRANSFER, WRITE_TRANSFER_NOSTRB, WRITE_RESPONSE, WRITE_LAST_RESPONSE, WRITE_FINISH);
	signal write_state_curr, write_state_next: write_state_t;
	
	signal write_addr_curr, write_addr_next: std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);
	signal write_transactions_left_curr, write_transactions_left_next: std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
	
	signal ofifo_output_ready, ofifo_output_valid: std_logic;
	signal ofifo_output_last, ofifo_almost_full: std_logic;
	signal ofifo_output_data: std_logic_vector((2**M_AXI_DATA_BYTE_LOG)*8-1 downto 0);
	
	signal ofifo_seen_last: std_logic;
	
	signal dbg_reg_outbyt, dbg_reg_outbyt_next: std_logic_vector(M_AXI_ADDR_WIDTH - 1 downto 0);

begin


	dbg_outbyt <= dbg_reg_outbyt;
	d_s_axis_ready <= d_s_axis_ready_in;
	
	last_watcher: process(axi_clk)
	begin
		if rising_edge(axi_clk) then
			if axi_rst = '1' then
				ofifo_seen_last <= '0';
			else
				if d_s_axis_valid = '1' and d_s_axis_ready_in = '1' then
					if d_s_axis_last = '1' then
						ofifo_seen_last <= '1';
					end if;
				elsif write_state_curr = WRITE_FINISH then
					ofifo_seen_last <= '0';
				end if;	
			end if;
		end if;
	end process;

	input_fifo: entity work.AXIS_FIFO_SWRAP
		Generic map (
			DATA_WIDTH				=> (2**M_AXI_DATA_BYTE_LOG)*8,
			FIFO_DEPTH				=> 2*(2**AXI_LEN_WIDTH),
			ALMOST_FULL_THRESHOLD	=> 2**AXI_LEN_WIDTH
		)
		Port map ( 
			clk => axi_clk,
			rst	=> axi_rst,
			--input axi port
			input_valid		=> d_s_axis_valid,
			input_ready		=> d_s_axis_ready_in,
			input_data		=> d_s_axis_data,
			input_last		=> d_s_axis_last,
			--out axi port
			output_ready	=> ofifo_output_ready,
			output_data		=> ofifo_output_data,
			output_valid	=> ofifo_output_valid,
			output_last		=> ofifo_output_last,
			--output flags
			flag_almost_full	=> ofifo_almost_full
		);


	--------------------------------
	--CORE TO DDR OUTPUT PROCESSES--
	--------------------------------
	write_seq: process(axi_clk)
	begin
		if rising_edge(axi_clk) then
			if axi_rst = '1' then
				write_state_curr 			<= WRITE_IDLE;
				dbg_reg_outbyt 				<= (others => '0');
			else
				write_state_curr 			<= write_state_next;
				write_addr_curr  			<= write_addr_next;
				write_transactions_left_curr<= write_transactions_left_next;
				dbg_reg_outbyt     			<= dbg_reg_outbyt_next;
			end if;
		end if;
	end process;

	--fixed signals
	m_m_axi_awlen	<= (others => '1'); --set all by default (we don't know how many we'll have) (when we run out set wstrb to zero)
	m_m_axi_awsize	<= std_logic_vector(to_unsigned(M_AXI_DATA_BYTE_LOG, m_m_axi_awsize'length));
	m_m_axi_awburst	<= AXI_BURST_INCR;
	m_m_axi_awlock  <= AXI_LOCK_UNLOCKED;
	m_m_axi_awcache <= AXI_CACHE_NORMAL_NONCACHE_NONBUFF;
	m_m_axi_awprot  <= AXI_PROT_UNPRIVILEDGED_NONSECURE_DATA;
	m_m_axi_awqos   <= AXI_QOS_EIGHT;
	m_m_axi_awaddr	<= write_addr_curr;
	--
	m_m_axi_wdata  <= ofifo_output_data;
	
	write_comb: process(write_state_curr, write_addr_curr, write_transactions_left_curr,
			dbg_reg_outbyt, 
			c_s_axis_valid, c_s_axis_start, c_s_axis_stop, c_s_axis_addr, 
			m_m_axi_awready, m_m_axi_wready, m_m_axi_bvalid, ofifo_output_valid, ofifo_output_last,
			c_m_axis_ready,
			ofifo_almost_full, ofifo_seen_last)
	begin
		c_s_axis_ready <= '0';
		c_m_axis_valid <= '0';
	
		write_state_next <= write_state_curr;
		write_addr_next <= write_addr_curr;
		
		m_m_axi_awvalid 	<= '0';
		write_transactions_left_next <= write_transactions_left_curr;
		ofifo_output_ready	<= '0';
		m_m_axi_wvalid 		<= '0';
		m_m_axi_wlast 		<= '0';
		m_m_axi_wstrb		<= (others => '0');
		m_m_axi_bready 		<= '0';
		
		dbg_reg_outbyt_next <= dbg_reg_outbyt;

		if write_state_curr = WRITE_IDLE then
			c_s_axis_ready <= '1';
			if c_s_axis_valid = '1' and c_s_axis_start = '1' and c_s_axis_stop = '0' then
				write_state_next <= WRITE_READY;
				write_addr_next  <= c_s_axis_addr;
			end if;
		elsif write_state_curr = WRITE_READY then
			c_s_axis_ready <= '1';
			if c_s_axis_valid = '0' then
				--IF output fifo is almost full (has enough bytes to feed a full write) 
				--OR output fifo has read a 'last' flag (has to send stuff out cause its never gonna fill)
				--THEN initiate transaction (which potentially ends in a string of zero-strobed writes)
				if ofifo_almost_full = '1' or ofifo_seen_last = '1' then
					write_state_next <= WRITE_REQUEST;
				end if;
			--if central control has deasserted our enable, we know we have to finish early (in-flight reset)
			else 
				if c_s_axis_stop = '1' then
					write_state_next <= WRITE_FINISH;
				elsif c_s_axis_start = '1' then
					write_state_next <= WRITE_READY;
					write_addr_next  <= c_s_axis_addr;
				end if;
			end if;
		elsif write_state_curr = WRITE_REQUEST then
			m_m_axi_awvalid <= '1';
			if m_m_axi_awready = '1' then
				write_state_next <= WRITE_TRANSFER;
				write_transactions_left_next <= (others => '1');
				write_addr_next			  	 <= std_logic_vector(unsigned(write_addr_curr) + to_unsigned(2**(AXI_LEN_WIDTH+M_AXI_DATA_BYTE_LOG), write_addr_curr'length));
			end if;
		elsif write_state_curr = WRITE_TRANSFER then
			ofifo_output_ready	<= m_m_axi_wready;
			m_m_axi_wvalid 		<= ofifo_output_valid;
			m_m_axi_wstrb		<= (others => '1');
			if ofifo_output_valid = '1' and m_m_axi_wready = '1' then
				dbg_reg_outbyt_next <= std_logic_vector(unsigned(dbg_reg_outbyt) + to_unsigned(2**M_AXI_DATA_BYTE_LOG, dbg_reg_outbyt'length));
				if write_transactions_left_curr = (write_transactions_left_curr'range => '0') then
					m_m_axi_wlast <= '1';
					if ofifo_output_last = '0' then
						write_state_next <= WRITE_RESPONSE;
					else
						write_state_next <= WRITE_LAST_RESPONSE;
					end if;
				else
					write_transactions_left_next <= std_logic_vector(unsigned(write_transactions_left_curr) - to_unsigned(1, write_transactions_left_curr'length));
					if ofifo_output_last = '1' then
						--last word but we still are on the write transaction. Change state to go to disable strobing
						write_state_next <= WRITE_TRANSFER_NOSTRB;
					end if;
				end if;
			end if;
		--finishing transaction with empty bytes to avoid overwriting of stuff
		elsif write_state_curr = WRITE_TRANSFER_NOSTRB then
			m_m_axi_wvalid <= '1';
			m_m_axi_wstrb <= (others => '0');
			if m_m_axi_wready = '1' then
				--don't count these as bytes sent
				--dbg_reg_outbyt_next <= std_logic_vector(unsigned(dbg_reg_outbyt) + to_unsigned(1, dbg_reg_outbyt'length));
				if write_transactions_left_curr = (write_transactions_left_curr'range => '0') then
					m_m_axi_wlast <= '1';
					write_state_next <= WRITE_LAST_RESPONSE;
				else
					write_transactions_left_next <= std_logic_vector(unsigned(write_transactions_left_curr) - to_unsigned(1, write_transactions_left_curr'length));
				end if;
			end if;
		elsif write_state_curr = WRITE_RESPONSE then
			m_m_axi_bready <= '1';
			if m_m_axi_bvalid = '1' then
				write_state_next <= WRITE_READY;
			end if;
		elsif write_state_curr = WRITE_LAST_RESPONSE then
			m_m_axi_bready <= '1';
			if m_m_axi_bvalid = '1' then
				write_state_next <= WRITE_FINISH;
			end if;
		elsif write_state_curr = WRITE_FINISH then
			c_m_axis_valid <= '1';
			if c_m_axis_ready = '1' then
				write_state_next <= WRITE_IDLE;
			else
				c_s_axis_ready <= '1';
				if c_s_axis_valid = '1' and c_s_axis_start = '1' and c_s_axis_stop = '0' then
					write_state_next <= WRITE_READY;
					write_addr_next  <= c_s_axis_addr;
				end if;
			end if;
		end if;
	end process;

end AXIS_TO_AXI_WRITE_BRIDGE_arc;