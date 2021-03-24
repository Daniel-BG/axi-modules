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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity generic_multiplier is
	generic (
		A_SIZE		: integer := 20;
		B_SIZE		: integer := 20;
		STAGES		: integer := 3;
		SIGNED_A	: boolean := true;
		SIGNED_B	: boolean := true
	);
	Port ( 
		clk, enable: in std_logic;
		in_a: in std_logic_vector(A_SIZE - 1 downto 0);
		in_b: in std_logic_vector(B_SIZE - 1 downto 0);
		prod: out std_logic_vector(A_SIZE + B_SIZE - 1 downto 0)
	);
end generic_multiplier;

architecture Behavioral of generic_multiplier is
	type prod_stages_t is array(0 to STAGES) of std_logic_vector(A_SIZE + B_SIZE - 1 downto 0);
	
	signal prod_stages: prod_stages_t;
begin
	gen_s_s: if SIGNED_A and SIGNED_B generate
		prod_stages(0) <= std_logic_vector(signed(in_a) * signed(in_b));
	end generate;
	gen_u_u: if not SIGNED_A and not SIGNED_B generate
		prod_stages(0) <= std_logic_vector(unsigned(in_a) * unsigned(in_b));
	end generate;
	gen_s_u: if SIGNED_A and not SIGNED_B generate
		prod_stages(0) <= std_logic_vector(resize(signed(in_a) * signed("0" & unsigned(in_b)), A_SIZE + B_SIZE));
	end generate;
	gen_u_s: if not SIGNED_A and SIGNED_B generate
		prod_stages(0) <= std_logic_vector(resize(signed("0" & unsigned(in_a)) * signed(in_b), A_SIZE + B_SIZE));
	end generate;
	
	
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if enable = '1' then
				for i in 1 to STAGES loop
					prod_stages(i) <= prod_stages(i-1);
				end loop;
			end if;
		end if;
	end process;
	
	prod <= prod_stages(STAGES);
	
end Behavioral;
