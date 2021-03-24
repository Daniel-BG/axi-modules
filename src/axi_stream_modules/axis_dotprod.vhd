----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.03.2021 14:01:24
-- Design Name: 
-- Module Name: axis_dotprod - Behavioral
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
use work.am_data_types.all;

entity axis_dotprod is
	generic (
		VECTOR_LENGTH: integer := 6;
		VECTOR_LENGTH_LOG: integer := 3;
		INPUT_A_DATA_WIDTH: integer := 19;
		INPUT_B_DATA_WIDTH: integer := 16;
		LAST_POLICY		: am_last_policy_t := PASS_ZERO;
		USER_WIDTH		: integer := 1;
		USER_POLICY 	: am_last_policy_t := PASS_ZERO
	);
	port ( 
		clk, rst: in std_logic;
		axis_input_a_d: in std_logic_vector(INPUT_A_DATA_WIDTH*VECTOR_LENGTH-1 downto 0);
		axis_input_a_ready: out std_logic;
		axis_input_a_valid: in std_logic;
		axis_input_a_last: in std_logic := '0';
		axis_input_a_user: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_input_b_d: in std_logic_vector(INPUT_B_DATA_WIDTH*VECTOR_LENGTH-1 downto 0);
		axis_input_b_ready: out std_logic;
		axis_input_b_valid: in std_logic;
		axis_input_b_last: in std_logic := '0';
		axis_input_b_user: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_output_d: out std_logic_vector(INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH+VECTOR_LENGTH_LOG - 1 downto 0);
		axis_output_ready: in std_logic;
		axis_output_valid: out std_logic;
		axis_output_last: out std_logic;
		axis_output_user: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_dotprod;

architecture Behavioral of axis_dotprod is
	
	signal input_a_readys, input_b_readys: std_logic_vector(VECTOR_LENGTH - 1 downto 0);
	
	signal axis_mult_out_d: std_logic_vector((INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH)*VECTOR_LENGTH-1 downto 0);
	signal axis_mult_out_ready, axis_mult_out_valid, axis_mult_out_last: std_logic_vector(VECTOR_LENGTH - 1 downto 0);
	type mult_out_user_arr_t is array(0 to VECTOR_LENGTH - 1) of std_logic_vector(USER_WIDTH - 1 downto 0);
	signal axis_mult_out_user: mult_out_user_arr_t;
	
	signal axis_latched_d: std_logic_vector(INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH+VECTOR_LENGTH_LOG - 1 downto 0);
	signal axis_latched_last, axis_latched_ready, axis_latched_valid: std_logic;
	signal axis_latched_user: std_logic_vector(USER_WIDTH - 1 downto 0);
begin

	--generate multipliers
	--take first as sync module since the rest are synchronized
	axis_input_a_ready <= input_a_readys(0);
	axis_input_b_ready <= input_b_readys(0);
	gen_multipliers: for i in 0 to VECTOR_LENGTH-1 generate
		mult_i: entity work.AXIS_MULTIPLIER
			generic map (
				DATA_WIDTH_0 => INPUT_A_DATA_WIDTH,
				DATA_WIDTH_1 => INPUT_B_DATA_WIDTH,
				SIGNED_0=> true,
				SIGNED_1=> true,
				LAST_POLICY  => LAST_POLICY,
				USER_POLICY  => USER_POLICY,
				USER_WIDTH   => USER_WIDTH,
				STAGES_AFTER_SYNC => 3
			)
			port map(
				clk => clk, rst => rst,
				input_0_data	=> axis_input_a_d(INPUT_A_DATA_WIDTH*(i+1) - 1 downto INPUT_A_DATA_WIDTH*i),
				input_0_valid	=> axis_input_a_valid,
				input_0_ready	=> input_a_readys(i),
				input_0_last    => axis_input_a_last,
				input_0_user    => axis_input_a_user,
				input_1_data	=> axis_input_b_d(INPUT_B_DATA_WIDTH*(i+1) - 1 downto INPUT_B_DATA_WIDTH*i),
				input_1_valid	=> axis_input_b_valid,
				input_1_ready	=> input_b_readys(i),
				input_1_last    => axis_input_b_last,
				input_1_user    => axis_input_b_user,
				output_data		=> axis_mult_out_d((INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH)*(i+1)-1 downto (INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH)*i),
				output_valid	=> axis_mult_out_valid(i),
				output_ready	=> axis_mult_out_ready(i),
				output_last		=> axis_mult_out_last(i),
				output_user 	=> axis_mult_out_user(i)
			);
	end generate;
	
	
	reductor: entity work.axis_treered_sum 
		generic map (
			DATA_WIDTH => INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH,
			VECTOR_LENGTH => VECTOR_LENGTH,
			VECTOR_LENGTH_LOG => VECTOR_LENGTH_LOG
		)
		Port map( 
			axis_in_d => axis_mult_out_d,
			axis_out_d => axis_latched_d
		);

	axis_latched_valid <= axis_mult_out_valid(0);
	axis_latched_last  <= axis_mult_out_last(0);
	axis_latched_user  <= axis_mult_out_user(0);
	axis_mult_out_ready <= (others => '1') when axis_latched_ready = '1' else (others => '0');


	output_latch: entity work.AXIS_DATA_LATCH
		generic map (
			DATA_WIDTH => INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH+VECTOR_LENGTH_LOG,
			USER_WIDTH   => USER_WIDTH
		)
		port map ( 
			clk => clk, rst => rst,
			input_data	=> axis_latched_d,
			input_ready => axis_latched_ready,
			input_valid => axis_latched_valid,
			input_last  => axis_latched_last,
			input_user  => axis_latched_user,
			output_data	=> axis_output_d,
			output_ready=> axis_output_ready,
			output_valid=> axis_output_valid,
			output_last => axis_output_last,
			output_user => axis_output_user
		);

end Behavioral;
