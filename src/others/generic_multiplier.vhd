----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.03.2021 12:24:51
-- Design Name: 
-- Module Name: generic_multiplier - Behavioral
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

entity generic_multiplier is
	generic (
		A_SIZE		: integer  := 50;
		B_SIZE		: integer  := 50;
		STAGES		: positive := 12;
		SIGNED_A	: boolean  := true;
		SIGNED_B	: boolean  := false
	);
	Port ( 
		clk, enable: in std_logic;
		in_a: in std_logic_vector(A_SIZE - 1 downto 0);
		in_b: in std_logic_vector(B_SIZE - 1 downto 0);
		prod: out std_logic_vector(A_SIZE + B_SIZE - 1 downto 0)
	);
end generic_multiplier;

architecture Behavioral of generic_multiplier is
	signal in_a_se: std_logic_vector(A_SIZE downto 0);
	signal in_b_se: std_logic_vector(B_SIZE downto 0);

	signal prod_raw: std_logic_vector(A_SIZE + B_SIZE + 1 downto 0);
begin

	assert STAGES >= 2 report "Multiplier stages must be at least 2" severity failure;

	gen_s_a: if SIGNED_A generate
		in_a_se <= in_a(in_a'high) & in_a;
	end generate;
	gen_u_a: if not SIGNED_A generate
		in_a_se <= "0" & in_a;
	end generate;
	gen_s_b: if SIGNED_B generate
		in_b_se <= in_b(in_b'high) & in_b;
	end generate;
	gen_u_b: if not SIGNED_B generate
		in_b_se <= "0" & in_b;
	end generate;
	
	multiplier: entity work.signed_multiplier 
		generic map (
			A_SIZE => A_SIZE + 1,
			B_SIZE => B_SIZE + 1,
			STAGES => STAGES
		)
		Port map ( 
			clk => clk, enable => enable,
			in_a => in_a_se,
			in_b => in_b_se,
			prod => prod_raw
		);
	
	prod <= prod_raw(prod'range);
	
end Behavioral;
