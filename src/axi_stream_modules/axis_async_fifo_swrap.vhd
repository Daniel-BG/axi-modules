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

entity AXIS_ASYNC_FIFO_SWRAP is
	Generic (
		DATA_WIDTH: positive := 16;
		FIFO_DEPTH_LOG: positive := 10; --greater than 2!! (otherwise use other AXIS LINKS)
		ALMOST_FULL_THRESHOLD	: positive := 128;
		ALMOST_EMPTY_THRESHOLD	: positive := 128;
		USER_WIDTH: positive := 1
	);
	Port ( 
		rst						: in  STD_LOGIC;
		--input ctrl signals
		axis_in_clk				: in  STD_LOGIC;
		--input axi port
		axis_in_valid			: in  STD_LOGIC;
		axis_in_ready			: out STD_LOGIC;
		axis_in_data			: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		axis_in_last			: in  STD_LOGIC;
		axis_in_user			: in  STD_LOGIC_VECTOR (USER_WIDTH - 1 downto 0);
		axis_in_almost_full		: out STD_LOGIC;
		axis_in_full			: out STD_LOGIC;
		--output ctrl signals
		axis_out_clk			: in  STD_LOGIC;
		--output axi port
		axis_out_ready			: in  STD_LOGIC;
		axis_out_data			: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		axis_out_last			: out STD_LOGIC;
		axis_out_user			: out STD_LOGIC_VECTOR (USER_WIDTH - 1 downto 0);
		axis_out_valid			: out STD_LOGIC;
		axis_out_almost_empty	: out STD_LOGIC;
		axis_out_empty			: out STD_LOGIC
	);
end AXIS_ASYNC_FIFO_SWRAP;

architecture Behavioral of AXIS_ASYNC_FIFO_SWRAP is
	--user & last & data
	signal inner_fifo_input, inner_fifo_output: std_logic_vector(USER_WIDTH + 1 + DATA_WIDTH - 1 downto 0);
begin

	inner_fifo_input <= axis_in_user & axis_in_last & axis_in_data;

	inner_fifo: entity work.AXIS_ASYNC_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1 + USER_WIDTH,
			FIFO_DEPTH_LOG => FIFO_DEPTH_LOG,
			ALMOST_FULL_THRESHOLD => ALMOST_FULL_THRESHOLD,
			ALMOST_EMPTY_THRESHOLD => ALMOST_EMPTY_THRESHOLD
		)
		Port map ( 
			--reset
			rst => rst,
			--input ctrl signals
			axis_in_clk				=> axis_in_clk,
			--input axi port
			axis_in_valid			=> axis_in_valid,
			axis_in_ready			=> axis_in_ready,
			axis_in_data			=> inner_fifo_input,
			axis_in_almost_full		=> axis_in_almost_full,
			axis_in_full			=> axis_in_full,
			--output ctrl signals
			axis_out_clk			=> axis_out_clk,
			--output axi port
			axis_out_ready			=> axis_out_ready,
			axis_out_data			=> inner_fifo_output,
			axis_out_valid			=> axis_out_valid,
			axis_out_almost_empty	=> axis_out_almost_empty,
			axis_out_empty			=> axis_out_empty
		);
	
	axis_out_user <= inner_fifo_output(USER_WIDTH + 1 + DATA_WIDTH - 1 downto 1 + DATA_WIDTH);
	axis_out_last <= inner_fifo_output(DATA_WIDTH);
	axis_out_data <= inner_fifo_output(DATA_WIDTH - 1 downto 0); 

end Behavioral;
