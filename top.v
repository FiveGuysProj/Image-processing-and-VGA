`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2019 07:29:32 PM
// Design Name: 
// Module Name: top
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


module top(
    input wire [1:0] Sel,  // Selects for the output image
    input wire CLK,             // board clock: 100 MHz on Arty/Basys3/Nexys
    input wire RST_BTN,         // reset button
    input wire [3:0] UI,        //user input for image processing
    input wire [1:0] RGB,
    output wire VGA_HS_O,       // horizontal sync output
    output wire VGA_VS_O,       // vertical sync output
    output reg [3:0] VGA_R,     // 4-bit VGA red output
    output reg [3:0] VGA_G,     // 4-bit VGA green output
    output reg [3:0] VGA_B      // 4-bit VGA blue output
    );

     wire rst = RST_BTN;  // reset is active high on Basys3 (BTNC)

    // generate a 25 MHz pixel strobe
    reg [15:0] cnt;
    reg pix_stb;
    always @(posedge CLK)
        {pix_stb, cnt} <= cnt + 16'h4000;  // divide by 4: (2^16)/4 = 0x4000

    wire [9:0] x;  // current pixel x position: 10-bit value: 0-1023
    wire [8:0] y;  // current pixel y position:  9-bit value: 0-511
    wire active;   // high during active pixel drawing

    vga640x360 display (
        .i_clk(CLK), 
        .i_pix_stb(pix_stb),
        .i_rst(rst),
        .o_hs(VGA_HS_O), 
        .o_vs(VGA_VS_O), 
        .o_x(x), 
        .o_y(y),
        .o_active(active)
    );

    // VRAM frame buffers (read-write)
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 360;
    localparam VRAM_DEPTH = SCREEN_WIDTH * SCREEN_HEIGHT; 
    localparam VRAM_A_WIDTH = 18;  // 2^18 > 640 x 360
    localparam VRAM_D_WIDTH = 6;   // colour bits per pixel

    // 3 wires go into mux  
    // 1 image outputted at a time
    reg [VRAM_A_WIDTH-1:0] address;
    wire [VRAM_D_WIDTH-1:0] dataout2; //Artoria.mem
    wire [VRAM_D_WIDTH-1:0] dataout1; //game.mem

    sram #(
        .ADDR_WIDTH(VRAM_A_WIDTH), 
        .DATA_WIDTH(VRAM_D_WIDTH), 
        .DEPTH(VRAM_DEPTH), 
        .MEMFILE("game.mem"))  // bitmap to load
        vram (
        .i_addr(address), 
        .i_clk(CLK), 
        .i_write(0),  // we're always reading
        .i_data(0), 
        .o_data(dataout1)   //load game.mem to dataout1
    );
    sram #(
        .ADDR_WIDTH(VRAM_A_WIDTH), 
        .DATA_WIDTH(VRAM_D_WIDTH), 
        .DEPTH(VRAM_DEPTH), 
        .MEMFILE("seiba.mem"))  // bitmap to load
        vram2 (
        .i_addr(address), 
        .i_clk(CLK), 
        .i_write(0),  // we're always reading
        .i_data(0), 
        .o_data(dataout2)   //load the seiba picture to dataout2
    );
    reg [11:0] palette1 [0:63];  // 64 x 12-bit colour palette entries (all 4 are mostly identical. Multiple created for debugging purposes)
	reg [11:0] palette2 [0:63];
 	reg [11:0] palette3 [0:63];
 	reg [11:0] palette4 [0:63];
	reg [11:0] colour;
    always@(posedge CLK) begin
        address <= y * SCREEN_WIDTH + x;
        if(active) // pixel drawing time
            case(Sel)
                2'b00: begin      
                        $display("Loading palette1.");
                        $readmemh("game_palette.mem", palette1);  // load game palette
                        colour <= palette1[dataout1];   //generate game.mem with game_palette.mem
                       end
                2'b01: begin
                        $display("Loading palette2.");
                        $readmemh("seiba_palette.mem", palette2);  // load seiba palette
                        colour <= palette2[dataout2];   //generate seiba.mem with seiba_palette.mem
                       end
                2'b10: begin
                        $display("Loading palette3.");
                        $readmemh("dig_palette.mem", palette3); //load dig palette for encryption
                        colour <= palette3[dataout1];   //generate game.mem with dig_palette.mem    (Encrypting game.mem)
                       end
                2'b11:begin 
                        $display("Loading palette3.");
                        $readmemh("Artoria_palette.mem", palette4); //load Artoria palette for encryption
                        colour <= palette4[dataout2];   //generate seiba.mem with Artoria_palette.mem (Encrypting seiba.mem)
                      end
            endcase
        else
        colour <= 0;
        case(RGB)
        2'b00: 
            begin
            VGA_R <= colour[11:8];  //default picture
            VGA_G <= colour[7:4];
            VGA_B <= colour[3:0];
            end
        2'b01: 
            begin
            VGA_R <= 16 - colour[11:8];  //invert colors
            VGA_G <= 16 - colour[7:4];
            VGA_B <= 16 - colour[3:0];
            end
        2'b10: 
            begin
            VGA_R <= (colour[11:8] + colour[7:4] + colour[3:0])/3;  //greyscale
            VGA_G <= (colour[11:8] + colour[7:4] + colour[3:0])/3;
            VGA_B <= (colour[11:8] + colour[7:4] + colour[3:0])/3;
            end
        2'b11:
            begin
            VGA_R <= colour[11:8]*UI == 0 ? colour[11:8] : (colour[11:8]*UI < 16 ? colour[11:8]*UI : 15);  //increase brightness
            VGA_G <= colour[7:4]* UI == 0 ? colour[7:4] : (colour[7:4]*UI < 16 ? colour[7:4]*UI : 15);
            VGA_B <= colour[3:0]*UI == 0 ? colour[3:0] : (colour[3:0]*UI < 16 ? colour[3:0]*UI : 15);
            end        
       default: 
            begin
            VGA_R <= colour[11:8];
            VGA_G <= colour[7:4]; 
            VGA_B <= colour[3:0];
            end
        endcase
    end
endmodule