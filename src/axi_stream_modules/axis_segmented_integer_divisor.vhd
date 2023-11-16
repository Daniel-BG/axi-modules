----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 16.11.2023
-- Design Name: 
-- Module Name: axis_segmented_integer_divider - Behavioral
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

entity axis_segmented_integer_divider is
	generic (
		DIVIDEND_WIDTH: integer := 16;
		DIVISOR_WIDTH: integer := 20;
		FLAG_WIDTH: integer := 20
	);
	port ( 
		clk, rst: std_logic;
		axis_in_dividend      : in std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
		axis_in_divisor       : in std_logic_vector(DIVISOR_WIDTH - 1 downto 0); 
		axis_in_ready         : out std_logic;
		axis_in_valid         : in std_logic;
		axis_in_flags          : in std_logic_vector(FLAG_WIDTH - 1 downto 0);
		axis_out_quotient	: out std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
		axis_out_remainder	: out std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
		axis_out_ready 		: in std_logic;
		axis_out_valid 		: out std_logic;
		axis_out_flags 		: out std_logic_vector(FLAG_WIDTH - 1 downto 0)
	);
end axis_segmented_integer_divider;

architecture Behavioral of axis_segmented_integer_divider is

    --need as many stages as the dividend width
	constant STAGES: integer := DIVIDEND_WIDTH;
	--need a buffer of at least the sum of lengths - 1 to shift the divisor left and align
	--its rightmost bit with the dividend's leftmost bit
	constant BUFFER_LEN: integer := DIVIDEND_WIDTH + DIVISOR_WIDTH - 1;
	
	type dividend_stages_t 	is array(0 to STAGES) of std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
	type divisor_stages_t 	is array(0 to STAGES) of std_logic_vector(DIVISOR_WIDTH - 1 downto 0); 
	type stage_full_t 		is array(0 to STAGES) of std_logic;
	type flag_stages_t 		is array(0 to STAGES) of std_logic_vector(FLAG_WIDTH - 1 downto 0);
	
	
	signal divisor_stages	: divisor_stages_t;
	signal dividend_stages	: dividend_stages_t;
	signal quotient_stages  : dividend_stages_t;
	signal stage_full		: stage_full_t;
	signal stage_negative 	: stage_full_t;
	signal stage_flags 		: flag_stages_t;
	 
	signal pipeline_enable  : std_logic;
	
	
	signal in_dividend_negative: std_logic;
	signal in_divisor_negative: std_logic;
begin

	
	pipeline_enable <= 
		'1' when stage_full(STAGES-1) = '0'
			 else
		'1' when axis_out_ready = '1'
			 else
		'0';
	axis_in_ready <= pipeline_enable;
		
	in_dividend_negative   <= '1' when signed(axis_in_dividend) < 0 else '0';
	in_divisor_negative    <= '1' when signed(axis_in_divisor) < 0 else '0';
	
	dividend_stages(0) 	   <= axis_in_dividend when in_dividend_negative = '0' else std_logic_vector(-signed(axis_in_dividend));
	divisor_stages(0) 	   <= axis_in_divisor when in_divisor_negative = '0' else std_logic_vector(-signed(axis_in_divisor));
	quotient_stages(0)     <= (others => '0');
	stage_full(0)          <= axis_in_valid;
	stage_flags(0)         <= axis_in_flags;
	stage_negative(0)      <= in_dividend_negative xor in_divisor_negative;
	
	
	gen_stages: for i in 1 to STAGES generate
	begin
	   --upscaled_dividend(i) <= std_logic_vector(resize(unsigned(dividend_stages(i-1)), BUFFER_LEN));
	   --shifted_divisor(i) <= std_logic_vector(shift_left(resize(unsigned(divisor_stages(i-1)), BUFFER_LEN), DIVIDEND_WIDTH - i));
		register_stage_i: process(clk, rst, pipeline_enable)
				variable stagequot: natural range 0 to 1;
				--add enough zeroes to the left of the dividend to be able to align the shifted divisor
				variable upscaled_dividend: std_logic_vector(BUFFER_LEN - i downto 0);
				variable shifted_divisor: std_logic_vector(BUFFER_LEN - i downto 0);
			begin
			    upscaled_dividend := std_logic_vector(resize(unsigned(dividend_stages(i-1)), BUFFER_LEN - i + 1));
			    shifted_divisor := std_logic_vector(shift_left(resize(unsigned(divisor_stages(i-1)), BUFFER_LEN - i + 1), DIVIDEND_WIDTH - i));
			    
				if rising_edge(clk) then
					if rst = '1' then
					    --just reset the stage full flag, the rest we don't care
						stage_full(i) 	  	<= '0';
				    --only update if the pipeline shift is enabled
					elsif pipeline_enable = '1' then
					    --dividend less than shifted divisor, we can't substract it
						if unsigned(upscaled_dividend) < unsigned(shifted_divisor) then 
							dividend_stages(i) <= dividend_stages(i-1); 
							stagequot := 0;
						else --substracting
							dividend_stages(i) <= std_logic_vector(unsigned(dividend_stages(i-1)) - resize(unsigned(shifted_divisor), DIVIDEND_WIDTH));
							stagequot := 1;
						end if;
						quotient_stages(i) <= std_logic_vector(shift_left(unsigned(quotient_stages(i-1)), 1) + stagequot);
						divisor_stages(i) <= divisor_stages(i-1); --keep same value
						stage_full(i) <= stage_full(i-1);
						stage_flags(i) <= stage_flags(i-1);
						stage_negative(i) <= stage_negative(i-1);
					end if;
				end if;
			end process;
	end generate;
	
	axis_out_valid	 	<= stage_full(STAGES);
	axis_out_quotient 	<= std_logic_vector(quotient_stages(STAGES)) when stage_negative(STAGES) = '0' else std_logic_vector(-signed(quotient_stages(STAGES)));
	axis_out_remainder	<= std_logic_vector(resize(unsigned(dividend_stages(STAGES)), DIVIDEND_WIDTH)); --should be only this wide
	axis_out_flags 		<= stage_flags(STAGES);
	

end Behavioral;
