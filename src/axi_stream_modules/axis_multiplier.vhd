----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:59:23
-- Design Name: 
-- Module Name: AXIS_MULTIPLIER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Multiplies two numbers together producing a result after some 
--		cycles (the exact number is dependant on the size of the inputs)
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
use work.am_data_types.all;

entity AXIS_MULTIPLIER is
	Generic (
		DATA_WIDTH_0		: integer := 38;
		DATA_WIDTH_1		: integer := 5;
		SIGNED_0			: boolean := true;
		SIGNED_1			: boolean := false;
		LAST_POLICY			: am_last_policy_t := PASS_ZERO;
		USER_WIDTH			: integer := 1;
		USER_POLICY 		: am_last_policy_t := PASS_ZERO;
		STAGES_AFTER_SYNC	: integer := 3
	);
	Port(
		clk, rst: in std_logic;
		input_0_data	: in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_0_valid	: in  std_logic;
		input_0_ready	: out std_logic;
		input_0_last	: in  std_logic := '0';
		input_0_user    : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		input_1_data	: in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		input_1_valid	: in  std_logic;
		input_1_ready	: out std_logic;
		input_1_last    : in  std_logic := '0';
		input_1_user    : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_data		: out std_logic_vector(DATA_WIDTH_0 + DATA_WIDTH_1 - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_last		: out std_logic;
		output_user		: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_MULTIPLIER;

architecture Behavioral of AXIS_MULTIPLIER is
	signal joint_valid, joint_ready: std_logic;
	signal joint_data_0: std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
	signal joint_data_1: std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
	signal joint_last: std_logic;
	signal joint_user: std_logic_vector(USER_WIDTH - 1 downto 0);
	
	type stage_user_t is array(0 to STAGES_AFTER_SYNC - 1) of std_logic_vector(USER_WIDTH - 1 downto 0);
	signal stage_occ, stage_last: std_logic_vector(STAGES_AFTER_SYNC - 1 downto 0);
	signal stage_user: stage_user_t;
	
	signal inner_mult_enable: std_logic;
	
	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	data_joiner: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => DATA_WIDTH_0,
			DATA_WIDTH_1 => DATA_WIDTH_1,
			LAST_POLICY  => LAST_POLICY,
			USER_WIDTH   => USER_WIDTH,
			USER_POLICY  => USER_POLICY
		)
		port map (
			clk => clk, rst => inner_reset,
			input_0_valid => input_0_valid,
			input_0_ready => input_0_ready,
			input_0_data  => input_0_data,
			input_0_last  => input_0_last,
			input_0_user  => input_0_user,
			input_1_valid => input_1_valid,
			input_1_ready => input_1_ready,
			input_1_data  => input_1_data,
			input_1_last  => input_1_last,
			input_1_user  => input_1_user,
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_data_0,
			output_data_1 => joint_data_1,
			output_last   => joint_last,
			output_user   => joint_user
		);
	
	
	inner_mult_enable <= '1' 
		when output_ready = '1' 			--if anyone is around to read, we can always enable multiplication 
		or   stage_occ(stage_occ'high) = '0'--we can also enable multiplication if the last stage isnt full
		else '0';
	joint_ready <= inner_mult_enable;
	
	seq: process(clk, inner_reset) 
	begin
		if rising_edge(clk) then
			if inner_reset = '1' then
				stage_occ <= (others => '0');
			else
				if inner_mult_enable = '1' then
					stage_occ <= stage_occ(stage_occ'high - 1 downto 0) & joint_valid;
					stage_last <= stage_last(stage_last'high - 1 downto 0) & joint_last;
					for i in 1 to STAGES_AFTER_SYNC - 1 loop
						stage_user(i) <= stage_user(i-1);
					end loop;
					stage_user(0) <= joint_user;
				end if;
			end if;
		end if;
	end process;
		
	inner_multiplier: entity work.generic_multiplier
		generic map (
			A_SIZE		=> DATA_WIDTH_0,
			B_SIZE		=> DATA_WIDTH_1,
			STAGES		=> STAGES_AFTER_SYNC,
			SIGNED_A	=> SIGNED_0,
			SIGNED_B 	=> SIGNED_1
		)
		Port map ( 
			clk => clk, 
			enable => inner_mult_enable,
			in_a => joint_data_0,
			in_b => joint_data_1,
			prod => output_data
		);
	output_valid	<= stage_occ(STAGES_AFTER_SYNC - 1);
	output_last		<= stage_last(STAGES_AFTER_SYNC - 1);
	output_user		<= stage_user(STAGES_AFTER_SYNC - 1);
		
		
end Behavioral;
