module display_final (
    input clk,
    input rst,
    input [15:0]p1_x,
    input [15:0]p1_y,
    input [15:0]p2_x,
    input [15:0]p2_y,
    input [15:0]ball_x,
    input [15:0]ball_y,
    output [3:0]vgaRed,
    output [3:0]vgaGreen, 
    output [3:0]vgaBlue,
    output hsync,
    output vsync
);
// THE DECLARATION ABOUT THE PICTURE AND DISPLAY OUTPUT
reg [11:0] pixel_out;

wire [11:0] pixel_background;
wire [11:0] pixel_player1;
wire [11:0] pixel_ball;
wire [11:0] pixel_player2;

wire [9:0] h_cnt; //640
wire [9:0] v_cnt;  //480
wire [11:0] data;
wire valid;

reg [16:0] pixel_addr_background;
reg [11:0] pixel_addr_player1; //64*64
reg [11:0] pixel_addr_ball; //50*50
reg [11:0] pixel_addr_player2; //64*64

wire clk_25MHz;

assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel_out:12'h0;

clock_divider_1 clk_25MHzinst(
    .clk(clk),
    .clk_25MHz(clk_25MHz)
);

vga_controller   vga_inst(
    .pclk(clk_25MHz),
    .reset(rst),
    .hsync(hsync),
    .vsync(vsync),
    .valid(valid),
    .h_cnt(h_cnt),
    .v_cnt(v_cnt)
);


blk_mem_gen_0 blk_mem_gen_0_inst( //bg
    .clka(clk_25MHz),
    .wea(0),
    .addra(pixel_addr_background),
    .dina(data[11:0]),
    .douta(pixel_background)
);
blk_mem_gen_1 blk_mem_gen_1_inst( //p1
    .clka(clk_25MHz),
    .wea(0),
    .addra(pixel_addr_player1),
    .dina(data[11:0]),
    .douta(pixel_player1)
);
blk_mem_gen_2 blk_mem_gen_2_inst( //ball
    .clka(clk_25MHz),
    .wea(0),
    .addra(pixel_addr_ball),
    .dina(data[11:0]),
    .douta(pixel_ball)
);
blk_mem_gen_3 blk_mem_gen_3_inst( //p2
    .clka(clk_25MHz),
    .wea(0),
    .addra(pixel_addr_player2),
    .dina(data[11:0]),
    .douta(pixel_player2)
);
    

always @(*) begin
    pixel_addr_background = ((h_cnt>>1)+320*(v_cnt>>1))% 76800;
end

always @(*) begin
    //draw p1
    if(pixel_out==pixel_player1)begin
        pixel_addr_player1=2080;
        if(h_cnt>>1 >= p1_x) pixel_addr_player1= pixel_addr_player1 + ((h_cnt>>1) -p1_x);
        else pixel_addr_player1= pixel_addr_player1- (p1_x - (h_cnt>>1) );
        if(v_cnt>>1 >= p1_y) pixel_addr_player1= pixel_addr_player1+ ((v_cnt>>1) -p1_y)*64;
        else pixel_addr_player1= pixel_addr_player1- (p1_y - (v_cnt>>1) )*64;
    end else begin
        pixel_addr_player1=0;
    end
end

always @(*) begin
    //draw p2
    if(pixel_out==pixel_player2)begin
        pixel_addr_player2=2080;
        if(h_cnt>>1 >= p2_x) pixel_addr_player2= pixel_addr_player2+ ((h_cnt>>1) -p2_x);
        else pixel_addr_player2= pixel_addr_player2- (p2_x - (h_cnt>>1) );
        if(v_cnt>>1 >= p2_y) pixel_addr_player2= pixel_addr_player2+ ((v_cnt>>1) -p2_y)*64;
        else pixel_addr_player2= pixel_addr_player2- (p2_y - (v_cnt>>1) )*64;
    end else begin
        pixel_addr_player2=0;
    end
end

always @(*) begin
    //draw the ball
    if(pixel_out==pixel_ball)begin
        pixel_addr_ball=1225;
        pixel_addr_ball= pixel_addr_ball+ ((h_cnt>>1) -ball_x);
        if(v_cnt>>1 >= ball_y) pixel_addr_ball= pixel_addr_ball+ ((v_cnt>>1) -ball_y)*50;
        else pixel_addr_ball= pixel_addr_ball- (ball_y - (v_cnt>>1) )*50;
    end else begin
        pixel_addr_ball=0;
    end
end

reg [30:0]dist_sq;
reg [30:0]dist_sq_to_p2;

wire ball_white;
reg [15:0] pos_ball_2500;
ball_display bd0(.pos(pos_ball_2500), .white(ball_white));

always @(*) begin
    dist_sq=0;
    if(h_cnt>>1 >= p1_x) dist_sq= dist_sq+ ((h_cnt>>1) -p1_x)*((h_cnt>>1) -p1_x);
    else dist_sq= dist_sq+ (p1_x - (h_cnt>>1) )*(p1_x - (h_cnt>>1));
    if(v_cnt>>1 >= p1_y) dist_sq= dist_sq+ ((v_cnt>>1) -p1_y)*((v_cnt>>1) -p1_y);
    else dist_sq= dist_sq+ (p1_y - (v_cnt>>1) )*(p1_y - (v_cnt>>1));  // distance between p1 and current location

    dist_sq_to_p2=0;
    if(h_cnt>>1 >= p2_x) dist_sq_to_p2= dist_sq_to_p2+ ((h_cnt>>1) -p2_x)*((h_cnt>>1) -p2_x);
    else dist_sq_to_p2= dist_sq_to_p2+ (p2_x - (h_cnt>>1) )*(p2_x - (h_cnt>>1));
    if(v_cnt>>1 >= p2_y) dist_sq_to_p2= dist_sq_to_p2+ ((v_cnt>>1) -p2_y)*((v_cnt>>1) -p2_y);
    else dist_sq_to_p2= dist_sq_to_p2+ (p2_y - (v_cnt>>1) )*(p2_y - (v_cnt>>1)); // distance between p2 and current location

    pos_ball_2500=1225;
    pos_ball_2500=pos_ball_2500+ (h_cnt>>1)-ball_x;
    if(v_cnt>>1 >= ball_y) pos_ball_2500=pos_ball_2500+((v_cnt>>1)-ball_y)*50;
    else pos_ball_2500=pos_ball_2500-(ball_y-(v_cnt>>1))*50; // index of ball (2500)

    if(dist_sq<=800) pixel_out=pixel_player1; // the display size of p1
    else if(dist_sq_to_p2<=800)pixel_out=pixel_player2; //the display size for p2
    else if(((v_cnt>>1 >= ball_y && (v_cnt>>1)-ball_y <= 25 )||(v_cnt>>1 < ball_y && ball_y-(v_cnt>>1) <= 25))
    && (((h_cnt>>1 >= ball_x && (h_cnt>>1)-ball_x <= 25 ))||(h_cnt>>1 < ball_x && ball_x-(h_cnt>>1) <= 25 )) 
    && ball_white==0) pixel_out=pixel_ball;
    else pixel_out=pixel_background;
end


endmodule