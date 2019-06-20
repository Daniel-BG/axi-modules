----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.06.2019 15:20:42
-- Design Name: 
-- Module Name: axis_fifo_swrap - Behavioral
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

entity AXIS_FIFO_SWRAP is
	Generic (
		DATA_WIDTH: positive := 16;
		FIFO_DEPTH: positive := 360*1000; --greater than 2!! (otherwise use other AXIS LINKS)
		ALMOST_FULL_THRESHOLD	: positive := 128;
		ALMOST_EMPTY_THRESHOLD	: positive := 128;
		USER_WIDTH: positive := 1
	);
	Port ( 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		--input axi port
		input_valid		: in  STD_LOGIC;
		input_ready		: out STD_LOGIC;
		input_data		: in  STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		input_last		: in  STD_LOGIC := '0';
		input_user		: in  STD_LOGIC_VECTOR(USER_WIDTH - 1 downto 0) := (others => '0');
		--out axi port
		output_ready	: in  STD_LOGIC;
		output_data		: out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_valid	: out STD_LOGIC;
		output_last		: out STD_LOGIC;
		output_user		: out STD_LOGIC_VECTOR(USER_WIDTH - 1 downto 0);
		--output flags
		flag_almost_full	: out std_logic;
		flag_almost_empty	: out std_logic
	);
end AXIS_FIFO_SWRAP;

architecture Behavioral of AXIS_FIFO_SWRAP is
	--user & last & data
	signal inner_fifo_input, inner_fifo_output: std_logic_vector(USER_WIDTH + 1 + DATA_WIDTH - 1 downto 0);
begin

	inner_fifo_input <= input_user & input_last & input_data;

	inner_fifo: entity work.AXIS_FIFO 
	Generic map (
		DATA_WIDTH => DATA_WIDTH + 1 + USER_WIDTH,
		FIFO_DEPTH => FIFO_DEPTH,
		ALMOST_FULL_THRESHOLD	=> ALMOST_FULL_THRESHOLD,
		ALMOST_EMPTY_THRESHOLD	=> ALMOST_EMPTY_THRESHOLD
	)
	Port map ( 
		clk		=> clk,
		rst		=> rst,
		input_valid		=> input_valid,
		input_ready		=> input_ready,
		input_data		=> inner_fifo_input,
		output_ready	=> output_ready,
		output_data		=> inner_fifo_output,
		output_valid	=> output_valid,
		flag_almost_full	=> flag_almost_full,
		flag_almost_empty	=> flag_almost_empty
	);
	
	output_user <= inner_fifo_output(USER_WIDTH + 1 + DATA_WIDTH - 1 downto 1 + DATA_WIDTH);
	output_last <= inner_fifo_output(DATA_WIDTH);
	output_data <= inner_fifo_output(DATA_WIDTH - 1 downto 0); 

end Behavioral;
