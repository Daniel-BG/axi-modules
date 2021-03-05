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

entity axis_segmented_unsigned_divider is
	generic (
		DIVIDEND_WIDTH: integer := 24;
		DIVISOR_WIDTH: integer := 12;
		LAST_POLICY: am_last_policy_t := PASS_ZERO;
		USER_WIDTH: integer := 1;
		USER_POLICY: am_last_policy_t := PASS_ZERO
	);
	port ( 
		clk, rst: std_logic;
		axis_dividend_data		: in std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
		axis_dividend_ready		: out std_logic;
		axis_dividend_valid		: in std_logic;
		axis_dividend_last		: in std_logic;
		axis_dividend_user		: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_divisor_data		: in std_logic_vector(DIVISOR_WIDTH - 1 downto 0);
		axis_divisor_ready		: out std_logic;
		axis_divisor_valid		: in std_logic;
		axis_divisor_last		: in std_logic;
		axis_divisor_user		: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_output_quotient	: out std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
		axis_output_remainder	: out std_logic_vector(DIVISOR_WIDTH - 1 downto 0);
		axis_output_ready 		: in std_logic;
		axis_output_valid 		: out std_logic;
		axis_output_last 		: out std_logic;
		axis_output_user 		: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end axis_segmented_unsigned_divider;

architecture Behavioral of axis_segmented_unsigned_divider is

	signal joint_valid, joint_ready, joint_last: std_logic;
	signal joint_dividend: std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
	signal joint_divisor: std_logic_vector(DIVISOR_WIDTH - 1 downto 0);
	signal joint_user: std_logic_vector(USER_WIDTH - 1 downto 0);
	
	constant STAGES: integer := DIVIDEND_WIDTH - DIVISOR_WIDTH + 1;
	
	type dividend_stages_t 	is array(0 to STAGES-1) of unsigned(DIVIDEND_WIDTH - 1 downto 0);
	type divisor_stages_t 	is array(0 to STAGES-1) of unsigned(DIVISOR_WIDTH - 1 downto 0); 
	type shifted_divisor_t 	is array(0 to STAGES-1) of unsigned(DIVIDEND_WIDTH - 1 downto 0);
	type stage_full_t 		is array(0 to STAGES-1) of std_logic;
	type user_stages_t 		is array(0 to STAGES-1) of std_logic_vector(USER_WIDTH - 1 downto 0);
	signal divisor_stages	: divisor_stages_t;
	signal dividend_stages	: dividend_stages_t;
	signal quotient_stages  : dividend_stages_t;
	signal shifted_divisor  : shifted_divisor_t;
	signal stage_full		: stage_full_t;
	signal stage_last 		: stage_full_t;
	signal stage_user 		: user_stages_t;
	 
	signal pipeline_enable  : std_logic;
begin
	
	assert DIVISOR_WIDTH <= DIVIDEND_WIDTH report "DIVIDEND MUST BE WIDER THAN DIVISOR" severity failure;
	
	
	pipeline_enable <= 
		'1' when stage_full(STAGES-1) = '0'
			 else
		'1' when axis_output_ready = '1'
			 else
		'0';
		
	joint_ready <= pipeline_enable;
	

	joint_signals: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => DIVIDEND_WIDTH,
			DATA_WIDTH_1 => DIVISOR_WIDTH,
			LATCH => false,
			LAST_POLICY => LAST_POLICY,
			USER_WIDTH => USER_WIDTH,
			USER_POLICY => USER_POLICY
		)
		port map (
			clk => clk, rst => rst,
			input_0_valid => axis_dividend_valid,
			input_0_ready => axis_dividend_ready,
			input_0_data  => std_logic_vector(axis_dividend_data),
			input_0_last  => axis_dividend_last,
			input_0_user  => axis_dividend_user,
			input_1_valid => axis_divisor_valid,
			input_1_ready => axis_divisor_ready,
			input_1_data  => std_logic_vector(axis_divisor_data),
			input_1_last  => axis_divisor_last,
			input_1_user  => axis_divisor_user,
			--to output axi ports
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_dividend,
			output_data_1 => joint_divisor,
			output_last   => joint_last,
			output_user   => joint_user
		);
	
	
	gen_stages: for i in 0 to STAGES-1 generate
		gen_zero: if i = 0 generate
			shifted_divisor(0) <= shift_left(resize(unsigned(joint_divisor), DIVIDEND_WIDTH), DIVIDEND_WIDTH - DIVISOR_WIDTH);
			register_stage_0: process(clk, rst, pipeline_enable)
			begin
				if rst = '1' then
					dividend_stages(0) 	<= (others => '0');
					divisor_stages(0)  	<= (others => '0');
					quotient_stages(0) 	<= (others => '0');
					stage_full(0) 	  	<= '0';
					stage_last(0) 		<= '0';
					stage_user(0) 		<= (others => '0');
				elsif rising_edge(clk) and pipeline_enable = '1' then
					if unsigned(joint_dividend) < shifted_divisor(0) then --not substracting
						dividend_stages(0) <= unsigned(joint_dividend); 
						quotient_stages(0) <= (others => '0');
					else --substracting
						dividend_stages(0) <= unsigned(joint_dividend) - shifted_divisor(0);
						quotient_stages(0) <= to_unsigned(2**(STAGES-1), DIVIDEND_WIDTH);
					end if;
					divisor_stages(0) <= unsigned(joint_divisor);
					stage_full(0) <= joint_valid;
					stage_last(0) <= joint_last;
					stage_user(0) <= joint_user;
				end if;
			end process;
		end generate;
		gen_nonzero: if i /= 0 generate
			shifted_divisor(i) <= shift_left(resize(unsigned(divisor_stages(i-1)), DIVIDEND_WIDTH), DIVIDEND_WIDTH - DIVISOR_WIDTH - i);
			register_stage_i: process(clk, rst, pipeline_enable)
			begin
				if rst = '1' then
					dividend_stages(i) 	<= (others => '0');
					divisor_stages(i)  	<= (others => '0');
					quotient_stages(i) 	<= (others => '0');
					stage_full(i) 	  	<= '0';
					stage_last(i) 		<= '0';
					stage_user(i) 		<= (others => '0');
				elsif rising_edge(clk) and pipeline_enable = '1' then
					if unsigned(dividend_stages(i-1)) < shifted_divisor(i) then --not substracting
						dividend_stages(i) <= dividend_stages(i-1);
						quotient_stages(i) <= quotient_stages(i-1); 
					else --substracting
						dividend_stages(i) <= dividend_stages(i-1) - shifted_divisor(i);
						quotient_stages(i) <= quotient_stages(i-1) + to_unsigned(2**(STAGES-1-i), DIVIDEND_WIDTH);
					end if;
					divisor_stages(i) 	<= divisor_stages(i-1); --keep same value
					stage_full(i) 	  	<= stage_full(i-1);
					stage_last(i) 		<= stage_last(i-1);
					stage_user(i) 		<= stage_user(i-1);
				end if;
			end process;
		end generate;
	end generate;

	axis_output_valid	 	<= stage_full(STAGES - 1);
	axis_output_quotient 	<= std_logic_vector(quotient_stages(STAGES - 1));
	axis_output_remainder	<= std_logic_vector(resize(dividend_stages(STAGES - 1), DIVISOR_WIDTH)); --should be only this wide
	axis_output_last 	  	<= stage_last(STAGES - 1);
	axis_output_user 		<= stage_user(STAGES - 1);
	

end Behavioral;
