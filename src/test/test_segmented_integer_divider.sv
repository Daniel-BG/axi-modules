`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/16/2023 02:16:21 PM
// Design Name: 
// Module Name: test_segmented_integer_divider
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



module test_segmented_integer_divider();

    parameter DIVIDEND_WIDTH = 5;
    parameter DIVISOR_WIDTH = 3;
    parameter FLAG_WIDTH = 10;
    
    reg clk, rst;
    
    reg [DIVIDEND_WIDTH - 1:0] axis_in_dividend;
    reg [DIVISOR_WIDTH - 1:0] axis_in_divisor;
    wire axis_in_ready;
    wire axis_in_valid;
    reg [FLAG_WIDTH - 1:0] axis_in_flags;
    
    
    wire [DIVIDEND_WIDTH - 1:0] axis_out_quotient;
    wire [DIVIDEND_WIDTH - 1:0] axis_out_remainder;
    wire axis_out_ready;
    wire axis_out_valid;
    wire [FLAG_WIDTH - 1:0] axis_out_flags;
    
    
    axis_segmented_integer_divider #(.DIVIDEND_WIDTH(DIVIDEND_WIDTH), .DIVISOR_WIDTH(DIVISOR_WIDTH), .FLAG_WIDTH(FLAG_WIDTH)) dut (
        .clk(clk), .rst(rst),
		.axis_in_dividend(axis_in_dividend),
		.axis_in_divisor(axis_in_divisor), 
		.axis_in_ready(axis_in_ready),
		.axis_in_valid(axis_in_valid),
		.axis_in_flags(axis_in_flags),
		.axis_out_quotient(axis_out_quotient),
		.axis_out_remainder(axis_out_remainder),
		.axis_out_ready(axis_out_ready),
		.axis_out_valid(axis_out_valid),
		.axis_out_flags(axis_out_flags)
    );
	   	
	
   	always #10 clk <= ~clk;
   	
   	initial begin
   	    clk <= 0;
   	    axis_in_dividend <= 0;
   	    axis_in_divisor <= 0;
   	    axis_in_flags <= 0;
   	    #5 rst <= 0;
   	    #20 rst <= 1;
   	    #400 rst <= 0;
   	end
   	
   	
   	assign axis_in_valid = 1;
   	assign axis_out_ready = 1;
   	
   	always @(posedge clk) begin
   	    axis_in_dividend <= axis_in_dividend + 1;
   	    axis_in_divisor <= axis_in_divisor + 1;
   	    axis_in_flags <= axis_in_flags + 1;
   	end

   	
endmodule
