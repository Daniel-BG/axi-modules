----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.03.2021 14:01:24
-- Design Name: 
-- Module Name: axis_dotprod - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_dotprod is
	generic (
		VECTOR_LENGTH: integer := 6;
		VECTOR_LENGTH_LOG: integer := 3;
		INPUT_A_DATA_WIDTH: integer := 19;
		INPUT_B_DATA_WIDTH: integer := 16
	);
	port ( 
		clk, rst: in std_logic;
		axis_input_a_d: in std_logic_vector(INPUT_A_DATA_WIDTH*VECTOR_LENGTH-1 downto 0);
		axis_input_a_ready: out std_logic;
		axis_input_a_valid: in std_logic;
		axis_input_b_d: in std_logic_vector(INPUT_B_DATA_WIDTH*VECTOR_LENGTH-1 downto 0);
		axis_input_b_ready: out std_logic;
		axis_input_b_valid: in std_logic;
		axis_output_d: out std_logic_vector(INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH+VECTOR_LENGTH_LOG - 1 downto 0);
		axis_output_ready: in std_logic;
		axis_output_valid: out std_logic
	);
end axis_dotprod;

architecture Behavioral of axis_dotprod is
	constant MULT_STAGES: integer := 4;
	
	signal input_a_readys, input_b_readys: std_logic_vector(VECTOR_LENGTH - 1 downto 0);
	
	signal axis_mult_out_d: std_logic_vector((INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH)*VECTOR_LENGTH-1 downto 0);
	signal axis_mult_out_ready, axis_mult_out_valid: std_logic_vector(VECTOR_LENGTH - 1 downto 0);
	
	signal axis_latched_d: std_logic_vector(INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH+VECTOR_LENGTH_LOG - 1 downto 0);
	signal axis_latched_ready, axis_latched_valid: std_logic;
begin

	--generate multipliers
	--take first as sync module since the rest are synchronized
	axis_input_a_ready <= input_a_readys(0);
	axis_input_b_ready <= input_b_readys(0);
	gen_multipliers: for i in 0 to VECTOR_LENGTH-1 generate
		mult_i: entity work.AXIS_MULTIPLIER
			generic map (
				DATA_WIDTH_0 => INPUT_A_DATA_WIDTH,
				DATA_WIDTH_1 => INPUT_B_DATA_WIDTH,
				OUTPUT_WIDTH => INPUT_A_DATA_WIDTH + INPUT_B_DATA_WIDTH,
				SIGN_EXTEND_0=> true,
				SIGN_EXTEND_1=> true,
				SIGNED_OP	 => true,
				DESIRED_STAGES=> MULT_STAGES
			)
			port map(
				clk => clk, rst => rst,
				input_0_data	=> axis_input_a_d(INPUT_A_DATA_WIDTH*(i+1) - 1 downto INPUT_A_DATA_WIDTH*i),
				input_0_valid	=> axis_input_a_valid,
				input_0_ready	=> input_a_readys(i),

				input_1_data	=> axis_input_b_d(INPUT_B_DATA_WIDTH*(i+1) - 1 downto INPUT_B_DATA_WIDTH*i),
				input_1_valid	=> axis_input_b_valid,
				input_1_ready	=> input_b_readys(i),
				output_data		=> axis_mult_out_d((INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH)*(i+1)-1 downto (INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH)*i),
				output_valid	=> axis_mult_out_valid(i),
				output_ready	=> axis_mult_out_ready(i)
			);
	end generate;
	
	
	reductor: entity work.axis_treered_sum 
		generic map (
			DATA_WIDTH => INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH,
			VECTOR_LENGTH => VECTOR_LENGTH,
			VECTOR_LENGTH_LOG => VECTOR_LENGTH_LOG
		)
		Port map( 
			axis_in_d => axis_mult_out_d,
			axis_out_d => axis_latched_d
		);

	axis_latched_valid <= axis_mult_out_valid(0);
	axis_mult_out_ready <= (others => '1') when axis_latched_ready = '1' else (others => '0');


	output_latch: entity work.AXIS_DATA_LATCH
		generic map (
			DATA_WIDTH => INPUT_A_DATA_WIDTH+INPUT_B_DATA_WIDTH+VECTOR_LENGTH_LOG
		)
		port map ( 
			clk => clk, rst => rst,
			input_data	=> axis_latched_d,
			input_ready => axis_latched_ready,
			input_valid => axis_latched_valid,
			output_data	=> axis_output_d,
			output_ready=> axis_output_ready,
			output_valid=> axis_output_valid
		);

end Behavioral;
