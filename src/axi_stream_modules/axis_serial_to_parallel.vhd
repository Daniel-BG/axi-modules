----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    SERIAL_TO_PARALLEL - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Transform a serial input AXI stream into a parallel one.
--		Last signal flushes buffer and is propagated along with user signal.
--		Otherwise both are ignored
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

entity AXIS_SERIAL_TO_PARALLEL is
	generic (
		DATA_WIDTH				:	integer := 16;
		PARALLEL_SIGNAL_COUNT	: 	integer := 8;
		USER_WIDTH				:	integer := 1;
		START_MSB				:	boolean := true --where to start buffering the input data
	);
	port (
		clk, rst : in std_logic;
		input_ready	: out	std_logic;
		input_valid	: in 	std_logic;
		input_data	: in 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last	: in 	std_logic := '0';
		input_user	: in 	std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in 	std_logic;
		output_valid: out 	std_logic;
		output_data	: out 	std_logic_vector(DATA_WIDTH*PARALLEL_SIGNAL_COUNT - 1 downto 0);
		output_strb : out   std_logic_vector(PARALLEL_SIGNAL_COUNT - 1 downto 0);
		output_last : out 	std_logic;
		output_user	: out 	std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_SERIAL_TO_PARALLEL;

architecture axis_serial_to_parallel_arc of AXIS_SERIAL_TO_PARALLEL is
	type serial_to_parallel_state_t is (RESET, IDLE, BUFFERING, SENDING);
	signal state_curr, state_next: serial_to_parallel_state_t;

	--we always input from right to left, and then we can reorder the signals if needed
	signal output_data_buffer, output_data_buffer_next, output_data_buffer_shifted: std_logic_vector(DATA_WIDTH*PARALLEL_SIGNAL_COUNT - 1 downto 0);
	signal output_last_buffer, output_last_buffer_next: std_logic;
	signal output_user_buffer, output_user_buffer_next: std_logic_vector(USER_WIDTH - 1 downto 0);
	signal output_buffer_occ, output_buffer_occ_next: std_logic_vector(PARALLEL_SIGNAL_COUNT - 1 downto 0);

begin

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= RESET;
			else
				state_curr <= state_next;
				output_data_buffer <= output_data_buffer_next;
				output_last_buffer <= output_last_buffer_next;
				output_user_buffer <= output_user_buffer_next;
				output_buffer_occ  <= output_buffer_occ_next;
			end if;
		end if;
	end process;


	comb: process(
		state_curr, 
		output_data_buffer, output_last_buffer, output_user_buffer, output_buffer_occ, output_data_buffer_shifted, 
		input_last, input_user, output_ready, input_valid)
	begin

		input_ready		<= '0';
		output_valid	<= '0';
		state_next 		<= state_curr;

		output_data_buffer_next <= output_data_buffer;
		output_last_buffer_next <= output_last_buffer;
		output_user_buffer_next <= output_user_buffer;
		output_buffer_occ_next  <= output_buffer_occ;

		if state_curr = RESET then
			state_next <= IDLE;
		elsif state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				output_data_buffer_next <= output_data_buffer_shifted;
				output_buffer_occ_next  <= std_logic_vector(to_unsigned(1, PARALLEL_SIGNAL_COUNT));
				output_last_buffer_next <= input_last;
				output_user_buffer_next <= input_user;
				if input_last = '1' then
					--we end the serial to parallel stream
					state_next <= SENDING;
				else
					--we still have more data to receive
					state_next <= BUFFERING;
				end if;
			end if;
		elsif state_curr = BUFFERING then
			input_ready <= '1';
			if input_valid = '1' then
				output_data_buffer_next <= output_data_buffer_shifted;
				output_buffer_occ_next  <= output_buffer_occ(PARALLEL_SIGNAL_COUNT - 2 downto 0) & '1';
				output_last_buffer_next <= input_last;
				output_user_buffer_next <= input_user;
				if input_last = '1' then
					state_next <= SENDING;
				elsif output_buffer_occ = std_logic_vector(to_unsigned(2**(PARALLEL_SIGNAL_COUNT-1)-1, PARALLEL_SIGNAL_COUNT)) then
					--this fills up the buffer
					state_next <= SENDING;
				end if;
			end if;
		elsif state_curr = SENDING then
			output_valid <= '1';
			if output_ready = '1' then
				input_ready <= '1';
				if input_valid = '1' then
					--pass-through to process 1 per cycle
					output_data_buffer_next <= output_data_buffer_shifted;
					output_buffer_occ_next  <= std_logic_vector(to_unsigned(1, PARALLEL_SIGNAL_COUNT));
					output_last_buffer_next <= input_last;
					output_user_buffer_next <= input_user;
					if input_last = '1' then
						--we end the serial to parallel stream
						state_next <= SENDING;
					else
						--we still have more data to receive
						state_next <= BUFFERING;
					end if;
				else
					state_next <= IDLE;
				end if;
				
			end if;
		end if;
	end process;

	output_data_buffer_shifted <= output_data_buffer(DATA_WIDTH*(PARALLEL_SIGNAL_COUNT-1) - 1 downto 0) & input_data;


	--GENERATE OUTPUTS

	output_last <= output_last_buffer;
	output_user <= output_user_buffer;

	--conditionally assign or flip inner results depending on if we want MSB or LSB ordering
	gen_msb_ordering: if START_MSB generate
		output_data <= output_data_buffer;
		output_strb <= output_buffer_occ;
	end generate;

	gen_lsb_ordering: if not START_MSB generate
		get_loop: for i in 0 to PARALLEL_SIGNAL_COUNT - 1 generate
			output_data(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i) <= output_data_buffer(DATA_WIDTH*(PARALLEL_SIGNAL_COUNT - i) - 1 downto DATA_WIDTH*(PARALLEL_SIGNAL_COUNT - 1 - i));
			output_strb(i) <= output_buffer_occ(PARALLEL_SIGNAL_COUNT - 1 - i);
		end generate;
	end generate;
	

end axis_serial_to_parallel_arc;