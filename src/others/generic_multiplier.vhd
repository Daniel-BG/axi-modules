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
		A_SIZE		: integer  := 5;
		B_SIZE		: integer  := 5;
		STAGES		: positive := 3;
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
	signal input_reg_a: std_logic_vector(A_SIZE - 1 downto 0);
	signal input_reg_b: std_logic_vector(B_SIZE - 1 downto 0);

	constant OUTPUT_STAGES: integer := STAGES - 1;

	type prod_stages_t is array(1 to OUTPUT_STAGES) of std_logic_vector(A_SIZE + B_SIZE - 1 downto 0);
	
	signal prod_stages: prod_stages_t;
	signal mult_result: std_logic_vector(A_SIZE + B_SIZE - 1 downto 0);
	attribute use_dsp : string;
	attribute use_dsp of prod_stages : signal is "yes";
begin
	assert STAGES >= 2 report "Multiplier stages must be at least 2" severity failure;

	gen_s_s: if SIGNED_A and SIGNED_B generate
		process_s_s: process(input_reg_a, input_reg_b)  begin
			mult_result <= std_logic_vector(resize(resize(signed(input_reg_a), A_SIZE + B_SIZE) * resize(signed(input_reg_b), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
		end process;
	end generate;
	gen_u_u: if not SIGNED_A and not SIGNED_B generate
		process_u_u: process(input_reg_a, input_reg_b)  begin
			mult_result <= std_logic_vector(resize(resize(unsigned(input_reg_a), A_SIZE + B_SIZE) * resize(unsigned(input_reg_b), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
		end process;
	end generate;
	gen_s_u: if SIGNED_A and not SIGNED_B generate
		process_s_u: process(input_reg_a, input_reg_b)  begin
			mult_result <= std_logic_vector(resize(resize(signed(input_reg_a), A_SIZE + B_SIZE) * resize(signed("0" & unsigned(input_reg_b)), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
		end process;
	end generate;
	gen_u_s: if not SIGNED_A and SIGNED_B generate
		process_u_s: process(input_reg_a, input_reg_b)  begin
			mult_result <= std_logic_vector(resize(resize(signed("0" & unsigned(input_reg_a)), A_SIZE + B_SIZE) * resize(signed(input_reg_b), A_SIZE + B_SIZE), A_SIZE + B_SIZE));
		end process;
	end generate;
	
	
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if enable = '1' then
				input_reg_b <= in_b;
				input_reg_a <= in_a;
				for i in 1 to OUTPUT_STAGES loop
					if i = 1 then
						prod_stages(i) <= mult_result;
					else
						prod_stages(i) <= prod_stages(i-1);	
					end if;
				end loop;
			end if;
		end if;
	end process;
	
	prod <= prod_stages(OUTPUT_STAGES);
	
end Behavioral;
