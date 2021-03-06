----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.03.2021 10:11:28
-- Design Name: 
-- Module Name: axis_conditioned_selector - Behavioral
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
use work.ccsds_data_structures.all;

entity axis_conditioned_selector is
	generic (
		DATA_WIDTH: integer := 16;
		USER_WIDTH: integer := 1
	);
	port ( 
		clk, rst: in std_logic;
		axis_in_cond: in std_logic; 
		axis_in_cond_valid: in std_logic;
		axis_in_cond_ready: out std_logic;
		axis_in_cond_user: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_in_data_0_d: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_data_0_valid: in std_logic;
		axis_in_data_0_ready: out std_logic;
		axis_in_data_1_d: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_data_1_valid: in std_logic;
		axis_in_data_1_ready: out std_logic;
		axis_out_data_d: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_out_data_valid: out std_logic;
		axis_out_data_ready: in std_logic;
		axis_out_data_user: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_conditioned_selector;

architecture Behavioral of axis_conditioned_selector is

	type state_t is (RESET, IDLE, COORD_READ);
	signal state_curr, state_next: state_t;
	
	signal saved_cond, saved_cond_next: std_logic;
	signal saved_user, saved_user_next: std_logic_vector(USER_WIDTH - 1 downto 0);

	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	seq: process(clk, inner_reset)
	begin
		if rising_edge(clk) then
			if inner_reset = '1' then
				state_curr <= RESET;
				saved_cond <= '0';
				saved_user <= (others => '0');
			else
				state_curr <= state_next;
				saved_cond <= saved_cond_next;
				saved_user <= saved_user_next;
			end if;
		end if;
	end process;
	
	axis_out_data_user <= saved_user;
	
	comb: process(state_curr, saved_cond, saved_user, axis_in_cond_valid, axis_out_data_ready, axis_in_data_0_d, axis_in_data_1_d, axis_in_data_0_valid, axis_in_data_1_valid, axis_in_cond,
		axis_in_cond_user) 
	begin
		state_next <= state_curr;	
		saved_cond_next <= saved_cond;
		saved_user_next <= saved_user;
		axis_out_data_valid <= '0';
		axis_out_data_d <= (others => '0');
		axis_in_data_0_ready <= '0';
		axis_in_data_1_ready <= '0';
		axis_in_cond_ready <= '0';	

		if state_curr = RESET then		
			state_next <= IDLE;
		elsif state_curr = IDLE then
			axis_in_cond_ready <= '1';
			if axis_in_cond_valid = '1' then
				state_next <= COORD_READ;
				saved_cond_next <= axis_in_cond;
				saved_user_next <= axis_in_cond_user;
			end if;
		elsif state_curr = COORD_READ then
			if saved_cond = '0' then --pipe first axis
				axis_out_data_valid 	<= axis_in_data_0_valid;
				axis_in_data_0_ready    <= axis_out_data_ready;
				axis_out_data_d 		<= axis_in_data_0_d;
				if (axis_in_data_0_valid = '1' and axis_out_data_ready = '1') then
					axis_in_cond_ready <= '1';
					if axis_in_cond_valid = '1' then
						state_next <= COORD_READ;
						saved_cond_next <= axis_in_cond;
						saved_user_next <= axis_in_cond_user;
					else
						state_next <= IDLE;
					end if;
				end if;
			else --pipe the other one
				axis_out_data_valid 	<= axis_in_data_1_valid;
				axis_in_data_1_ready    <= axis_out_data_ready;
				axis_out_data_d 		<= axis_in_data_1_d;
				if (axis_in_data_1_valid = '1' and axis_out_data_ready = '1') then
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
