module final_project(
    input clk,
    input rst,
    inout PS2_CLK,
    inout PS2_DATA,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output hsync,
    output vsync
);
reg [11:0] pixel_out;
wire [11:0] pixel_background;
wire [11:0] pixel_player1;
wire [11:0] pixel_ball;
wire [11:0] pixel_player2;


wire [15:0] h_cnt; //640
wire [15:0] v_cnt;  //480
wire [11:0] data;
wire valid;
reg [16:0] pixel_addr_background;
reg [12:0] pixel_addr_player1; //64*64
reg [12:0] pixel_addr_ball; //50*50
reg [12:0] pixel_addr_player2; //64*64


wire ball_white;
reg [15:0] pos_ball_2500;

ball_display bd0(.pos(pos_ball_2500), .white(ball_white));

wire clk_25MHz;

reg [15:0]p1_x,p1_y; //左
reg [15:0]p2_x,p2_y; //右
reg [15:0]ball_x,ball_y;
reg [15:0]next_p1_x,next_p1_y; //左
reg [15:0]next_p2_x,next_p2_y; //右
reg [15:0]next_ball_x,next_ball_y;



assign {vgaRed, vgaGreen, vgaBlue} = (valid==1'b1) ? pixel_out:12'h0;


clock_divider clk_25MHzinst(
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
reg [22:0] p1_left_counter;
reg [22:0] p1_right_counter;
reg [22:0] p2_left_counter;
reg [22:0] p2_right_counter;
reg p1_move_left,p1_move_right,p2_move_left,p2_move_right;
always@(posedge clk)begin
    if(p1_move_left==1) p1_move_left=0;
    else if(p1_left_counter==1250000)begin
        p1_move_left=1;
        p1_left_counter=0;
    end else if(key_down[p1_left_key])begin
        p1_left_counter=p1_left_counter+1;
    end else begin
        p1_left_counter=0;
    end
end
always @(posedge clk) begin
    if(p1_move_right==1) p1_move_right=0;
    else if(p1_right_counter==1250000)begin
        p1_move_right=1;
        p1_right_counter=0;
    end else if(key_down[p1_right_key])begin
        p1_right_counter=p1_right_counter+1;
    end else begin
        p1_right_counter=0;
    end
end

always@(posedge clk)begin
    if(p2_move_left==1) p2_move_left=0;
    else if(p2_left_counter==1250000)begin
        p2_move_left=1;
        p2_left_counter=0;
    end else if(key_down[p2_left_key])begin
        p2_left_counter=p2_left_counter+1;
    end else begin
        p2_left_counter=0;
    end
end
always @(posedge clk) begin
    if(p2_move_right==1) p2_move_right=0;
    else if(p2_right_counter==1250000)begin
        p2_move_right=1;
        p2_right_counter=0;
    end else if(key_down[p2_right_key])begin
        p2_right_counter=p2_right_counter+1;
    end else begin
        p2_right_counter=0;
    end
end

reg [22:0] p1_jump_counter;
reg p1_move_up,p1_jump,p1_drop,p1_up_1p,p1_down_1p;
always@(posedge clk,posedge rst)begin
    p1_up_1p=0; p1_down_1p=0;
    if(rst)begin
        p1_jump=0; p1_drop=0;        
    end 
    else begin
        if(p1_jump)begin
            if (p1_y==120)begin
                p1_jump=0; p1_drop=1;
            end
            else if(p1_jump_counter==500000)begin 
                p1_jump_counter=0;
                p1_up_1p=1;
            end
            else p1_jump_counter=p1_jump_counter+1;
        end else if(p1_drop)begin
            if (p1_y==180)begin
                p1_jump=0; p1_drop=0;
            end
            else if(p1_jump_counter==500000)begin 
                p1_jump_counter=0;
                p1_down_1p=1;
            end
            else p1_jump_counter=p1_jump_counter+1;
        end else begin
            if(key_down[p1_up_key])begin
                p1_jump=1;
            end
            p1_jump_counter=0;
        end
    end
end
always@(*)begin
    next_p1_y=p1_y;
    if(p1_up_1p) next_p1_y=p1_y-1;
    else if(p1_down_1p) next_p1_y=p1_y+1;
end

always@(*)begin
    next_p1_x=p1_x; 
    if(p1_move_left && p1_x>=28) next_p1_x=p1_x-1;
    else if(p1_move_right && p1_x<= 160-28) next_p1_x=p1_x+1;
end
always@(*)begin
    next_p2_x=p2_x; 
    next_p2_y=p2_y;
    if(p2_move_left && p2_x>=160+28) next_p2_x=p2_x-1;
    else if(p2_move_right && p2_x<=320-28) next_p2_x=p2_x+1;
end
always@(*)begin
    next_ball_x=160;
    next_ball_y=40;
end


always @(*) begin
    pixel_addr_background = ((h_cnt>>1)+320*(v_cnt>>1))% 76800;
end
always @(*) begin
    //畫出p1
    if(pixel_out==pixel_player1)begin
        pixel_addr_player1=2080;
        if(h_cnt>>1 >= p1_x) pixel_addr_player1= pixel_addr_player1+ ((h_cnt>>1) -p1_x);
        else pixel_addr_player1= pixel_addr_player1- (p1_x - (h_cnt>>1) );
        if(v_cnt>>1 >= p1_y) pixel_addr_player1= pixel_addr_player1+ ((v_cnt>>1) -p1_y)*64;
        else pixel_addr_player1= pixel_addr_player1- (p1_y - (v_cnt>>1) )*64;
    end else begin
        pixel_addr_player1=0;
    end
end
always @(*) begin
    //畫出p2
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
    //畫出球
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

    if(dist_sq<=800) pixel_out=pixel_player1; //p1的顯示大小
    else if(dist_sq_to_p2<=800)pixel_out=pixel_player2; //p2的顯示大小
    else if(((v_cnt>>1 >= ball_y && (v_cnt>>1)-ball_y <= 25 )||(v_cnt>>1 < ball_y && ball_y-(v_cnt>>1) <= 25))
    && (((h_cnt>>1 >= ball_x && (h_cnt>>1)-ball_x <= 25 ))||(h_cnt>>1 < ball_x && ball_x-(h_cnt>>1) <= 25 )) 
    && ball_white==0) pixel_out=pixel_ball;
    else pixel_out=pixel_background;
end

endmodule






module clock_divider(clk_25MHz, clk);
    input clk;
    output clk_25MHz;

    reg [21:0] num;
    wire [21:0] next_num;

    always @(posedge clk) begin
        num <= next_num;
    end

    assign next_num = num + 1'b1;
    assign clk_25MHz = num[1];
endmodule
