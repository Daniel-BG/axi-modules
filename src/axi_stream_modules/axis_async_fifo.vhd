----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    AXIS_FIFO - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Asnycrhonous FIFO with two clocks (one on input, one on output)
-- using gray codes for pointer syncrhonization
-- idea from: https://zipcpu.com/blog/2018/07/06/afifo.html
-- 		 and: http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf
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
use ieee.numeric_std.all;

entity AXIS_ASYNC_FIFO is
	Generic (
		DATA_WIDTH: positive := 16;
		FIFO_DEPTH_LOG: positive := 10;
		ALMOST_FULL_THRESHOLD: positive := 100;
		ALMOST_EMPTY_THRESHOLD: positive := 100
	);
	Port ( 
		--reset
		rst						: in  STD_LOGIC;
		--input ctrl signals
		axis_in_clk				: in  STD_LOGIC;
		--input axi port
		axis_in_valid			: in  STD_LOGIC;
		axis_in_ready			: out STD_LOGIC;
		axis_in_data			: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		axis_in_almost_full		: out STD_LOGIC;
		axis_in_full			: out STD_LOGIC;
		--output ctrl signals
		axis_out_clk			: in  STD_LOGIC;
		--output axi port
		axis_out_ready			: in  STD_LOGIC;
		axis_out_data			: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		axis_out_valid			: out STD_LOGIC;
		axis_out_almost_empty	: out STD_LOGIC;
		axis_out_empty			: out STD_LOGIC
		
	);
end AXIS_ASYNC_FIFO;

