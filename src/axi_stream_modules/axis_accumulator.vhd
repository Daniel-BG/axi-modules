----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel B�scones
-- 
-- Create Date: 12.02.2019 15:39:07
-- Design Name: 
-- Module Name: AXIS_ACCUMULATOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: An AXI_STREAM accumulator. Starting at zero, it adds values (either
-- 		in a signed or unsigned way) to an internal accumulator. As soon as the tlast
-- 		input goes high, it adds the last value that comes in input_data, and the next 
-- 		cycle it is ready to go in the output. After that value is read, the accumulator
--		restarts. Make sure to leave enough margin between the DATA_WIDTH and the 
--		ACCUMULATOR_WIDTH to not cause overflow, since that is not checked by the module
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.am_functions.all;

entity AXIS_ACCUMULATOR is
	Generic (
		DATA_WIDTH			: integer := 36;
		MAX_COUNT_LOG		: integer := 8;
		IS_SIGNED			: boolean := true
	);
	Port (
		clk, rst		: in  std_logic;
		input_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid		: in  std_logic;
		input_ready		: out std_logic;
		input_last		: in  std_logic;
		input_last_pt	: in  std_logic := '0';
		output_data		: out std_logic_vector(MAX_COUNT_LOG+ DATA_WIDTH - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_last_pt	: out std_logic
	);
end AXIS_ACCUMULATOR;

architecture Behavioral of AXIS_ACCUMULATOR is
	--counter signals
	type acc_state_t is (READING, OUTPUTTING);
	signal acc_state_curr, acc_state_next: acc_state_t;

	--last_pt signals
	signal last_buf, last_buf_next: std_logic;
	
	constant ACCUMULATOR_WIDTH: integer := DATA_WIDTH + MAX_COUNT_LOG;
	signal accumulator, accumulator_next, accumulator_plus_input: std_logic_vector(ACCUMULATOR_WIDTH - 1 downto 0);

	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	assert MAX_COUNT_LOG>= 2 report "Max count should be greater or equal than 2" severity error; 

	gen_acc_plus_signed: if IS_SIGNED generate
		accumulator_plus_input <= std_logic_vector(signed(accumulator) + resize(signed(input_data), ACCUMULATOR_WIDTH));
	end generate;
	gen_acc_plus_unsigned: if not IS_SIGNED generate
		accumulator_plus_input <= std_logic_vector(unsigned(accumulator) + resize(unsigned(input_data), ACCUMULATOR_WIDTH));
	end generate;
	
	seq: process(clk, inner_reset)
	begin
		if rising_edge(clk) then
			if inner_reset = '1' then
				acc_state_curr <= READING;
				accumulator <= (others => '0');
				last_buf <= '0';
			else 
				acc_state_curr <= acc_state_next;
				accumulator <= accumulator_next;
				last_buf <= last_buf_next;
			end if;
		end if;
	end process;
	
	comb: process(acc_state_curr, accumulator, accumulator_plus_input, output_ready, input_valid, input_last, input_last_pt)
	begin
		acc_state_next <= acc_state_curr;
		accumulator_next <= accumulator;
		input_ready <= '0';
		output_valid <= '0';
		last_buf_next <= '0';
	
		if acc_state_curr = READING then
			input_ready <= '1';
			if input_valid = '1' then
				accumulator_next <= accumulator_plus_input;
				last_buf_next <= input_last_pt;
				if input_last = '1' then
					acc_state_next <= OUTPUTTING;
				end if;
			end if; 
		elsif acc_state_curr = OUTPUTTING then
			output_valid <= '1';
			if output_ready = '1' then
				accumulator_next <= (others => '0');
				acc_state_next <= READING;
			end if;
		end if;
	end process;
	
	output_data <= accumulator;
	output_last_pt <= last_buf;
	
	
end Behavioral;
