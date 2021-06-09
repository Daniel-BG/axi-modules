----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel B�scones
-- 
-- Create Date: 11.02.2019 16:28:19
-- Design Name: 
-- Module Name: AXIS_INTERVAL_CLAMPER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Take an input AXIS stream and output the values clamped to a
--		certain specified interval
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

entity AXIS_INTERVAL_CLAMPER is
	Generic (
		DATA_WIDTH: integer := 18;
		IS_SIGNED: boolean := true;
		LOWER_LIMIT: integer := 0;
		UPPER_LIMIT: integer := 2**16;
		USER_WIDTH: integer := 1
	);
	Port(
		clk, rst	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid	: in  std_logic;
		input_ready	: out std_logic;
		input_last  : in  std_logic := '0';
		input_user	: in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in  std_logic;
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_INTERVAL_CLAMPER;

architecture Behavioral of AXIS_INTERVAL_CLAMPER is
	signal output_reg: std_logic_vector(DATA_WIDTH - 1 downto 0);

	signal output_valid_reg: std_logic;
	signal output_last_reg: std_logic;
	signal output_user_reg: std_logic_vector(USER_WIDTH - 1 downto 0);


	
	signal op_enable: std_logic;
	
	signal result: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--inner signals
	signal inner_reset			: std_logic;
begin

	reset_replicator: entity work.reset_replicator
		port map (
			clk => clk, rst => rst,
			rst_out => inner_reset
		);

	op_enable <= '1' when output_valid_reg = '0' or output_ready = '1' else '0';

	gen_signed: if IS_SIGNED generate
		result <=
			std_logic_vector(to_signed(LOWER_LIMIT, DATA_WIDTH))
				when signed(input_data) < to_signed(LOWER_LIMIT, DATA_WIDTH) else
			std_logic_vector(to_signed(UPPER_LIMIT, DATA_WIDTH))
				when signed(input_data) > to_signed(UPPER_LIMIT, DATA_WIDTH) else
			input_data;
	end generate;
	
	gen_unsigned: if not IS_SIGNED generate
		result <=
			std_logic_vector(to_unsigned(LOWER_LIMIT, DATA_WIDTH))
				when unsigned(input_data) < to_unsigned(LOWER_LIMIT, DATA_WIDTH) else
			std_logic_vector(to_unsigned(UPPER_LIMIT, DATA_WIDTH))
				when unsigned(input_data) > to_unsigned(UPPER_LIMIT, DATA_WIDTH) else
			input_data;
	end generate;
	
	seq_update: process(clk, inner_reset)
	begin
		if rising_edge(clk) then
			if inner_reset = '1' then
				output_valid_reg <= '0';
				output_reg <= (others => '0');
				output_last_reg <= '0';
				output_user_reg <= (others => '0');
			elsif op_enable = '1' then
				output_reg <= result;
				output_valid_reg <= input_valid;
				output_last_reg <= input_last;
				output_user_reg <= input_user;
			end if;
		end if;
	end process;
				 
	output_last  <= output_last_reg;
	output_user  <= output_user_reg;
	output_valid <= output_valid_reg;
	input_ready  <= op_enable;
	output_data  <= output_reg;
	

end Behavioral;
