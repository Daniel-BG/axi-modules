----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.03.2021 10:11:28
-- Design Name: 
-- Module Name: axis_conditioned_retrieval - Behavioral
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

entity axis_conditioned_retrieval is
	generic (
		DATA_WIDTH: integer := 16;
		USER_WIDTH: integer := 3
	);
	port ( 
		clk, rst: in std_logic;
		axis_in_cond: in std_logic; --output axis_in when cond = '1', otherwise output 0 for each 0 condition
		axis_in_cond_user: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_in_cond_valid: in std_logic;
		axis_in_cond_ready: out std_logic;
		axis_in_data_d: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_data_valid: in std_logic;
		axis_in_data_ready: out std_logic;
		axis_out_data_d: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_out_data_valid: out std_logic;
		axis_out_data_ready: in std_logic;
		axis_out_data_user: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_conditioned_retrieval;

architecture Behavioral of axis_conditioned_retrieval is

	type state_t is (IDLE, COORD_READ);
	signal state_curr, state_next: state_t;
	
	signal saved_cond, saved_cond_next: std_logic;
	signal saved_user, saved_user_next: std_logic_vector(USER_WIDTH - 1 downto 0);

begin

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				saved_cond <= '0';
				saved_user <= (others => '0');
			else
				state_curr <= state_next;
				saved_cond <= saved_cond_next;
				saved_user <= saved_user_next;
			end if;
		end if;
	end process;
	
	
	comb: process(state_curr, saved_cond, saved_user, axis_in_cond_valid, axis_in_cond_user, axis_out_data_ready, axis_in_data_d, axis_in_data_valid, axis_in_cond) 
	begin
		state_next <= state_curr;	
		saved_cond_next <= saved_cond;
		saved_user_next <= saved_user;
		axis_out_data_valid <= '0';
		axis_out_data_d <= (others => '0');
		axis_out_data_user <= (others => '0');
		axis_in_data_ready <= '0';
		axis_in_cond_ready <= '0';			
		
		if state_curr = IDLE then
			axis_in_cond_ready <= '1';
			if axis_in_cond_valid = '1' then
				state_next <= COORD_READ;
				saved_cond_next <= axis_in_cond;
				saved_user_next <= axis_in_cond_user;
			end if;
		elsif state_curr = COORD_READ then
			if saved_cond = '0' then
				--first line and sample, we output ZERO always, since we don't have the values in the queue
				axis_out_data_valid <= '1';
				axis_out_data_d <= (others => '0');
				axis_out_data_user <= saved_user;
				if axis_out_data_ready = '1' then
					axis_in_cond_ready <= '1';
					if axis_in_cond_valid = '1' then
						state_next <= COORD_READ;
						saved_cond_next <= axis_in_cond;
						saved_user_next <= axis_in_cond_user;
					else
						state_next <= IDLE;
					end if;
				end if;
			else
				--any other option, we pipe the input axis to the output axis
				axis_out_data_d <= axis_in_data_d;
				axis_out_data_user <= saved_user;
				axis_out_data_valid <= axis_in_data_valid;
				axis_in_data_ready <= axis_out_data_ready;
				if (axis_in_data_valid = '1' and axis_out_data_ready = '1') then
					axis_in_cond_ready <= '1';
					if axis_in_cond_valid = '1' then
						state_next <= COORD_READ;
						saved_cond_next <= axis_in_cond;
						saved_user_next <= axis_in_cond_user;
					else
						state_next <= IDLE;
					end if;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
