module final_project(
    input clk,
    input rst,
    inout PS2_CLK,
    inout PS2_DATA,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output hsync,
    output vsync,
    output audio_mclk,
    output audio_lrck, 
    output audio_sck,
    output audio_sdin
);
// THE DECLARATION ABOUT THE PICTURE AND DISPLAY OUTPUT

reg [15:0]p1_x,p1_y; //LEFT
reg [15:0]p2_x,p2_y; //RIGHT
reg [15:0]ball_x,ball_y;
reg [15:0]next_p1_x,next_p1_y; //LEFT
reg [15:0]next_p2_x,next_p2_y; //RIGHT
reg [15:0]next_ball_x,next_ball_y;

parameter [8:0] p1_right_key = 9'b0_0011_0100; //G:34
parameter [8:0] p1_left_key = 9'b0_0010_0011;//D:23 
parameter [8:0] p1_up_key = 9'b0_0010_1101;  //R:2D
parameter [8:0] p1_down_key = 9'b0_0010_1011; //F:2B
parameter [8:0] p2_right_key = 9'b0_0111_1010; // 3: 7A
parameter [8:0] p2_left_key = 9'b0_0110_1001; //1: 69 
parameter [8:0] p2_up_key = 9'b0_0111_0011; // 5: 73
parameter [8:0] p2_down_key = 9'b0_0111_0010; //2: 72
wire key_valid;
wire [8:0]last_change;
wire [511:0] key_down;

KeyboardDecoder kbd(
    .key_down(key_down),
	.last_change(last_change),
	.key_valid(key_valid),
	.PS2_DATA(PS2_DATA),
	.PS2_CLK(PS2_CLK),
	.rst(rst),
	.clk(clk)
);

always@(posedge clk,posedge rst)begin
    if(rst)begin
        p1_x=70;
        p1_y=180;
        ball_x=160;
        ball_y=40;
        p2_x=250;
        p2_y=180;
    end else begin
        p1_x=next_p1_x;
        p2_x=next_p2_x;
        p1_y=next_p1_y;
        p2_y=next_p2_y;
        ball_x=next_ball_x;
        ball_y=next_ball_y;
    end
end

wire p1_move_left,p1_move_right,p2_move_left,p2_move_right;
wire p1_up_1p,p1_down_1p,p2_up_1p,p2_down_1p;

handle_keypressed move_left_right_handle(.clk(clk), .rst(rst), .pl_l(key_down[p1_left_key]),
    .p1_r(key_down[p1_right_key]), .p2_l(key_down[p2_left_key]), .p2_r(key_down[p2_right_key]), 
    .p1_l_cmd(p1_move_left), .p1_r_cmd(p1_move_right), .p2_l_cmd(p2_move_left), .p2_r_cmd(p2_move_right)
);

jump_control jp(.clk(clk), .rst(rst), .p1_y(p1_y), .p2_y(p2_y), .p1_u(key_down[p1_up_key]),
    .p2_u(key_down[p2_up_key]), .p1_up_cmd(p1_up_1p), .p1_drop_cmd(p1_down_1p), .p2_up_cmd(p2_up_1p),
    .p2_drop_cmd(p2_down_1p)
);

always@(*)begin
    next_p1_y=p1_y;
    if(p1_up_1p) next_p1_y=p1_y-1;
    else if(p1_down_1p) next_p1_y=p1_y+1;
end

always@(*)begin
    next_p2_y=p2_y;
    if(p2_up_1p) next_p2_y=p2_y-1;
    else if(p2_down_1p) next_p2_y=p2_y+1;
end

always@(*)begin
    next_p1_x=p1_x; 
    if(p1_move_left && p1_x>=28) next_p1_x=p1_x-1;
    else if(p1_move_right && p1_x<= 160-28) next_p1_x=p1_x+1;
end
always@(*)begin
    next_p2_x=p2_x; 
    if(p2_move_left && p2_x>=160+28) next_p2_x=p2_x-1;
    else if(p2_move_right && p2_x<=320-28) next_p2_x=p2_x+1;
end

always@(*)begin
    next_ball_x=160;
    next_ball_y=40;
end

//-----------------------------------------------------------------begin display--------------------------------------------------------//
display_final display_part(.clk(clk), .rst(rst), .p1_x(p1_x) , .p1_y(p1_y) , .p2_x(p2_x), .p2_y(p2_y), .ball_x(ball_x), .ball_y(ball_y),
.vgaRed(vgaRed), .vgaGreen(vgaGreen), .vgaBlue(vgaBlue),.hsync(hsync),.vsync(vsync));
//-----------------------------------------------------------------end display----------------------------------------------------------//

//-------------------------------------------------------------begin music part -------------------------------------------------------//
// declaration 
music_final music_part( .clk(clk), .rst(rst), .audio_mclk(audio_mclk), .audio_lrck(audio_lrck), .audio_sck(audio_sck), .audio_sdin(audio_sdin));
//-------------------------------------------------------------end music part -------------------------------------------------------//
endmodule


