----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.04.2021 09:09:55
-- Design Name: 
-- Module Name: axis_width_converter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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

entity axis_width_converter is
	generic (
		INPUT_DATA_WIDTH		:	integer := 16;
		OUTPUT_DATA_WIDTH		: 	integer := 8;
		USER_WIDTH				:	integer := 1;
		START_MSB				:	boolean := true
	);
	port (
		clk, rst : in std_logic;
		input_ready	: out	std_logic;
		input_valid	: in 	std_logic;
		input_data	: in 	std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
		input_last	: in 	std_logic := '0';
		input_user	: in 	std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in 	std_logic;
		output_valid: out 	std_logic;
		output_data	: out 	std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
		output_last : out 	std_logic;
		output_user	: out 	std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_width_converter;

architecture Behavioral of axis_width_converter is

begin
	assert (INPUT_DATA_WIDTH = OUTPUT_DATA_WIDTH) or
		   ((INPUT_DATA_WIDTH > OUTPUT_DATA_WIDTH) and (INPUT_DATA_WIDTH mod OUTPUT_DATA_WIDTH = 0)) or
		   ((INPUT_DATA_WIDTH < OUTPUT_DATA_WIDTH) and (OUTPUT_DATA_WIDTH mod INPUT_DATA_WIDTH = 0)) 
		   report "Conversion is only valid between streams which data width is a multiple of the other"
		   severity failure;
		   
	gen_direct_stream: if INPUT_DATA_WIDTH = OUTPUT_DATA_WIDTH generate
		output_valid 	<= input_valid;
		output_data 	<= input_data;
		output_last 	<= input_last;
		output_user 	<= input_user;
		input_ready 	<= output_ready;
	end generate;

	gen_shrinking_stream: if INPUT_DATA_WIDTH > OUTPUT_DATA_WIDTH generate
		parallel_to_serial: entity work.axis_parallel_to_serial 
			generic map (
				DATA_WIDTH				=> OUTPUT_DATA_WIDTH,
				PARALLEL_SIGNAL_COUNT	=> INPUT_DATA_WIDTH / OUTPUT_DATA_WIDTH,
				USER_WIDTH				=> USER_WIDTH,
				START_MSB				=> START_MSB
			)
			port map (
				clk => clk, rst => rst,
				input_ready	=> input_ready,
				input_valid	=> input_valid,
				input_data	=> input_data,
				input_last	=> input_last,
				input_user	=> input_user,
				output_ready=> output_ready,
				output_valid=> output_valid,
				output_data	=> output_data,
				output_last => output_last,
				output_user	=> output_user
			);		
	end generate;
	
	gen_expanding_stream: if INPUT_DATA_WIDTH < OUTPUT_DATA_WIDTH generate
		serial_to_parallel: entity work.axis_serial_to_parallel 
			generic map (
				DATA_WIDTH				=> INPUT_DATA_WIDTH,
				PARALLEL_SIGNAL_COUNT	=> OUTPUT_DATA_WIDTH / INPUT_DATA_WIDTH,
				USER_WIDTH				=> USER_WIDTH,
				START_MSB				=> START_MSB
			)
			port map (
				clk => clk, rst => rst,
				input_ready	=> input_ready,
				input_valid	=> input_valid,
				input_data	=> input_data,
				input_last	=> input_last,
				input_user	=> input_user,
				output_ready=> output_ready,
				output_valid=> output_valid,
				output_data	=> output_data,
				output_last => output_last,
				output_user	=> output_user
			);		
	end generate;

end Behavioral;
