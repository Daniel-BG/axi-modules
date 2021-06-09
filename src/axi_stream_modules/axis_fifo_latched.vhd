----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.03.2021 11:38:09
-- Design Name: 
-- Module Name: axis_fifo_latched - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_fifo_latched is
	Generic (
		DATA_WIDTH: positive := 16;
		FIFO_DEPTH: positive := 360*1000; --greater than 2!! (otherwise use other AXIS LINKS)
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
		output_user		: out STD_LOGIC_VECTOR(USER_WIDTH - 1 downto 0)
	);
end axis_fifo_latched;

architecture Behavioral of axis_fifo_latched is
	signal latched_ready: STD_LOGIC;
	signal latched_data	: STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
	signal latched_valid: STD_LOGIC;
	signal latched_last	: STD_LOGIC;
	signal latched_user	: STD_LOGIC_VECTOR(USER_WIDTH - 1 downto 0);

	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	inner_fifo: entity work.AXIS_FIFO_SWRAP
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => FIFO_DEPTH,
			USER_WIDTH => USER_WIDTH
		)
		Port map ( 
			clk		=> clk,
			rst		=> inner_reset,
			--input axi port
			input_valid		=> input_valid,
			input_ready		=> input_ready,
			input_data		=> input_data,
			input_last		=> input_last,
			input_user		=> input_user,
			--out axi port
			output_ready	=> latched_ready,
			output_data		=> latched_data,
			output_valid	=> latched_valid,
			output_last		=> latched_last,
			output_user		=> latched_user
		);
		
	latch: entity work.AXIS_DATA_LATCH
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			USER_WIDTH => USER_WIDTH
		)
		Port map ( 
			clk		=> clk,
			rst		=> inner_reset,
			input_valid		=> latched_valid,
			input_ready		=> latched_ready,
			input_data		=> latched_data,
			input_last		=> latched_last,
			input_user		=> latched_user,
			output_ready	=> output_ready,
			output_data		=> output_data,
			output_valid	=> output_valid,
			output_last		=> output_last,
			output_user		=> output_user
		);
		
end Behavioral;
