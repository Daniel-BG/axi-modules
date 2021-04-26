`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:00:40
// Design Name: 
// Module Name: helper_axis_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Simple data reader for AXIS bus (taking values from file)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module helper_axis_reader(
	clk, rst, enable,
	output_valid, output_data, output_ready
);
	parameter DATA_WIDTH=10;
	parameter FILE_NAME = null;
	parameter SKIP = 0;
	parameter BINARY = 0;

	//file stuff
	int fd; // file descriptor
	int status; //status for file reads
	reg [DATA_WIDTH-1:0] value; //values read from file go here
	string errorMsg;
	////
	
	input					clk, rst, enable;
	output 					output_valid;
	output [DATA_WIDTH-1:0]	output_data;
	input					output_ready;

	reg output_valid_pre;

	assign output_data  = value;
	assign output_valid = output_valid_pre & enable;
	

	always @(posedge clk) begin
		if (rst == 1) begin
			$fclose(fd);
			if (BINARY == 0) begin
				fd = $fopen(FILE_NAME, "r");
			end else begin
				fd = $fopen(FILE_NAME, "rb");
			end;
			if (!fd) begin
				$error("Error when opening file");
			end;
			//SKIP+1 so that value loads the first value already
			for (int i = 0; i < SKIP + 1; i++) begin
				if (BINARY == 0) begin
					status = $fscanf(fd, "%d", value);
				end else begin
					status = $fread(value, fd);
				end;
				if (status != 1) begin
					//$ferror(fd, errorMsg);
					$error("Error when reading file (skipping values): %d ", status);
				end;
			end
			output_valid_pre = 1;
		end else if (output_valid_pre == 1 && output_ready == 1 && enable == 1) begin
			if ($feof(fd)) begin
				output_valid_pre = 0;
				$info("End of file reached! %s", FILE_NAME);
			end else begin
				if (BINARY == 0) begin
					status = $fscanf(fd, "%d", value);
				end else begin
					status = $fread(value, fd);
				end;
				if (status != 1) begin
					if ($feof(fd)) begin 
						$info("End of file reached! %s", FILE_NAME);
					end else begin
						$error("Unknown when reading file: %s", FILE_NAME);
					end 
					output_valid_pre = 0;
				end 
			end
		end
	end

endmodule

