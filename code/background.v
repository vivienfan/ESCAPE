// Background image display
module background
 (
  CLOCK_50,      // On Board 50 MHz
  VGA_CLK,         // VGA Clock
  VGA_HS,       // VGA H_SYNC
  VGA_VS,       // VGA V_SYNC
  VGA_BLANK,      // VGA BLANK
  VGA_SYNC,      // VGA SYNC
  VGA_R,         // VGA Red[9:0]
  VGA_G,        // VGA Green[9:0]
  VGA_B,
  KEY
 );
	input CLOCK_50;
	input [3:0]KEY;// 50 MHz
	output VGA_CLK;       // VGA Clock
	output VGA_HS;     // VGA H_SYNC
	output VGA_VS;     // VGA V_SYNC
	output VGA_BLANK;    // VGA BLANK
	output VGA_SYNC;    // VGA SYNC
	output [9:0] VGA_R;      // VGA Red[9:0]
	output [9:0] VGA_G;    // VGA Green[9:0]
	output [9:0] VGA_B;      // VGA Blue[9:0]
 
	wire resetn;
	assign resetn=KEY[0];
	reg[2:0] color;
	reg[7:0] x;
	reg[6:0] y;
	reg write;


	reg [2:0] state, next_state;
	reg [3:0] done;
	integer shiftPix, EngX, EngY, counterX, counterPix, countTime;
	parameter[2:0] idle=3'b000, start=3'b001, draw=3'b010, shiftLeft=3'b011, eraseEnergy0=3'b100, eraseEnergy1=3'b101, eraseEnergy2=3'b100;
	
	wire delay_18s;
	delay_1_8_sec delay0(CLOCK_50, delay_18s);
	
	always@(*)
	begin
		case(state)
			idle: 
				next_state = start;
			start:
				next_state = draw;
			draw:
				if(delay_18s) next_state = shiftLeft;
				else next_state = draw;
			shiftLeft:
				if(done[2]) next_state = eraseEnergy;
				else next_state = draw;
			eraseEnergy:
				if (done[3] && done[1]) next_state = start;
				else if(done[3] && ~done[1]) next_state = draw;
				else next_state = eraseEnergy;
			default: next_state = idle;
		endcase
	end
	
	always@(posedge CLOCK_50)
	begin
		if(state == idle)
		begin
			done = 4'b0000;
			shiftPix = 0;
			EngX = 0;
			EngY = 0;
			countTime = 0;
		end
		if(state == start)
		begin
			done[1] =0;
			done[2] = 0;
			done[3] = 0;
			counterX = 0;
			counterPix = 0;
		end
		if(state ==  draw)
		begin	
			if(~done[0])
			begin
				write <= 1;
				y <= 7'b1001111;
				counterX = counterX+1;
				counterPix = counterPix+1;
				if(counterX<161)
				begin
					if((counterPix>0) && (counterPix<9))
					begin
						x <= counterX-1;
						color <= 3'b110;
					end
					else if((counterPix>8) && (counterPix<16))
					begin	
						x <= counterX-1;
						color <= 3'b000;
					end
					else if(counterPix==16)
					begin
						x <= counterX-1;
						color <= 3'b000;
						counterPix = 0;
					end
				end
				else if(counterX==161)
				begin
					counterX = 0;
					done[0] = 1;
					write <= 0;
				end
			end
		end
		if(state == shiftLeft)
		begin			
			done[0] = 0;
			shiftPix = shiftPix + 1;
			countTime = countTime + 1;
			if(countTime==16);
			begin
				done[2] = 1;
				countTime = 0;
			end			
			if(shiftPix==16)
			begin
				done[1] = 1;
				shiftPix = 0;
			end
		end
		if(state == eraseEnergy)
		begin
			done[2] = 0;
			write <= 1;
			if(EngY<5)
			begin
				y <= EngY;
				x <= EngX;
				EngY = EngY + 1;
				color <= 3'b000;
			end
			else if(EngY == 5)
			begin
				EngY = 0;
				EngX = EngX + 1;
				done[3] = 1;
			end
		end
		state <= next_state;
	end	
	
	
	// Create an Instance of a VGA controller - "There can be only one!"
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
		.resetn(resetn),
		.clock(CLOCK_50),
		.colour(color),
		.x(x),
		.y(y),
		.plot(write),
		/* Signals for the DAC to drive the monitor. */
		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_BLANK(VGA_BLANK),
		.VGA_SYNC(VGA_SYNC),
		.VGA_CLK(VGA_CLK));
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.MONOCHROME = "FALSE";
	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	defparam VGA.BACKGROUND_IMAGE = "display.mif";  
endmodule


module delay_1_8_sec(CLOCK_50, enable);
	input CLOCK_50;
	output reg enable;
	reg [31:0] count;
 
	always @(posedge CLOCK_50)
	begin
		if(count == 32'd3_124_999) //0.0625s
		begin
			count <= 32'd0;
			enable <= 1;
		end
		else
		begin
			count <= count + 1;
			enable <= 0;
		end
	end
endmodule


