`timescale 1ns/1ns

/*
MIPI CSI RX to Parallel Bridge (c) by Gaurav Singh www.CircuitValley.com

MIPI CSI RX to Parallel Bridge is licensed under a
Creative Commons Attribution 3.0 Unported License.

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/3.0/>.
*/

/*
received 4 pixel 120bit RGB from the Debayer filter output 64bit 4pixel yuv422 
Calculation is done based on integer YUV formula from the YUV wiki page 
*/

module rgb_to_yuv(clk_i, //data changes on rising edge , latched in on falling edge
				  reset_i,
				  rgb_i,
				  rgb_valid_i,
				  yuv_o,
				  yuv_valid_o);
				  
localparam PIXEL_DEPTH = 5'd16; //10bit per color				  
localparam PIXEL_PER_CLK = 4'd4;  //4pixels per clock cycle comes , should be even
input clk_i;
input reset_i;
input [((PIXEL_DEPTH * PIXEL_PER_CLK * 3) - 1'd1):0]rgb_i;
input rgb_valid_i;

output reg [((PIXEL_PER_CLK * 2 * 8) - 1'd1):0]yuv_o;
output reg yuv_valid_o;

reg [7:0]Y[3:0]; // result 
reg [7:0]U[3:0];
reg [7:0]V[3:0];


//from YUV wiki page full swing
// Y = ((77 R + 150G + 29B + 128) >>10)
// U = ((-43R - 84G + 127B + 128) >>10) + 128
// V = ((127R -106G -21B +128) >>10) + 128

reg [23:0]not_used24; //to suppress warning from the tool 

always @(negedge  clk_i)
begin
	yuv_valid_o <= rgb_valid_i; 
	
	{not_used24,Y[0]} =  (( 77 * rgb_i[176 +: 10]) + (150 * rgb_i[160 +: 16]) + (29 * rgb_i[144  +: 16]) + 18'd128) >> 16;
	{not_used24,U[0]} = (((127 * rgb_i[144 +: 16]) - (43  * rgb_i[176 +: 16]) - (84 * rgb_i[160 +: 16]) + 18'd128) >> 16 ) + 32'd128;
	{not_used24,V[0]} = (((127 * rgb_i[176 +: 16]) - (106 * rgb_i[160 +: 16]) - (21 * rgb_i[144  +: 16]) + 18'd128) >> 16 ) + 32'd128;
	
	{not_used24,Y[1]} =  (( 77 * rgb_i[128  +: 16]) + (150 * rgb_i[112  +: 16]) + (29 * rgb_i[96  +: 16]) + 18'd128) >> 16;
	//U[1] and V[1]  not need to yuv422 sub sampling
	
	{not_used24,Y[2]} =  (( 77 * rgb_i[128 +: 16]) + (150 * rgb_i[64  +: 16]) + (29 * rgb_i[48 +: 16]) + 18'd128) >> 16;
	{not_used24,U[2]} = (((127 * rgb_i[48  +: 16]) - ( 43 * rgb_i[128 +: 16]) - (84 * rgb_i[64 +: 16]) + 18'd128) >> 16 ) + 32'd128;
	{not_used24,V[2]} = (((127 * rgb_i[128 +: 16]) - (106 * rgb_i[64  +: 16]) - (21 * rgb_i[48 +: 16]) + 18'd128) >> 16 ) + 32'd128;
	
	{not_used24,Y[3]} =  (( 77 * rgb_i[32 +: 16]) + (150 * rgb_i[16 +: 16]) + (29 * rgb_i[0 +: 16])  + 18'd128) >> 16;
	//U[3] and V[3]  not need to yuv422 sub sampling

	yuv_o <= { Y[0], U[0], Y[1], V[0],		Y[2], U[2], Y[3], V[2]};
	
end

endmodule