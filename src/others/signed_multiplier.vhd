----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 17.05.2021 11:59:37
-- Design Name: 
-- Module Name: signed_multiplier - Behavioral
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

entity signed_multiplier is
	generic (
		A_SIZE		: integer  := 50;
		B_SIZE		: integer  := 50;
		STAGES		: positive := 12
	);
	Port ( 
		clk, enable: in std_logic;
		in_a: in std_logic_vector(A_SIZE - 1 downto 0);
		in_b: in std_logic_vector(B_SIZE - 1 downto 0);
		prod: out std_logic_vector(A_SIZE + B_SIZE - 1 downto 0)
	);
end signed_multiplier;

architecture Behavioral of signed_multiplier is
	signal input_reg_a: std_logic_vector(A_SIZE - 1 downto 0);
	signal input_reg_b: std_logic_vector(B_SIZE - 1 downto 0);

	constant OUTPUT_STAGES: integer := STAGES - 1;

	type prod_stages_t is array(0 to OUTPUT_STAGES - 1) of std_logic_vector(A_SIZE + B_SIZE - 1 downto 0);
	
	signal prod_stages: prod_stages_t;
	attribute use_dsp : string;
	attribute use_dsp of prod_stages : signal is "yes";
begin

	gen_sequential: if STAGES = 0 generate
		prod <= std_logic_vector(resize(resize(signed(in_a), A_SIZE + B_SIZE) * resize(signed(in_b), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
	end generate;
	
	gen_one: if STAGES = 1 generate
		seq: process(clk)
		begin
			if rising_edge(clk) then
				if enable = '1' then
					input_reg_b <= in_b;
					input_reg_a <= in_a;
				end if;
			end if;
		end process;
		
		prod <= std_logic_vector(resize(resize(signed(input_reg_a), A_SIZE + B_SIZE) * resize(signed(input_reg_b), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
	end generate;


	gen_two_or_more: if STAGES >= 2 generate
		seq: process(clk)
		begin
			if rising_edge(clk) then
				if enable = '1' then
					input_reg_b <= in_b;
					input_reg_a <= in_a;
					prod_stages(0) <= std_logic_vector(resize(resize(signed(input_reg_a), A_SIZE + B_SIZE) * resize(signed(input_reg_b), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
					for i in 1 to OUTPUT_STAGES - 1 loop
						prod_stages(i) <= prod_stages(i-1);	
					end loop;
				end if;
			end if;
		end process;
		
		prod <= prod_stages(OUTPUT_STAGES - 1);
	end generate;


end Behavioral;