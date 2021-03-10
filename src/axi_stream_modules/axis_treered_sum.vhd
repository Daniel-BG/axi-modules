----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.03.2021 12:27:33
-- Design Name: 
-- Module Name: treered_test - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_treered_sum is
	generic (
		DATA_WIDTH: integer := 16;
		VECTOR_LENGTH: integer := 7;
		VECTOR_LENGTH_LOG: integer := 3
	);
	Port ( 
		axis_in_d: in std_logic_vector(DATA_WIDTH*VECTOR_LENGTH-1 downto 0);
		axis_out_d: out std_logic_vector(DATA_WIDTH+VECTOR_LENGTH_LOG-1 downto 0)
	);
end axis_treered_sum;

architecture Behavioral of axis_treered_sum is
	constant LENGTH_LEFT: integer := VECTOR_LENGTH / 2;
	constant LENGTH_RIGHT: integer := (VECTOR_LENGTH / 2) + (VECTOR_LENGTH mod 2);
	
	signal output_left, output_right: std_logic_vector(DATA_WIDTH+VECTOR_LENGTH_LOG - 2 downto 0);
	
begin

	assert VECTOR_LENGTH > 0 report "ERROR" severity failure;
	assert 2**VECTOR_LENGTH_LOG >= VECTOR_LENGTH report "ERROR" severity failure;

	gen_base_case: if VECTOR_LENGTH = 1 generate
		axis_out_d <= std_logic_vector(resize(signed(axis_in_d), axis_out_d'length));
	end generate;
	
	gen_others: if VECTOR_LENGTH > 1 generate
		--perform recursive reduction
		tree_left: entity work.axis_treered_sum
			generic map (
				DATA_WIDTH => DATA_WIDTH,
				VECTOR_LENGTH => LENGTH_LEFT,
				VECTOR_LENGTH_LOG => VECTOR_LENGTH_LOG - 1
			)
			port map (
				axis_in_d => axis_in_d(DATA_WIDTH*VECTOR_LENGTH-1 downto DATA_WIDTH*LENGTH_RIGHT),
				axis_out_d => output_left
			);
		
		tree_right: entity work.axis_treered_sum
			generic map (
				DATA_WIDTH => DATA_WIDTH,
				VECTOR_LENGTH => LENGTH_RIGHT,
				VECTOR_LENGTH_LOG => VECTOR_LENGTH_LOG - 1
			)
			port map (
				axis_in_d => axis_in_d(DATA_WIDTH*LENGTH_RIGHT-1 downto 0),
				axis_out_d=> output_right
			);
		
		axis_out_d <= std_logic_vector(resize(signed(output_left), axis_out_d'length) + resize(signed(output_right), axis_out_d'length));
	end generate;
end Behavioral;
	
	