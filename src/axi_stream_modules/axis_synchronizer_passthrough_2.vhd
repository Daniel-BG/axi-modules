----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 19:01:39
-- Design Name: 
-- Module Name: AXIS_SYNCHRONIZER_PASSTHROUGH_2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Synchronize two axis streams into only one. Data outputs are kept separate for ease of use
--		this passthrough version does not latch control signals but reduces the registers from 2 to 1.
-- 		use this when the critical path for control signals is short so you can save registers 
--
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.am_data_types.all;

entity AXIS_SYNCHRONIZER_PASSTHROUGH_2 is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32;
		LAST_POLICY: am_last_policy_t := PASS_ZERO;
		USER_WIDTH: integer := 1;
		USER_POLICY: am_last_policy_t := PASS_ZERO
	);
	Port (
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid: in  std_logic;
		input_0_ready: out std_logic;
		input_0_data : in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_0_last : in  std_logic;
		input_0_user : in  std_logic_vector(USER_WIDTH - 1 downto 0);
		input_1_valid: in  std_logic;
		input_1_ready: out std_logic; 
		input_1_data : in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		input_1_last : in  std_logic;
		input_1_user : in  std_logic_vector(USER_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_data_0	: out std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		output_data_1	: out std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		output_last_0	: out std_logic;
		output_last_1	: out std_logic;
		output_user_0 	: out std_logic_vector(USER_WIDTH - 1 downto 0);
		output_user_1 	: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_SYNCHRONIZER_PASSTHROUGH_2;

architecture Behavioral of AXIS_SYNCHRONIZER_PASSTHROUGH_2 is
	signal buf_0_full, buf_1_full: std_logic;
	signal buf_0: std_logic_vector(DATA_WIDTH_0 - 1 downto 0); 
	signal buf_1: std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
	signal buf_0_last, buf_1_last: std_logic;
	signal buf_0_user, buf_1_user: std_logic_vector(USER_WIDTH - 1 downto 0);
	
	signal input_0_ready_in, input_1_ready_in: std_logic;
	signal output_valid_in: std_logic;
begin

	input_0_ready_in <= '1' when buf_0_full = '0' or (output_ready = '1' and buf_1_full = '1') else '0';
	input_1_ready_in <= '1' when buf_1_full = '0' or (output_ready = '1' and buf_0_full = '1') else '0';
	input_0_ready <= input_0_ready_in;
	input_1_ready <= input_1_ready_in;
	
	output_valid_in <= '1' when buf_0_full = '1' and buf_1_full = '1' else '0';
	output_valid <= output_valid_in;
	
	output_data_0 <= buf_0;
	output_data_1 <= buf_1;
	output_last_0 <= buf_0_last;
	output_last_1 <= buf_1_last;
	output_user_0 <= buf_0_user;
	output_user_1 <= buf_1_user;

	seq: process(clk, rst) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf_0_full <= '0';
				buf_1_full <= '0';
				buf_0 <= (others => '0');
				buf_1 <= (others => '0');
				buf_0_last <= '0';
				buf_1_last <= '0';
				buf_0_user <= (others => '0');
				buf_1_user <= (others => '0');
			else
				if input_0_ready_in = '1' and input_0_valid = '1' then
					--writing to buffer
					buf_0 <= input_0_data;
					buf_0_last <= input_0_last;
					buf_0_user <= input_0_user;
					buf_0_full <= '1';
				elsif output_valid_in = '1' and output_ready = '1' then
					buf_0_full <= '0';
				end if;
				if input_1_ready_in = '1' and input_1_valid = '1' then
					--writing to output buffer
					buf_1_full <= '1';
					buf_1 <= input_1_data;
					buf_1_last <= input_1_last;
					buf_1_user <= input_1_user;
				elsif output_valid_in = '1' and output_ready = '1' then
					buf_1_full <= '0';
				end if;
			end if;
		end if;
	end process;
	
end Behavioral;
