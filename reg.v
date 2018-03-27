// Clocked register with enable signal and synchronous reset
// Default width is 8, but can be overriden
module cenrreg(out, in, enable, reset, resetval, clock);
	parameter width = 8;
  	output [width-1:0] out;
 	reg    [width-1:0] out;
	input  [width-1:0] in;
	input              enable;
	input              reset;
  	input  [width-1:0] resetval;
  	input              clock;
  	always @(posedge clock)
		begin
	  	if (reset)  //Synchronous Reset
			out <= resetval;
	  	else if (enable)
			out <= in;
		end
endmodule

// Clocked register with enable signal
// Default width is 8
module cenreg(out, in, enable, clock);
  	parameter width = 8;
  	output [width-1:0] out;
  	input [width-1:0] in;
  	input enable;
  	input clock;
  	cenrreg #(width) c(out, in, enable, 1`b0, 8`b0, clock);
endmodule // cenreg

// Basic creg
module creg(out, in);
  	parameter width = 8;
  	output [width-1:0] out;
  	input [width-1:0] in;
  	cenreg #(width) r(out, in, 1`b1, clock);
endmodule // creg

