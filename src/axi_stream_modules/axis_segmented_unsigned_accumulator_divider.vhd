----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04.03.2021 09:54:58
-- Design Name: 
-- Module Name: axis_segmented_divider - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
use work.am_data_types.all;

entity axis_segmented_unsigned_accumulator_divider is
	generic (
		SAMPLE_WIDTH: integer := 16;
		NUMBER_OF_SAMPLES_WIDTH: integer := 20;
		LAST_POLICY: am_last_policy_t := PASS_ZERO;
		USER_WIDTH: integer := 1;
		USER_POLICY: am_last_policy_t := PASS_ZERO
	);
	port ( 
		clk, rst: std_logic;
		axis_acc_data			: in std_logic_vector(SAMPLE_WIDTH + NUMBER_OF_SAMPLES_WIDTH - 1 downto 0);
		axis_acc_ready			: out std_logic;
		axis_acc_valid			: in std_logic;
		axis_acc_last			: in std_logic := '0';
		axis_acc_user			: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_nos_data			: in std_logic_vector(NUMBER_OF_SAMPLES_WIDTH - 1 downto 0);
		axis_nos_ready			: out std_logic;
		axis_nos_valid			: in std_logic;
		axis_nos_last			: in std_logic := '0';
		axis_nos_user			: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_output_quotient	: out std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
		axis_output_remainder	: out std_logic_vector(NUMBER_OF_SAMPLES_WIDTH - 1 downto 0);
		axis_output_ready 		: in std_logic;
		axis_output_valid 		: out std_logic;
		axis_output_last 		: out std_logic;
		axis_output_user 		: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_segmented_unsigned_accumulator_divider;

architecture Behavioral of axis_segmented_unsigned_accumulator_divider is

	constant ACC_WIDTH: integer := SAMPLE_WIDTH + NUMBER_OF_SAMPLES_WIDTH;

	signal joint_valid, joint_ready, joint_last: std_logic;
	signal joint_acc: std_logic_vector(ACC_WIDTH - 1 downto 0);
	signal joint_nos: std_logic_vector(NUMBER_OF_SAMPLES_WIDTH - 1 downto 0);
	signal joint_user: std_logic_vector(USER_WIDTH - 1 downto 0);
	
	constant STAGES: integer := SAMPLE_WIDTH;
	
	type acc_stages_t 		is array(0 to STAGES) of std_logic_vector(ACC_WIDTH - 1 downto 0);
	type nos_stages_t 		is array(0 to STAGES) of std_logic_vector(NUMBER_OF_SAMPLES_WIDTH - 1 downto 0);
	type quo_stages_t 		is array(0 to STAGES) of std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
	type stage_flag_t 		is array(0 to STAGES) of std_logic;
	type user_stages_t 		is array(0 to STAGES) of std_logic_vector(USER_WIDTH - 1 downto 0);
	signal acc_stages		: acc_stages_t;
	signal nos_stages		: nos_stages_t;
	signal quotient_stages  : quo_stages_t;
	signal stage_full		: stage_flag_t;
	signal stage_last 		: stage_flag_t;
	signal stage_user 		: user_stages_t;
	 
	signal pipeline_enable  : std_logic;

	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	
	pipeline_enable <= 
		'1' when stage_full(STAGES-1) = '0'
			 else
		'1' when axis_output_ready = '1'
			 else
		'0';
		
	joint_ready <= pipeline_enable;
	

	joint_signals: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => ACC_WIDTH,
			DATA_WIDTH_1 => NUMBER_OF_SAMPLES_WIDTH,
			LATCH => false,
			LAST_POLICY => LAST_POLICY,
			USER_WIDTH => USER_WIDTH,
			USER_POLICY => USER_POLICY
		)
		port map (
			clk => clk, rst => inner_reset,
			input_0_valid => axis_acc_valid,
			input_0_ready => axis_acc_ready,
			input_0_data  => axis_acc_data,
			input_0_last  => axis_acc_last,
			input_0_user  => axis_acc_user,
			input_1_valid => axis_nos_valid,
			input_1_ready => axis_nos_ready,
			input_1_data  => axis_nos_data,
			input_1_last  => axis_nos_last,
			input_1_user  => axis_nos_user,
			--to output axi ports
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_acc,
			output_data_1 => joint_nos,
			output_last   => joint_last,
			output_user   => joint_user
		);
	
	acc_stages(0) 		<= joint_acc;
	nos_stages(0) 		<= joint_nos;
	quotient_stages(0)  <= (others => '0');
	stage_full(0)		<= joint_valid;
	stage_last(0) 		<= joint_last;
	stage_user(0) 		<= joint_user;
	
	
	gen_stages: for i in 1 to STAGES generate
	begin
		register_stage_i: process(clk, inner_reset, pipeline_enable)
				variable stagequot: natural range 0 to 1;
				variable shifted_divisor: std_logic_vector(ACC_WIDTH - i downto 0)
					:= std_logic_vector(shift_left(resize(unsigned(nos_stages(i-1)), ACC_WIDTH + 1 - i), SAMPLE_WIDTH - i));
			begin
				if rising_edge(clk) then
					if inner_reset = '1' then
						stage_full(i) 	  	<= '0';
						--do not need to reset the other signals
						--save resources
					elsif pipeline_enable = '1' then
						if unsigned(acc_stages(i-1)) < unsigned(shifted_divisor) then --not substracting
							acc_stages(i)(ACC_WIDTH - 1 - i downto 0) <= acc_stages(i-1)(ACC_WIDTH - 1 - i downto 0); 
							stagequot := 0;
						else --substracting
							acc_stages(i)(ACC_WIDTH - 1 - i downto 0) <= std_logic_vector(resize(unsigned(acc_stages(i-1)) - resize(unsigned(shifted_divisor), ACC_WIDTH), ACC_WIDTH - i));
							stagequot := 1;
						end if;
						quotient_stages(i)(i - 1 downto 0) <= std_logic_vector(shift_left(resize(unsigned(quotient_stages(i-1)), i), 1) + stagequot);
						nos_stages(i) <= nos_stages(i-1); --keep same value
						stage_full(i) <= stage_full(i-1);
						stage_last(i) <= stage_last(i-1);
						stage_user(i) <= stage_user(i-1);
					end if;
				end if;
			end process;
	end generate;
	
	axis_output_valid	 	<= stage_full(STAGES);
	axis_output_quotient 	<= std_logic_vector(quotient_stages(STAGES));
	axis_output_remainder	<= std_logic_vector(resize(unsigned(acc_stages(STAGES)), NUMBER_OF_SAMPLES_WIDTH)); --should be only this wide
	axis_output_last 	  	<= stage_last(STAGES);
	axis_output_user 		<= stage_user(STAGES);
	

end Behavioral;
