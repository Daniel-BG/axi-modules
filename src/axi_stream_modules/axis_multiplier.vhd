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
		DATA_WIDTH_0: integer := 20;
		DATA_WIDTH_1: integer := 20;
		OUTPUT_WIDTH: integer := 32;
		SIGN_EXTEND_0	: boolean := true;
		SIGN_EXTEND_1	: boolean := true;
		SIGNED_OP		: boolean := true;
		LAST_POLICY		: am_last_policy_t := PASS_ZERO;
		USER_WIDTH		: integer := 1;
		USER_POLICY 	: am_last_policy_t := PASS_ZERO;
		DESIRED_STAGES  : integer := 3
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
		output_data		: out std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
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
	
	function max(X, Y: integer; SIGNED_OP: boolean)
		return integer is
	begin
		if X > Y then
			if SIGNED_OP then
				return X;
			else
				return X + 1; --need one extra to avoid sign bits
			end if;
		else
			if SIGNED_OP then
				return Y;
			else
				return Y + 1; --need one extra to avoid sign bits
			end if;
		end if;
	end max;
	
	constant MAX_INPUT_LEN: integer := max(DATA_WIDTH_0, DATA_WIDTH_1, SIGNED_OP);
	
	function to_closest_mult_size(X : integer)
              return integer is
	begin
	  if X <= 18 then
		return 18;
	  elsif X <= 25 then
		return 25;
	  else
	  	report "Size out of max bounds" severity error;
	  	return 0;
	  end if;
	end to_closest_mult_size;

	
	constant INNER_DATA_WIDTH: integer := to_closest_mult_size(MAX_INPUT_LEN);
	signal final_input_0, final_input_1: std_logic_vector(INNER_DATA_WIDTH - 1 downto 0);
	
	signal final_output: std_logic_vector(INNER_DATA_WIDTH*2 - 1 downto 0);
begin

	data_joiner: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => DATA_WIDTH_0,
			DATA_WIDTH_1 => DATA_WIDTH_1,
			LAST_POLICY  => LAST_POLICY,
			USER_WIDTH   => USER_WIDTH,
			USER_POLICY  => USER_POLICY
		)
		port map (
			clk => clk, rst => rst,
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
	
	input_0_zero_extend: if not SIGN_EXTEND_0 generate
		final_input_0 <= std_logic_vector(resize(unsigned(joint_data_0), INNER_DATA_WIDTH));
	end generate;
	input_0_sign_extend: if SIGN_EXTEND_0 generate
		final_input_0 <= std_logic_vector(resize(signed(joint_data_0), INNER_DATA_WIDTH));
	end generate;
	input_1_zero_extend: if not SIGN_EXTEND_1 generate
		final_input_1 <= std_logic_vector(resize(unsigned(joint_data_1), INNER_DATA_WIDTH));
	end generate;
	input_1_sign_extend: if SIGN_EXTEND_1 generate
		final_input_1 <= std_logic_vector(resize(signed(joint_data_1), INNER_DATA_WIDTH));
	end generate;
	
	gen_signed: if SIGNED_OP generate
		output_data   <= std_logic_vector(resize(signed(final_output), OUTPUT_WIDTH));
	end generate;
	gen_unsigned: if not SIGNED_OP generate
		output_data   <= std_logic_vector(resize(unsigned(final_output), OUTPUT_WIDTH));
	end generate;
	 

	--use only 1 dsp block
	gen_lesseq_18x18: if MAX_INPUT_LEN <= 18 generate
		mult_18x18: entity work.AXIS_MULT_COMPONENT_18x18
			generic map (
				USER_WIDTH => USER_WIDTH,
				DESIRED_STAGES => DESIRED_STAGES
			)
			port map (
				clk => clk, rst => rst,
				input_a => final_input_0,
				input_b => final_input_1,
				input_valid => joint_valid,
				input_ready => joint_ready,
				input_last  => joint_last,
				input_user  => joint_user,
				output_data => final_output,
				output_valid => output_valid,
				output_ready => output_ready,
				output_last => output_last,
				output_user => output_user
			);
	end generate;
	
	--use only 2 dsp blocks
	gen_lesseq_25x25: if MAX_INPUT_LEN > 18 and MAX_INPUT_LEN <= 25 generate
		mult_25x25: entity work.AXIS_MULT_COMPONENT_25x25
			generic map (
				USER_WIDTH => USER_WIDTH,
				DESIRED_STAGES => DESIRED_STAGES
			)
			port map (
				clk => clk, rst => rst,
				input_a => final_input_0,
				input_b => final_input_1,
				input_valid => joint_valid,
				input_ready => joint_ready,
				input_last  => joint_last,
				input_user  => joint_user,
				output_data => final_output,
				output_valid => output_valid,
				output_ready => output_ready,
				output_last => output_last,
				output_user => output_user
			);
	end generate;
	
	
		
		
end Behavioral;
