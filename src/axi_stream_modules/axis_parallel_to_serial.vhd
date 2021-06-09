----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    PARALLEL_TO_SERIAL - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Transform a parallel input AXI stream into a serial one.
--		Last signal is only propagated to the last sample in the stream
--		USER signal is propagated to all serialized samples corresponding
--		to a parallel input
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
use ieee.numeric_std.all;

entity axis_parallel_to_serial is
	generic (
		DATA_WIDTH				:	integer := 16;
		PARALLEL_SIGNAL_COUNT	: 	integer := 8;
		USER_WIDTH				:	integer := 1;
		START_MSB				:	boolean := true
	);
	port (
		clk, rst : in std_logic;
		input_ready	: out	std_logic;
		input_valid	: in 	std_logic;
		input_data	: in 	std_logic_vector(DATA_WIDTH*PARALLEL_SIGNAL_COUNT - 1 downto 0);
		input_last	: in 	std_logic := '0';
		input_user	: in 	std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in 	std_logic;
		output_valid: out 	std_logic;
		output_data	: out 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last : out 	std_logic;
		output_user	: out 	std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_parallel_to_serial;

architecture axis_parallel_to_serial_arc of axis_parallel_to_serial is
	type p2s_state_t is (IDLE, SENDING);
	signal state_curr, state_next: p2s_state_t;

	signal input_data_buf, input_data_buf_next, input_data_buf_shifted: std_logic_vector(DATA_WIDTH*PARALLEL_SIGNAL_COUNT - 1 downto 0);
	signal input_last_buf, input_last_buf_next: std_logic;
	signal input_user_buf, input_user_buf_next: std_logic_vector(USER_WIDTH - 1 downto 0);
	signal input_data_buf_occ, input_data_buf_occ_next: std_logic_vector(PARALLEL_SIGNAL_COUNT - 1 downto 0);


	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	seq: process(clk, inner_reset)
	begin
		if rising_edge(clk) then
			if inner_reset = '1' then
				state_curr <= IDLE;
				input_data_buf <= (others => '0');
				input_last_buf <= '0';
				input_user_buf <= (others => '0');
				input_data_buf_occ <= (others => '0');
			else
				state_curr <= state_next;
				input_data_buf <= input_data_buf_next;
				input_last_buf <= input_last_buf_next;
				input_user_buf <= input_user_buf_next;
				input_data_buf_occ <= input_data_buf_occ_next;
			end if;
		end if;
	end process;

	comb: process(state_curr, 
		input_valid, input_data_buf, input_last_buf, input_user_buf, input_data_buf_occ, input_data, input_last, input_user, 
		output_ready,
		input_data_buf_shifted) 
	begin
		state_next <= state_curr;

		input_ready <= '0';
		output_last <= '0';
		output_valid<= '0';
		output_user <= (others => '0');

		input_data_buf_next <= input_data_buf;
		input_last_buf_next <= input_last_buf;
		input_user_buf_next <= input_user_buf;
		input_data_buf_occ_next <= input_data_buf_occ;

		if state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				input_data_buf_next <= input_data;
				input_last_buf_next <= input_last;
				input_user_buf_next <= input_user;
				input_data_buf_occ_next <= (others => '1');
				state_next <= SENDING;
			end if;
		elsif state_curr = SENDING then
			output_valid <= '1';
			output_user <= input_user_buf;
			if output_ready = '1' then
				if input_data_buf_occ = std_logic_vector(to_unsigned(1, PARALLEL_SIGNAL_COUNT)) then
					--last sample to serialize
					output_last <= input_last_buf;
					------
					--state_next  <= IDLE;
					------
					input_ready <= '1';
					if input_valid = '1' then
						input_data_buf_next <= input_data;
						input_last_buf_next <= input_last;
						input_user_buf_next <= input_user;
						input_data_buf_occ_next <= (others => '1');
					else
						state_next  <= IDLE;	
					end if;
				else
					--intermediate sample to serialize
					input_data_buf_occ_next <= '0' & input_data_buf_occ(PARALLEL_SIGNAL_COUNT - 1 downto 1);
					input_data_buf_next 	<= input_data_buf_shifted;
				end if;
			end if;
		end if;
	end process;


	start_on_msb: if START_MSB generate
		input_data_buf_shifted <= input_data_buf(DATA_WIDTH*(PARALLEL_SIGNAL_COUNT - 1) - 1 downto 0) & (DATA_WIDTH - 1 downto 0 => '0');
		output_data <= input_data_buf(DATA_WIDTH*PARALLEL_SIGNAL_COUNT - 1 downto DATA_WIDTH*(PARALLEL_SIGNAL_COUNT-1));
	end generate;

	start_on_lsb: if not START_MSB generate
		input_data_buf_shifted <= (DATA_WIDTH - 1 downto 0 => '0') & input_data_buf(DATA_WIDTH*PARALLEL_SIGNAL_COUNT - 1 downto DATA_WIDTH);
		output_data <= input_data_buf(DATA_WIDTH - 1 downto 0);
	end generate;


end axis_parallel_to_serial_arc;