----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 08.02.2019 10:28:15
-- Design Name: 
-- Module Name: AXIS_MULT_COMPONENT_18x18 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Wrapper around the 18x18 mult IP core to be used with AXIS interfaces
-- 
-- Dependencies: mult18x18 component
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AXIS_MULT_COMPONENT_18x18 is
	Generic (
		USER_WIDTH: integer := 1;
		DESIRED_STAGES: integer := 3
	);
	Port(
		clk, rst: in std_logic;
		input_a, input_b	: in  std_logic_vector(17 downto 0);
		input_valid			: in  std_logic;
		input_ready			: out std_logic;
		input_last			: in  std_logic;
		input_user			: in  std_logic_vector(USER_WIDTH - 1 downto 0);
		output_data			: out std_logic_vector(35 downto 0);
		output_valid		: out std_logic;
		output_ready		: in  std_logic;
		output_last			: out std_logic;
		output_user 		: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_MULT_COMPONENT_18x18;

architecture Behavioral of AXIS_MULT_COMPONENT_18x18 is
	--multiplier declaration
	constant MULT_STAGES: integer := 3;
	COMPONENT mult_18_x_18
		PORT (
			CLK : IN STD_LOGIC;
			A : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
			B : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
			CE : IN STD_LOGIC;
			SCLR : IN STD_LOGIC;
			P : OUT STD_LOGIC_VECTOR(35 DOWNTO 0)
		);
	END COMPONENT;

	signal mult_enable: std_logic;
	
	signal mult_stage_occupancy: std_logic_vector(MULT_STAGES - 1 downto 0);
	signal mult_stage_last: std_logic_vector(MULT_STAGES - 1 downto 0);
	signal mult_stage_user: std_logic_vector(MULT_STAGES*USER_WIDTH - 1 downto 0);
	
begin

	assert DESIRED_STAGES = MULT_STAGES report "STAGES MUST BE MULT_STAGES" severity failure;

	mult_enable <= '1' when mult_stage_occupancy(MULT_STAGES - 1) = '0' or output_ready = '1' else '0';
	
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				mult_stage_occupancy <= (others => '0');
				mult_stage_last <= (others => '0');
				mult_stage_user <= (others => '0');
			elsif mult_enable = '1' then
				mult_stage_occupancy <= mult_stage_occupancy(MULT_STAGES - 2 downto 0) & input_valid;
				mult_stage_last      <= mult_stage_last     (MULT_STAGES - 2 downto 0) & input_last;
				mult_stage_user      <= mult_stage_user     (MULT_STAGES*USER_WIDTH - 1 - USER_WIDTH downto 0) & input_user;
			end if;
		end if;
	end process;

	mult: mult_18_x_18
		port map(CLK => CLK, 
				 A => input_a, 
				 B => input_b, 
				 CE => mult_enable, 
				 SCLR => rst, 
				 P => output_data);

	output_valid <= mult_stage_occupancy(MULT_STAGES - 1);
	output_last  <= mult_stage_last(MULT_STAGES - 1);
	output_user  <= mult_stage_user(MULT_STAGES*USER_WIDTH - 1 downto (MULT_STAGES-1)*USER_WIDTH);
	input_ready  <= mult_enable;

end Behavioral;
