----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.03.2021 15:04:25
-- Design Name: 
-- Module Name: axis_symmetric_synchronizer_latched_4 - Behavioral
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


entity axis_symmetric_synchronizer_latched_4 is
	generic (
		DATA_WIDTH: integer := 16;
		LAST_POLICY: am_last_policy_t := OR_ALL;
		USER_WIDTH: integer := 1;
		USER_POLICY: am_last_policy_t := OR_ALL
	);
	port (
		clk, rst: std_logic;
		axis_in_0_d		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_0_last	: in std_logic := '0';
		axis_in_0_ready	: out std_logic;
		axis_in_0_valid : in std_logic;
		axis_in_0_user	: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_in_1_d		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_1_last	: in std_logic := '0';
		axis_in_1_ready	: out std_logic;
		axis_in_1_valid : in std_logic;
		axis_in_1_user	: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_in_2_d		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_2_last	: in std_logic := '0';
		axis_in_2_ready	: out std_logic;
		axis_in_2_valid : in std_logic;
		axis_in_2_user	: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_in_3_d		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_in_3_last	: in std_logic := '0';
		axis_in_3_ready	: out std_logic;
		axis_in_3_valid : in std_logic;
		axis_in_3_user	: in std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		axis_out_d_0 	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_out_d_1 	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_out_d_2 	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_out_d_3 	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		axis_out_ready 	: in std_logic;
		axis_out_valid 	: out std_logic;
		axis_out_last	: out std_logic;
		axis_out_user 	: out std_logic_vector(USER_WIDTH - 1 downto 0)	
	);
end axis_symmetric_synchronizer_latched_4;

architecture Behavioral of axis_symmetric_synchronizer_latched_4 is
	constant INPUT_PORTS: integer := 4;
	
	--to internal module
	signal input_valid: std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal input_ready: std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal input_data : std_logic_vector(INPUT_PORTS*DATA_WIDTH - 1 downto 0);
	signal input_last : std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal input_user : std_logic_vector(INPUT_PORTS*USER_WIDTH - 1 downto 0);
	--from internal module
	signal output_valid	: std_logic;
	signal output_ready	: std_logic;
	signal output_data	: std_logic_vector(INPUT_PORTS*DATA_WIDTH - 1 downto 0);
	signal output_last  : std_logic_vector(INPUT_PORTS - 1 downto 0);
	signal output_user 	: std_logic_vector(INPUT_PORTS*USER_WIDTH - 1 downto 0);

begin


	input_valid <= axis_in_0_valid & axis_in_1_valid & axis_in_2_valid & axis_in_3_valid;
	axis_in_0_ready <= input_ready(3);
	axis_in_1_ready <= input_ready(2);
	axis_in_2_ready <= input_ready(1);
	axis_in_3_ready <= input_ready(0);
	input_data  <= axis_in_0_d & axis_in_1_d & axis_in_2_d & axis_in_3_d;
	input_last  <= axis_in_0_last & axis_in_1_last & axis_in_2_last & axis_in_3_last;
	input_user  <= axis_in_0_user & axis_in_1_user & axis_in_2_user & axis_in_3_user;
	--from internal module
	axis_out_valid <= output_valid;
	output_ready   <= axis_out_ready;
	axis_out_d_0 <= output_data(DATA_WIDTH*(3+1)-1 downto DATA_WIDTH*3);
	axis_out_d_1 <= output_data(DATA_WIDTH*(2+1)-1 downto DATA_WIDTH*2);
	axis_out_d_2 <= output_data(DATA_WIDTH*(1+1)-1 downto DATA_WIDTH*1);
	axis_out_d_3 <= output_data(DATA_WIDTH*(0+1)-1 downto DATA_WIDTH*0);
	
	assert LAST_POLICY = OR_ALL or LAST_POLICY = AND_ALL report "Only OR_ALL and AND_ALL supported" severity failure;
	gen_last_orall: if LAST_POLICY = OR_ALL generate
		axis_out_last <= '0' when output_last = (output_last'range => '0') else '1'; 
	end generate;
	gen_last_andall: if LAST_POLICY = AND_ALL generate
		axis_out_last <= '1' when output_last = (output_last'range => '1') else '0';
	end generate;
	
	assert USER_POLICY = OR_ALL or USER_POLICY = AND_ALL report "Only OR_ALL and AND_ALL supported" severity failure;
	gen_user_orall: if USER_POLICY = OR_ALL generate
		axis_out_user <= 	output_user(USER_WIDTH*(0+1)-1 downto USER_WIDTH*0) or
					 		output_user(USER_WIDTH*(1+1)-1 downto USER_WIDTH*1) or
					 		output_user(USER_WIDTH*(2+1)-1 downto USER_WIDTH*2) or
					 		output_user(USER_WIDTH*(3+1)-1 downto USER_WIDTH*3);
	end generate;
	gen_user_andall: if USER_POLICY = AND_ALL generate
		axis_out_user <= 	output_user(USER_WIDTH*(0+1)-1 downto USER_WIDTH*0) and
							output_user(USER_WIDTH*(1+1)-1 downto USER_WIDTH*1) and
							output_user(USER_WIDTH*(2+1)-1 downto USER_WIDTH*2) and
							output_user(USER_WIDTH*(3+1)-1 downto USER_WIDTH*3);
	end generate;

	internal_synchronizer: entity work.axis_symmetric_synchronizer_latched_base 
		generic map (
			DATA_WIDTH 	=> DATA_WIDTH,
			INPUT_PORTS => INPUT_PORTS,
			USER_WIDTH 	=> USER_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid => input_valid,
			input_ready => input_ready,
			input_data  => input_data,
			input_last  => input_last,
			input_user  => input_user,
			--to output axi ports
			output_valid=> output_valid,
			output_ready=> output_ready,
			output_data	=> output_data,
			output_last	=> output_last,
			output_user => output_user
		);
end Behavioral;