architecture Behavioral of AXIS_ASYNC_FIFO is
	type memory_t is array(0 to 2**FIFO_DEPTH_LOG - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;

	--WRITE SIGNALS
	signal in_ptr, in_ptr_next, in_gray, in_gray_next, in_xout_gray, in_xout_meta_gray, in_xout_ptr: std_logic_vector(FIFO_DEPTH_LOG downto 0);
	signal in_addr: std_logic_vector(FIFO_DEPTH_LOG - 1 downto 0);
	signal axis_in_inner_ready: std_logic;

	signal in_full, in_full_next, in_almost_full, in_almost_full_next: std_logic;

	--READ SIGNALS
	signal out_ptr, out_ptr_next, out_gray, out_gray_next, out_xin_gray, out_xin_meta_gray, out_xin_ptr: std_logic_vector(FIFO_DEPTH_LOG downto 0);
	signal out_addr: std_logic_vector(FIFO_DEPTH_LOG - 1 downto 0);
	signal axis_out_inner_valid: std_logic;
	
	signal out_empty, out_empty_next, out_axis_out_almost_empty, out_axis_out_almost_empty_next: std_logic;

	--FUNCTIONS
	function f_gray_2_bin (gray_stdlv: in std_logic_vector) return std_logic_vector is
		variable output: std_logic_vector(gray_stdlv'range);
	begin
		output(gray_stdlv'high) := gray_stdlv(gray_stdlv'high);
		for i in gray_stdlv'high - 1 downto 0 loop
			output(i) := output(i + 1) xor gray_stdlv(i);
		end loop;
		return output;
	end;
	
	function f_bin_2_gray (bin_stdlv: in std_logic_vector) return std_logic_vector is
		variable output: std_logic_vector(bin_stdlv'range);
	begin
		output := bin_stdlv xor ("0" & bin_stdlv(bin_stdlv'high - 1 downto 0));
		return output;
	end;

begin

	----------------------------------------------------------------------------
	--- WRITE LOGIC
	----------------------------------------------------------------------------

	out_ptr_cross_clock: process(axis_in_clk, rst)
	begin
		if rst = '1' then
			in_xout_gray <= (others => '0');
			in_xout_meta_gray <= (others => '0');
			in_xout_ptr <= (others => '0');
		else
			if rising_edge(axis_in_clk) then
				in_xout_gray <= in_xout_meta_gray;
				in_xout_meta_gray <= out_gray;
				in_xout_ptr <= f_gray_2_bin(in_xout_gray);
			end if;
		end if;
	end process;

	in_ptr_next <= std_logic_vector(unsigned(in_ptr) + 1) 
		when axis_in_valid = '1' and axis_in_inner_ready = '1' 
		else in_ptr;

	update_gray_in: process(in_ptr_next) begin
		in_gray_next <= f_bin_2_gray(in_ptr_next);
	end process;

	in_addr <= in_ptr(FIFO_DEPTH_LOG - 1 downto 0);

	assign_next_in_ptr: process(axis_in_clk, rst)
	begin
		if rst = '1' then
			in_ptr <= (others => '0');
			in_gray <= (others => '0');
		else
			if rising_edge(axis_in_clk) then
				in_ptr <= in_ptr_next;
				in_gray <= in_gray_next;
			end if;
		end if;
	end process;

	in_full_next <= '1' when in_gray_next(FIFO_DEPTH_LOG 	 downto FIFO_DEPTH_LOG - 1) = not in_xout_gray(FIFO_DEPTH_LOG 	  downto FIFO_DEPTH_LOG - 1)
						and  in_gray_next(FIFO_DEPTH_LOG - 2 downto 				 0) =     in_xout_gray(FIFO_DEPTH_LOG - 2 downto 				  0)
					else '0';
	in_almost_full_next <= '1' when unsigned(in_ptr) - unsigned(in_xout_ptr) >= to_unsigned(ALMOST_FULL_THRESHOLD, FIFO_DEPTH_LOG + 1) else '0'; 
	

	assign_next_full: process(axis_in_clk, rst) 
	begin
		if rst = '1' then
			in_full <= '0';
			in_almost_full <= '0';
		else
			if rising_edge(axis_in_clk) then
				in_full <= in_full_next;
				in_almost_full <= in_almost_full_next;
			end if;
		end if;
	end process;

	axis_in_inner_ready <= not in_full;
	axis_in_ready <= axis_in_inner_ready;
	axis_in_almost_full <= in_almost_full;
	axis_in_full <= in_full;

	write_to_mem: process(axis_in_clk)
	begin
		if rising_edge(axis_in_clk) then
			if axis_in_inner_ready = '1' and axis_in_valid = '1' then
				memory(to_integer(unsigned(in_addr))) <= axis_in_data;
			end if;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- READ LOGIC
	----------------------------------------------------------------------------

	in_ptr_cross_clock: process(axis_out_clk, rst)
	begin
		if rst = '1' then
			out_xin_gray <= (others => '0');
			out_xin_meta_gray <= (others => '0');
			out_xin_ptr <= (others => '0');
		elsif rising_edge(axis_out_clk) then
			out_xin_gray <= out_xin_meta_gray;
			out_xin_meta_gray <= in_gray;
			out_xin_ptr <= f_gray_2_bin(out_xin_gray);
		end if;
	end process;

	out_ptr_next <= std_logic_vector(unsigned(out_ptr) + 1) 
		when axis_out_ready = '1' and axis_out_inner_valid = '1' 
		else out_ptr;

	update_gray_out: process(out_ptr_next) begin
		out_gray_next <= f_bin_2_gray(out_ptr_next);
	end process;

	out_addr <= out_ptr(FIFO_DEPTH_LOG - 1 downto 0);

	assign_next_out_ptr: process(axis_out_clk, rst)
	begin
		if rst = '1' then
			out_ptr <= (others => '0');
			out_gray <= (others => '0');
		else
			if rising_edge(axis_out_clk) then
				out_ptr <= out_ptr_next;
				out_gray <= out_gray_next;
			end if;
		end if;
	end process;

	out_empty_next <= '1' when out_gray_next(FIFO_DEPTH_LOG) = out_xin_gray(FIFO_DEPTH_LOG) else '0';
	out_axis_out_almost_empty_next <= '1' when unsigned(out_xin_ptr) - unsigned(out_ptr) <= to_unsigned(ALMOST_EMPTY_THRESHOLD, FIFO_DEPTH_LOG + 1) else '0';

	assign_next_empty: process(axis_out_clk, rst) 
	begin
		if rst = '1' then
			out_empty <= '1';
			out_axis_out_almost_empty <= '1';
		else
			if rising_edge(axis_out_clk) then
				out_empty <= out_empty_next;
				out_axis_out_almost_empty <= out_axis_out_almost_empty_next; 
			end if;
		end if;
	end process;

	axis_out_inner_valid <= not out_empty;
	axis_out_valid <= axis_out_inner_valid;
	axis_out_almost_empty <= out_axis_out_almost_empty;
	axis_out_empty <= out_empty;

	axis_out_data <= memory(to_integer(unsigned(out_addr)));

end Behavioral;




--	signal in_full, out_empty: std_logic;
--
--	signal inner_axis_in_ready, inner_axis_out_valid: std_logic;
--
--
--	in_gray 	<= in_ptr 	xor ("0" & 	in_ptr ( in_ptr'high downto 1));
--	out_gray  	<= out_ptr  xor ("0" &  out_ptr(out_ptr'high downto 1));
--
--
--
--	out_empty <= '1' when (out_gray = out_xin_gray) else '0';
--	in_full   <= '1' when (in_gray(FIFO_DEPTH_LOG) /= in_xout_gray(FIFO_DEPTH_LOG)) and
--						  (in_gray(FIFO_DEPTH_LOG - 1 downto 0) = in_xout_gray(FIFO_DEPTH_LOG - 1 downto 0))
--				 else '0';
--
--	inner_axis_in_ready <= not in_full;
--	axis_in_ready <= inner_axis_in_ready;
--	input_values: process(axis_in_rst, axis_in_clk)
--	begin
--		if rising_edge(axis_in_clk) then
--			if axis_in_rst = '1' then
--				in_ptr <= (others => '0');
--			else
--				if inner_axis_in_ready = '1' and axis_in_valid = '1' then
--					memory(to_integer(unsigned(in_ptr(FIFO_DEPTH_LOG - 1 downto 0)))) <= axis_in_data;
--					in_ptr <= std_logic_vector(unsigned(in_ptr) + 1);
--				end if;
--			end if;
--		end if;
--	end process;
--
--	inner_axis_out_valid <= not out_empty;
--	axis_out_valid <= inner_axis_out_valid;
--	axis_out_data <= memory(to_integer(unsigned(out_ptr(FIFO_DEPTH_LOG - 1 downto 0))));
--	output_values: process(axis_out_rst, axis_out_clk)
--	begin
--		if rising_edge(axis_out_clk) then
--			if axis_out_rst = '1' then
--				out_ptr <= (others => '0');
--			else
--				if inner_axis_out_valid = '1' and axis_out_ready = '1' then
--					out_ptr <= std_logic_vector(unsigned(out_ptr) + 1);
--				end if;
--			end if;
--		end if;
--	end process;