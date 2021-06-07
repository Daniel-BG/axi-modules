--------------------------------------------------------------------------------
-- Title       : <Title Block>
-- Project     : Default Project Name
--------------------------------------------------------------------------------
-- File        : AXIS_ASYNC_FIFO_tb.vhd
-- Author      : User Name <user.email@user.company.com>
-- Company     : User Company Name
-- Created     : Wed Jun  2 12:47:58 2021
-- Last update : Wed Jun  2 12:51:52 2021
-- Platform    : Default Part Number
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Copyright (c) 2021 User Company Name
-------------------------------------------------------------------------------
-- Description: 
--------------------------------------------------------------------------------
-- Revisions:  Revisions and documentation are controlled by
-- the revision control system (RCS).  The RCS should be consulted
-- on revision history.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.ccsds_test_constants.all;


-----------------------------------------------------------

entity AXIS_ASYNC_FIFO_tb is

end entity AXIS_ASYNC_FIFO_tb;

-----------------------------------------------------------

architecture testbench of AXIS_ASYNC_FIFO_tb is

	-- Testbench DUT generics
	constant DATA_WIDTH             : positive := 16;
	constant FIFO_DEPTH_LOG         : positive := 10;
	constant ALMOST_FULL_THRESHOLD  : positive := 100;
	constant ALMOST_EMPTY_THRESHOLD : positive := 100;

	-- Testbench DUT ports
	signal rst                   : STD_LOGIC;
	signal axis_in_clk           : STD_LOGIC;
	signal axis_in_valid         : STD_LOGIC;
	signal axis_in_ready         : STD_LOGIC;
	signal axis_in_data          : STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
	signal axis_in_almost_full   : STD_LOGIC;
	signal axis_in_full          : STD_LOGIC;
	signal axis_out_clk          : STD_LOGIC;
	signal axis_out_ready        : STD_LOGIC;
	signal axis_out_data         : STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
	signal axis_out_valid        : STD_LOGIC;
	signal axis_out_almost_empty : STD_LOGIC;
	signal axis_out_empty        : STD_LOGIC;

	-- Other constants
--	constant C_IN_CLK_PERIOD : real := 3.333e-9; -- NS
--	constant C_OUT_CLK_PERIOD : real := 10.0e-9; -- NS
	
	constant C_IN_CLK_PERIOD : real := 10.0e-9; -- NS
	constant C_OUT_CLK_PERIOD : real := 3.333e-9; -- NS
	
	signal input_enable: std_logic;

begin
	-----------------------------------------------------------
	-- Clocks and Reset
	-----------------------------------------------------------
	CLK_IN_GEN : process
	begin
		axis_in_clk <= '1';
		wait for C_IN_CLK_PERIOD / 2.0 * (1 SEC);
		axis_in_clk <= '0';
		wait for C_IN_CLK_PERIOD / 2.0 * (1 SEC);
	end process CLK_IN_GEN;

	CLK_OUT_GEN : process
	begin
		axis_out_clk <= '1';
		wait for C_OUT_CLK_PERIOD / 2.0 * (1 SEC);
		axis_out_clk <= '0';
		wait for C_OUT_CLK_PERIOD / 2.0 * (1 SEC);
	end process ; -- CLK_OUT_GEN

	RESET_GEN : process
	begin
		rst <= '1',
		         '0' after 20.0*C_IN_CLK_PERIOD * (1 SEC);
		wait;
	end process RESET_GEN;

	-----------------------------------------------------------
	-- Testbench Stimulus
	-----------------------------------------------------------

	input_enable_proc: process
	begin
		input_enable <= '0';
		wait until rst = '0';
		wait until rising_edge(axis_in_clk);
		input_enable <= '1';
		wait;
	end process;

	INPUTTER: entity work.reader_wrapper
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			SKIP => 0,
			FILE_NUMBER => CONST_GOLDEN_NUM_S
		)
		port map (
			clk => axis_in_clk, rst => rst, 
			enable => input_enable,
			output_valid => axis_in_valid,
			output_ready => axis_in_ready,
			output_data  => axis_in_data
		);

	
	TEST_CHECK: entity work.checker_wrapper
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			SKIP => 0,
			FILE_NUMBER => 0
		)
		port map (
			clk => axis_out_clk, rst => rst, 
			valid => axis_out_valid,
			ready => axis_out_ready,
			data  => axis_out_data
		);
		
	ready_gen: process
	begin
		axis_out_ready <= '0';
		wait until rst = '0';
		wait for C_OUT_CLK_PERIOD * 10.0 * (1 SEC);
		wait until rising_edge(axis_out_clk);
		axis_out_ready <= '1';
		wait;
	end process;

	-----------------------------------------------------------
	-- Entity Under Test
	-----------------------------------------------------------
	DUT : entity work.AXIS_ASYNC_FIFO
		generic map (
			DATA_WIDTH             => DATA_WIDTH,
			FIFO_DEPTH_LOG         => FIFO_DEPTH_LOG,
			ALMOST_FULL_THRESHOLD  => ALMOST_FULL_THRESHOLD,
			ALMOST_EMPTY_THRESHOLD => ALMOST_EMPTY_THRESHOLD
		)
		port map (
			rst                   => rst,
			axis_in_clk           => axis_in_clk,
			axis_in_valid         => axis_in_valid,
			axis_in_ready         => axis_in_ready,
			axis_in_data          => axis_in_data,
			axis_in_almost_full   => axis_in_almost_full,
			axis_in_full          => axis_in_full,
			axis_out_clk          => axis_out_clk,
			axis_out_ready        => axis_out_ready,
			axis_out_data         => axis_out_data,
			axis_out_valid        => axis_out_valid,
			axis_out_almost_empty => axis_out_almost_empty,
			axis_out_empty        => axis_out_empty
		);

end architecture testbench;