`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2021 17:39:55
// Design Name: 
// Module Name: axis_rom_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axis_rom_fifo
	#(
		parameter int unsigned width = 16,
  		parameter int unsigned depth = 61200,
   		parameter intFile = "pattern_in.mif"
   	)
	(
		input logic clk,
		input logic rst,
		output logic [width-1:0] axis_d,
		output logic axis_valid,
		input logic axis_ready
    );
    
    (*rom_style = "block" *) reg [width-1:0] rom [0:depth-1];
    integer pointer;
    
    reg finished;
    
    // initialise ROM contents
	initial begin
		$readmemh(intFile,rom);
	end
	
	always_ff @ (posedge clk)
	begin
		if (rst) begin
			pointer <= 0;
			finished <= 0;
		end else begin
			if (axis_ready) begin
				if (pointer == depth - 1) begin
					finished <= 1;
				end else begin
					pointer <= pointer + 1;
				end
			end 
		end
	end
	
	assign axis_d = rom[pointer];
	assign axis_valid = (~rst) && (~finished);
	
    
endmodule: axis_rom_fifo

