`timescale 1ns/1ns

/*
MIPI CSI RX to Parallel Bridge (c) by Gaurav Singh www.CircuitValley.com

MIPI CSI RX to Parallel Bridge is licensed under a
Creative Commons Attribution 3.0 Unported License.

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/3.0/>.
*/

/*
Receives 4 lane raw mipi bytes from packet decoder, rearrange bytes to output 4 pixel 10bit each 
output is one clock cycle delayed, because the way , MIPI RAW10 is packed 
output come in group of 5x40bit chunk on each clock cycle, output_valid_o remains active only while 20 pixel chunk is outputted 
*/

module mipi_rx_raw_depacker(	clk_i,
								data_valid_i,
								data_i,
								packet_type_i,
								output_valid_o,
								output_o);

localparam [2:0]TRANSFERS_PERCHUNK= 3'h5; // RAW 10 is packed <Sample0[9:2]> <Sample1[9:2]> <Sample2[9:2]> <Sample3[9:2]> <Sample0[1:0],Sample1[1:0],Sample2[1:0],Sample3[1:0]>
localparam [7:0]MIPI_CSI_PACKET_10bRAW = 8'h2B;
localparam [7:0]MIPI_CSI_PACKET_12bRAW = 8'h2C;
localparam [7:0]MIPI_CSI_PACKET_14bRAW = 8'h2D;

input clk_i;
input data_valid_i;
input [31:0]data_i;
input [2:0]packet_type_i;

output reg output_valid_o;
output reg [63:0]output_o; 

reg [7:0]offset;
reg [2:0]byte_count;
reg [31:0]last_data_i[2:0];
reg [1:0]idle_count;

wire [7:0]offset_factor;
wire [2:0]burst_length;
wire [1:0]idle_length;
wire [127:0]word;
assign word = {data_i,last_data_i[0], last_data_i[1], last_data_i[2]}; //would need last bytes as well as current data to get full 4 pixel

assign offset_factor = (packet_type_i == (MIPI_CSI_PACKET_10bRAW & 8'h07))? 8'd8: (packet_type_i == (MIPI_CSI_PACKET_12bRAW & 8'h07))? 8'd16: 
					   (packet_type_i == (MIPI_CSI_PACKET_14bRAW & 8'h07))? 8'd24:8'h0;
					   
assign burst_length =  ((packet_type_i == (MIPI_CSI_PACKET_10bRAW & 8'h07)) || (packet_type_i == (MIPI_CSI_PACKET_14bRAW & 8'h07)))? 8'd5: 
						(packet_type_i == (MIPI_CSI_PACKET_12bRAW & 8'h07))? 8'd3:8'h0;		   
						
assign idle_length =  ((packet_type_i == (MIPI_CSI_PACKET_10bRAW & 8'h07)) || (packet_type_i == (MIPI_CSI_PACKET_12bRAW & 8'h07)))? 2'd1: 
						(packet_type_i == (MIPI_CSI_PACKET_14bRAW & 8'h07))? 2'd3:2'h0;

reg [15:0]pixel_counter_depacker;
						
always @(posedge clk_i)
begin
	
	if (data_valid_i)
	begin
		last_data_i[0] <= data_i;
		last_data_i[1] <= last_data_i[0];
		last_data_i[2] <= last_data_i[1];
		pixel_counter_depacker <= pixel_counter_depacker + 1'b1;
		//RAW 10 , Byte1 -> Byte2 -> Byte3 -> Byte4 -> [ LSbB1[1:0] LSbB2[1:0] LSbB3[1:0] LSbB4[1:0] ]
		
		if (packet_type_i == (MIPI_CSI_PACKET_10bRAW & 8'h07))
		begin
			output_o[63:48] <= 	{word [(offset +  8'd7 + 8'd64) -:8], 	word [(offset + 8'd33 + 8'd64) -:2]} << 6; 		//lane 1 	TODO:Reverify 
			output_o[47:32] <= 	{word [(offset + 8'd15 + 8'd64) -:8], 	word [(offset + 8'd35 + 8'd64) -:2]} << 6;		
			output_o[31:16] <= 	{word [(offset + 8'd23 + 8'd64) -:8], 	word [(offset + 8'd37 + 8'd64) -:2]} << 6;
			output_o[15:0] 	<= 	{word [(offset + 8'd31 + 8'd64) -:8], 	word [(offset + 8'd39 + 8'd64) -:2]} << 6;		//lane 4
		end
		else if (packet_type_i == (MIPI_CSI_PACKET_12bRAW & 8'h07))
		begin
			output_o[63:48] <= 	{word [(offset +  8'd7 + 8'd64) -:8], 	word [(offset + 8'd19 + 8'd64) -:4]} << 4; 		//lane 1
			output_o[47:32] <= 	{word [(offset + 8'd15 + 8'd64) -:8], 	word [(offset + 8'd23 + 8'd64) -:4]} << 4;
			output_o[31:16] <= 	{word [(offset + 8'd31 + 8'd64) -:8], 	word [(offset + 8'd43 + 8'd64) -:4]} << 4;
			output_o[15:0] 	<= 	{word [(offset + 8'd39 + 8'd64) -:8], 	word [(offset + 8'd47 + 8'd64) -:4]} << 4;		//lane 4
		end
		else if (packet_type_i == (MIPI_CSI_PACKET_14bRAW & 8'h07))
		begin
			output_o[63:48] <= 	{word [(offset + 7) -:8], 	word [(offset + 37) -:6]} << 2; 		//lane 1
			output_o[47:32] <= 	{word [(offset + 15) -:8], 	word [(offset + 43) -:6]} << 2;
			output_o[31:16] <= 	{word [(offset + 23) -:8], 	word [(offset + 49) -:6]} << 2;
			output_o[15:0] 	<= 	{word [(offset + 31) -:8], 	word [(offset + 55) -:6]} << 2;		//lane 4
		end
		
		
		if (byte_count < (burst_length))
		begin
			byte_count <= byte_count + 1'd1;
			idle_count <= idle_length - 1'b1;
			if (byte_count )
			begin
				offset <= ((offset + offset_factor) & 8'h7F);
				output_valid_o <= 1'b1;
			end
		end
		else
		begin
			idle_count <= idle_count - 1'b1;
			if (!idle_count)
			begin
				byte_count <= 4'b1;		//set to 1 to enable output_valid_o with next edge
			end
			
			offset <= 8'h0;
			output_valid_o <= 1'h0;
		end

	end
	else
	begin
		pixel_counter_depacker <= 0; 
		output_o <= 40'h0;
		last_data_i[0] <= 32'h0;
		last_data_i[1] <= 32'h0;
		last_data_i[2] <= 32'h0;
		
		if (packet_type_i == (MIPI_CSI_PACKET_14bRAW & 8'h07))		// for 14bit need to wait for 3 sample while 12bit and 10bit only need 1 sample delay
		begin
			byte_count <= burst_length;
			idle_count <= idle_length - 1'b1;
		end
		else
		begin 
			byte_count <= 3'b0;	//need to bezero to wait for 1 sample after data become valid	
		end
		
		offset <= 8'h0; 
		
		output_valid_o <= 1'h0;
	end
end

endmodule