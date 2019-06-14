----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.03.2019 09:54:32
-- Design Name: 
-- Module Name: axis_data_latch - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Latches data flow but NOT control flow. Whenever a control latch is
--		required, a latched_connection or FIFO is required (with more than 1 layer
--		to keep data flow steady)
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
use IEEE.NUMERIC_STD.ALL;

entity AXIS_DATA_LATCH is
	Generic (
		DATA_WIDTH: positive := 26;
		USER_WIDTH: integer := 1
	);
	Port ( 
		clk, rst: in std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_ready : out std_logic;
		input_valid : in  std_logic;
		input_last  : in  std_logic := '0';
		input_user 	: in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_DATA_LATCH;

architecture Behavioral of AXIS_DATA_LATCH is
	signal buf: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal buf_full: std_logic;

	signal buf_last: std_logic;
	signal buf_user: std_logic_vector(USER_WIDTH - 1 downto 0);
begin

	input_ready <= '1' when buf_full = '0' or output_ready = '1' else '0';
	output_valid <= buf_full;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf_full <= '0';
			else
				if output_ready = '1' or buf_full = '0' then
					buf <= input_data;
					buf_full <= input_valid;
					buf_last <= input_last;
					buf_user <= input_user;
				end if;
			end if;
		end if;
	end process;

	output_data <= buf;
	output_last <= buf_last;
	output_user <= buf_user;

end Behavioral;
