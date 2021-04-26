`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel B�scones
// 
// Create Date: 25.02.2019 12:00:40
// Design Name: 
// Module Name: inline_axis_checker
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Simple data generator for AXIS bus (used in testing)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module inline_axis_checker (
	clk, rst,
	valid, data, ready
);
	parameter DATA_WIDTH=10;
	parameter FILE_NAME = null;
	parameter SKIP = 0;
	parameter SHOW_ALL = 0;
	parameter BINARY = 0;

	input					clk, rst;
	input 					valid;
	input [DATA_WIDTH-1:0]	data;
	input					ready;


	//reader from file
	wire ref_valid, ref_ready;
	wire [DATA_WIDTH - 1:0] ref_data;
	
	int numloops;

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(FILE_NAME), .SKIP(SKIP), .BINARY(BINARY)) reference_reader
		(
			.clk         (clk),
			.rst         (rst),
			.enable      (1'b1),
			.output_valid(ref_valid),
			.output_data (ref_data),
			.output_ready(ref_ready)
		);

	//whenever a transaction is observed, we need to force one sample out of the reader
	assign ref_ready = valid & ready;

	always @(posedge clk) begin
		if (rst == 1) begin
			numloops = 0;
		end 
		if (valid == 1 && ready == 1) begin
			if (ref_valid == 1) begin
				//data should match ref_data
				if (data != ref_data || (^data === 1'bX) || $isunknown(data)) begin
					$info("Seen: 0x%h Expected: 0x%h (@ %d)", data, ref_data, numloops);
					$stop;
				end else begin
					//data matches expected value
					if (SHOW_ALL == 1) begin
						$info("Displaying info 0x%h", data); 
					end
				end
				numloops = numloops + 1;
			end else begin
				//error, we don't have data we are asking for
				$info("Data run out");
			end
		end
	end
	
	initial begin
		$info("Checker up!!"); 
	end
	
endmodule

