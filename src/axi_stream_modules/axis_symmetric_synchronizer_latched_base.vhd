----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 19:01:39
-- Design Name: 
-- Module Name: axis_synchronizer_latched_base - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Synchronize multiple axis streams into only one. 
--		Data outputs are kept separate for ease of use
--		Latches the control signals so that critical paths
--		can be reduced. This adds a layer of registers for data and
--		control, so the module is more expensive FF-wise
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

entity axis_symmetric_synchronizer_latched_base is
	Generic (
		DATA_WIDTH: integer := 32;
		INPUT_PORTS: integer := 4;
		USER_WIDTH: integer := 1
	);
	Port (
		clk, rst: in std_logic;
		--to input axi port
		input_valid: in  std_logic_vector(INPUT_PORTS - 1 downto 0);
		input_ready: out std_logic_vector(INPUT_PORTS - 1 downto 0);
		input_data : in  std_logic_vector(INPUT_PORTS*DATA_WIDTH - 1 downto 0);
		input_last : in  std_logic_vector(INPUT_PORTS - 1 downto 0);
		input_user : in  std_logic_vector(INPUT_PORTS*USER_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_data	    : out std_logic_vector(INPUT_PORTS*DATA_WIDTH - 1 downto 0);
		output_last		: out std_logic_vector(INPUT_PORTS - 1 downto 0);
		output_user 	: out std_logic_vector(INPUT_PORTS*USER_WIDTH - 1 downto 0)
	);
end axis_symmetric_synchronizer_latched_base;

architecture Behavioral of axis_symmetric_synchronizer_latched_base is
	signal buf_i_full: std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal buf_o_full: std_logic_vector(INPUT_PORTS - 1 downto 0);
	
	signal buf_i: std_logic_vector(DATA_WIDTH*INPUT_PORTS - 1 downto 0);
	signal buf_o: std_logic_vector(DATA_WIDTH*INPUT_PORTS - 1 downto 0);
	
	signal buf_i_last: std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal buf_o_last: std_logic_vector(INPUT_PORTS - 1 downto 0);
	
	signal buf_i_user: std_logic_vector(USER_WIDTH*INPUT_PORTS - 1 downto 0);
	signal buf_o_user: std_logic_vector(USER_WIDTH*INPUT_PORTS - 1 downto 0);
	
	signal input_ready_in: std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal output_valid_in: std_logic;
begin

	gen_input_ready: for i in 0 to INPUT_PORTS - 1 generate
		input_ready_in(i) <= '1' when buf_i_full(i) = '0' or buf_o_full(i) = '0' else '0';
		input_ready(i) <= input_ready_in(i);
	end generate;

	
	output_valid_in <= '1' when buf_o_full = (buf_o_full'range => '1') else '0';
	output_valid <= output_valid_in;
	
	gen_outputs: for i in 0 to INPUT_PORTS - 1 generate
		
	end generate;
	output_data <= buf_o;
	output_last <= buf_o_last;
	output_user <= buf_o_user;
	
	seq: process(clk) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf_i_full <= (others => '0');
				buf_o_full <= (others => '0');
				buf_i <= (others => '0');
				buf_o <= (others => '0');
				buf_i_last <= (others => '0');
				buf_o_last <= (others => '0');
				buf_o_user <= (others => '0');
				buf_i_user <= (others => '0');
			else
				--if reading from output
				if output_valid_in = '1' and output_ready = '1' then
					--shift input i
					gen_behavior_readinput: for i in 0 to INPUT_PORTS - 1 loop
						if input_ready_in(i) = '1' and input_valid(i) = '1' then
							buf_o(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i) <= input_data(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i);
							buf_o_last(i) <= input_last(i);
							buf_o_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i) <= input_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i);
							buf_o_full(i) <= '1';
						else --shift value
							buf_o(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i) <= buf_i(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i);
							buf_o_last(i) <= buf_i_last(i);
							buf_o_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i) <= buf_i_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i);
							buf_o_full(i) <= buf_i_full(i);
							buf_i_full(i) <= '0';
						end if;
					end loop;
				else --not reading from output
					gen_behavior_noreadinput: for i in 0 to INPUT_PORTS - 1 loop
						if input_ready_in(i) = '1' and input_valid(i) = '1' then
							if buf_o_full(i) = '0' then
								buf_o(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i) <= input_data(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i);
								buf_o_last(i) <= input_last(i);
								buf_o_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i) <= input_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i);
								buf_o_full(i) <= '1';
							else
								buf_i(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i) <= input_data(DATA_WIDTH*(i+1)-1 downto DATA_WIDTH*i);
								buf_i_last(i) <= input_last(i);
								buf_i_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i) <= input_user(USER_WIDTH*(i+1)-1 downto USER_WIDTH*i);
								buf_i_full(i) <= '1';
							end if;
						end if;
					end loop;
				end if;
			end if;
		end if;
	end process;
	
end Behavioral;
