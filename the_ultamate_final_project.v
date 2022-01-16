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
    output [6:0] DISPLAY,
	output [3:0] DIGIT,
    output [15:0] led,
    output audio_mclk,
    output audio_lrck, 
    output audio_sck,
    output audio_sdin
);
// THE DECLARATION ABOUT THE PICTURE AND DISPLAY OUTPUT

reg [15:0]p1_x,p1_y; //LEFT
reg [15:0]p2_x,p2_y; //RIGHT
reg [15:0]ball_x,ball_y;
wire [15:0]next_p1_x,next_p1_y; //LEFT
wire [15:0]next_p2_x,next_p2_y; //RIGHT
reg [15:0]next_ball_x,next_ball_y;

parameter [8:0] p1_right_key = 9'b0_0011_0100; //G:34
parameter [8:0] p1_left_key = 9'b0_0010_0011;//D:23 
parameter [8:0] p1_up_key = 9'b0_0010_1101;  //R:2D
parameter [8:0] p1_down_key = 9'b0_0010_1011; //F:2B
parameter [8:0] p2_right_key = 9'b0_0111_1010; // 3: 7A
parameter [8:0] p2_left_key = 9'b0_0110_1001; //1: 69 
parameter [8:0] p2_up_key = 9'b0_0111_0011; // 5: 73
parameter [8:0] space = 9'b0_0010_1001 ; //space: 29
parameter [8:0] a_press = 9'b0_0001_1100 ; //A: F0 1C
parameter [8:0] right_ult = 9'b1_0111_0100; // Right Arrow: E074 (E0F074)
parameter [8:0] left_ult = 9'b0_0001_1010; // Z: 1A
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

// ------------------------------------------------starting the implementation for FSM ----------------------------------------------------------------- //

// --------------- a clock for implementation ------------------/
reg exe_clk;
reg [22:0] exe_clk_counter;
always @(posedge clk) begin
    if(exe_clk_counter == 4166666) begin
        exe_clk_counter = 0;
        exe_clk = 1;
    end
    else begin
        exe_clk_counter = exe_clk_counter + 1;
        exe_clk = 0;
    end 
end

reg second_clk;
reg [27:0]s_clk_cnt;
always @(posedge clk) begin
    if(s_clk_cnt == 100000000) begin
        s_clk_cnt = 0;
        second_clk = 1;
    end
    else begin
        s_clk_cnt = s_clk_cnt + 1;
        second_clk = 0;
    end 
end

reg gravity_clk;
reg [25:0] gravity_clk_counter;
always @(posedge clk) begin
    if(gravity_clk_counter == 20000032) begin
        gravity_clk_counter = 0;
        gravity_clk = 1;
    end
    else begin
        gravity_clk_counter = gravity_clk_counter + 1;
        gravity_clk = 0;
    end 
end
// --------------- end a clock for implementation ------------------/

parameter IDLE = 3'b000;
parameter BALL_DROP = 3'b001;
parameter TWO_PLAYER = 3'b010;
parameter AI = 3'b011;
parameter p1_WIN = 3'b100;
parameter p2_WIN = 3'b101;
reg [2:0] state , next_state , p1_score, p2_score , next_p1_score, next_p2_score;
reg left_valid , next_left_valid , right_valid , next_right_valid;
reg [5:0] ball_vx , ball_vy , next_ball_vx , next_ball_vy; // it just tells you the pure value of the velocity
reg vx_po , vy_po , next_vx_po , next_vy_po; // for the 0 in vx_po -> move left and vx_po = 1 -> move right  // vy_po = 0 -> move up vy_po = 1 ->down  
reg reset ; // the reset for the position  
reg [3:0] light , next_light; // registor for how many times to light

always @(posedge clk or posedge rst) begin
    if(rst == 1) begin
        p1_x=70;
        p1_y=200;
        ball_x=70;
        ball_y=40;
        p2_x=250;
        p2_y=200;
        state = IDLE;
        p1_score = 0;
        p2_score = 0;
        left_valid = 0;
        right_valid = 0;
        ball_vx = 0;
        ball_vy = 0;
        light = 0;
        vx_po = 0;
        vy_po = 0;
    end
    else begin
        p1_x=next_p1_x;
        p2_x=next_p2_x;
        p1_y=next_p1_y;
        p2_y=next_p2_y;
        ball_x=next_ball_x;
        ball_y=next_ball_y;
        state = next_state;
        p1_score = next_p1_score;
        p2_score = next_p2_score;
        left_valid = next_left_valid;
        right_valid = next_right_valid;
        ball_vx = next_ball_vx;
        ball_vy = next_ball_vy;
        light = next_light;
        vx_po = next_vx_po;
        vy_po = next_vy_po;
    end
end

// ----------------------------------------------------- calculating the distance for the ball to the pikachu ---------------------------------------------//

reg [22:0] dist_p1_ball , dist_p2_ball; // the maximun distance square is 320*320 + 240*240 = 160000
reg [22:0] final_dist; // the final value for distance which is smaller

always @(*) begin
    if(p1_x >= ball_x && p1_y >= ball_y) dist_p1_ball = (p1_x - ball_x) * (p1_x - ball_x ) + (p1_y - ball_y) * (p1_y - ball_y) ;
    else if(p1_x >= ball_x && p1_y < ball_y) dist_p1_ball = (p1_x - ball_x) * (p1_x - ball_x ) + (ball_y - p1_y) * (ball_y - p1_y) ;
    else if(p1_x < ball_x && p1_y >= ball_y) dist_p1_ball = (ball_x - p1_x) * (ball_x - p1_x ) + (p1_y - ball_y) * (p1_y - ball_y) ;
    else dist_p1_ball = (ball_x - p1_x) * (ball_x - p1_x ) + (ball_y - p1_y) * (ball_y - p1_y) ;
end

always @(*) begin
    if(p2_x >= ball_x && p2_y >= ball_y) dist_p2_ball = (p2_x - ball_x) * (p2_x - ball_x ) + (p2_y - ball_y) * (p2_y - ball_y) ;
    else if(p2_x >= ball_x && p2_y < ball_y) dist_p2_ball = (p2_x - ball_x) * (p2_x - ball_x ) + (ball_y - p2_y) * (ball_y - p2_y) ;
    else if(p2_x < ball_x && p2_y >= ball_y) dist_p2_ball = (ball_x - p2_x) * (ball_x - p2_x ) + (p2_y - ball_y) * (p2_y - ball_y) ;
    else dist_p2_ball = (ball_x - p2_x) * (ball_x - p2_x ) + (ball_y - p2_y) * (ball_y - p2_y) ;
end

// return the which is smaller and its value
always @(*) begin
    final_dist = (dist_p2_ball > dist_p1_ball )? dist_p1_ball : dist_p2_ball;
end

// --------------------------------------------------- end the calculating --------------------------------------------------------------------------------//

// --------------------------------------------------- only monitor the speed and the direction for the ball --------------------------------------------//

// for the 0 in vx_po -> move left and vx_po = 1 -> move right  // vy_po = 0 -> move up vy_po = 1 ->down  
always @(*) begin
    case(state)
        IDLE: begin
            next_ball_vx = 0;
            next_ball_vy = 0;
            next_vx_po = 0;
            next_vy_po =0;
            if(key_down[space] == 1) begin
                next_ball_vx = 0;
                next_ball_vy = 3;
                next_vx_po = 0;
                next_vy_po = 1;
            end
            if(key_down[a_press] == 1) begin
                next_ball_vx = 0;
                next_ball_vy = 3;
                next_vx_po = 0;
                next_vy_po = 1;
            end
        end
        TWO_PLAYER: begin
            next_ball_vx = ball_vx;
            next_ball_vy = ball_vy;
            next_vx_po = vx_po;
            next_vy_po = vy_po;
            // ball hit the floor 
            if(ball_y <= 30 ) begin
                next_vy_po = 1; // change direction with the same speed // we can't use  next_vy_po = vy_po ^ 1;
            end
            // ball hit the wall
            if(ball_x <= 30) begin
                next_vx_po = 1; // change direction with the same speed
            end
            if(ball_x >= 320 - 30 ) begin
                next_vx_po = 0;
            end
            // ball hit the pillar (take 27 as ball's radius )
            if(ball_x > 160 && ball_x - 160 < 27 && ball_y > 125) begin
                next_vx_po = 1;
            end
            if(ball_x < 160 &&  160 - ball_x < 27 && ball_y > 125) begin
                next_vx_po = 0;
            end
            if(ball_x > 160 && ball_x - 160 < 27 && ball_y > 125  && ball_y < 125+27 ) begin
                next_vy_po = 0;
                next_ball_vy = (ball_y - 125 ) / 4;
            end
            // ball underground (other score )
            if(ball_y >= 200 - 10) begin
                next_ball_vx = 0;
                next_ball_vy = 3;
                next_vx_po = 0;
                next_vy_po = 1;
            end
            // the gravity part 
            if(gravity_clk == 1) begin
                if(vy_po == 1) begin
                    next_ball_vy = ball_vy + 1;
                end
                else begin // change dir
                    if(ball_vy <= 2) begin
                        next_vy_po = 1;
                    end
                    else begin
                        next_ball_vy = ball_vy - 1;
                    end
                end
            end
            // collision with the pillar should be handled first
            // the buttom point with the x_axis 160 and y_axis 200~140
            // ball collide with the pikachu ((25)+(16) + 2 )^2 = 1849
            if(ball_y < 200-10) begin
                if(final_dist <= 1850) begin
                    if(final_dist == dist_p1_ball) begin // indicate that it's closer to p1
                        if(p1_x >= ball_x && p1_y >= ball_y) begin
                            next_ball_vx = (p1_x - ball_x) / 4; // maximun speed = 6 (43/7)
                            next_ball_vy = (p1_y - ball_y) / 4;
                            next_vx_po = 0;
                            next_vy_po = 0;
                        end
                        else if(p1_x >= ball_x && p1_y < ball_y) begin
                            next_ball_vx = (p1_x - ball_x) / 4;
                            next_ball_vy = (ball_y - p1_y) / 4;
                            next_vx_po = 0;
                            next_vy_po = 1;
                        end
                        else if(p1_x < ball_x && p1_y >= ball_y) begin
                            next_ball_vx = (ball_x - p1_x) / 4;
                            next_ball_vy = (p1_y - ball_y) / 4;
                            next_vx_po = 1;
                            next_vy_po = 0;
                        end
                        else if(p1_x < ball_x && p1_y < ball_y) begin
                            next_ball_vx = (ball_x - p1_x) / 4;
                            next_ball_vy = (ball_y - p1_y) / 4;
                            next_vx_po = 1;
                            next_vy_po = 1;
                        end
                    end
                    else if(final_dist == dist_p2_ball) begin // indicate that it's closer to p2
                        if(p2_x >= ball_x && p2_y >= ball_y) begin
                            next_ball_vx = (p2_x - ball_x) / 4;
                            next_ball_vy = (p2_y - ball_y) / 4;
                            next_vx_po = 0;
                            next_vy_po = 0;
                        end
                        else if(p2_x >= ball_x && p2_y < ball_y) begin
                            next_ball_vx = (p2_x - ball_x) / 4;
                            next_ball_vy = (ball_y - p2_y) / 4;
                            next_vx_po = 0;
                            next_vy_po = 1;
                        end
                        else if(p2_x < ball_x && p2_y >= ball_y) begin
                            next_ball_vx = (ball_x - p2_x) / 4;
                            next_ball_vy = (p2_y - ball_y) / 4;
                            next_vx_po = 1;
                            next_vy_po = 0;
                        end
                        else if(p2_x < ball_x && p2_y < ball_y) begin
                            next_ball_vx = (ball_x - p2_x) / 4;
                            next_ball_vy = (ball_y - p2_y) / 4;
                            next_vx_po = 1;
                            next_vy_po = 1;
                        end
                    end
                end
                // for the 0 in vx_po -> move left and vx_po = 1 -> move right  // vy_po = 0 -> move up vy_po = 1 ->down 
                else if(final_dist <= 3600 && final_dist >= 1850) begin
                    if(final_dist == dist_p1_ball) begin
                        if(ball_x > p1_x && key_down[left_ult] == 1) begin
                            next_ball_vx = 15;
                            next_ball_vy = 10;
                            next_vx_po = 1;
                            next_vy_po = 1;
                        end 
                    end
                    else if(final_dist == dist_p2_ball) begin
                        if(ball_x < p2_x && key_down[right_ult] == 1) begin
                            next_ball_vx = 15;
                            next_ball_vy = 10;
                            next_vx_po = 0;
                            next_vy_po = 1;
                        end 
                    end
                end
            end
        end
        AI:begin
            next_ball_vx = ball_vx;
            next_ball_vy = ball_vy;
            next_vx_po = vx_po;
            next_vy_po = vy_po;
            // ball hit the floor 
            if(ball_y <= 30 ) begin
                next_vy_po = 1; // change direction with the same speed // we can't use  next_vy_po = vy_po ^ 1;
            end
            // ball hit the wall
            if(ball_x <= 30) begin
                next_vx_po = 1; // change direction with the same speed
            end
            if(ball_x >= 320 - 30 ) begin
                next_vx_po = 0;
            end
            // ball hit the pillar (take 27 as ball's radius )
            if(ball_x > 160 && ball_x - 160 < 27 && ball_y > 125) begin
                next_vx_po = 1;
            end
            if(ball_x < 160 &&  160 - ball_x < 27 && ball_y > 125) begin
                next_vx_po = 0;
            end
            if(ball_x > 160 && ball_x - 160 < 27 && ball_y > 125  && ball_y < 125+27 ) begin
                next_vy_po = 0;
                next_ball_vy = (ball_y - 125 ) / 4;
            end
            // ball underground (other score )
            if(ball_y >= 200 - 10) begin
                next_ball_vx = 0;
                next_ball_vy = 3;
                next_vx_po = 0;
                next_vy_po = 1;
            end
            // the gravity part 
            if(gravity_clk == 1) begin
                if(vy_po == 1) begin
                    next_ball_vy = ball_vy + 1;
                end
                else begin // change dir
                    if(ball_vy <= 2) begin
                        next_vy_po = 1;
                    end
                    else begin
                        next_ball_vy = ball_vy - 1;
                    end
                end
            end
            // collision with the pillar should be handled first
            // the buttom point with the x_axis 160 and y_axis 200~140
            // ball collide with the pikachu ((25)+(16) + 2 )^2 = 1849
            if(ball_y < 200-10) begin
                if(final_dist <= 1850) begin
                    if(final_dist == dist_p1_ball) begin // indicate that it's closer to p1
                        if(p1_x >= ball_x && p1_y >= ball_y) begin
                            next_ball_vx = (p1_x - ball_x)  / 4; // maximun speed = 6 (43/7)
                            next_ball_vy = (p1_y - ball_y)  / 4;
                            next_vx_po = 0;
                            next_vy_po = 0;
                        end
                        else if(p1_x >= ball_x && p1_y < ball_y) begin
                            next_ball_vx = (p1_x - ball_x)  / 4;
                            next_ball_vy = (ball_y - p1_y)  / 4;
                            next_vx_po = 0;
                            next_vy_po = 1;
                        end
                        else if(p1_x < ball_x && p1_y >= ball_y) begin
                            next_ball_vx = (ball_x - p1_x)  / 4;
                            next_ball_vy = (p1_y - ball_y)  / 4;
                            next_vx_po = 1;
                            next_vy_po = 0;
                        end
                        else if(p1_x < ball_x && p1_y < ball_y) begin
                            next_ball_vx = (ball_x - p1_x)  / 4;
                            next_ball_vy = (ball_y - p1_y)  / 4;
                            next_vx_po = 1;
                            next_vy_po = 1;
                        end
                    end
                    else if(final_dist == dist_p2_ball) begin // indicate that it's closer to p2
                        if(p2_x >= ball_x && p2_y >= ball_y) begin
                            next_ball_vx = (p2_x - ball_x)  / 4;
                            next_ball_vy = (p2_y - ball_y)  / 4;
                            next_vx_po = 0;
                            next_vy_po = 0;
                        end
                        else if(p2_x >= ball_x && p2_y < ball_y) begin
                            next_ball_vx = (p2_x - ball_x)  / 4;
                            next_ball_vy = (ball_y - p2_y)  / 4;
                            next_vx_po = 0;
                            next_vy_po = 1;
                        end
                        else if(p2_x < ball_x && p2_y >= ball_y) begin
                            next_ball_vx = (ball_x - p2_x)  / 4;
                            next_ball_vy = (p2_y - ball_y)  / 4;
                            next_vx_po = 1;
                            next_vy_po = 0;
                        end
                        else if(p2_x < ball_x && p2_y < ball_y) begin
                            next_ball_vx = (ball_x - p2_x)  / 4;
                            next_ball_vy = (ball_y - p2_y)  / 4;
                            next_vx_po = 1;
                            next_vy_po = 1;
                        end
                    end
                end
                // for the 0 in vx_po -> move left and vx_po = 1 -> move right  // vy_po = 0 -> move up vy_po = 1 ->down 
                else if(final_dist <= 3600 && final_dist >= 1850) begin
                    if(final_dist == dist_p1_ball) begin
                        if(ball_x > p1_x && key_down[left_ult] == 1) begin
                            next_ball_vx = 15;
                            next_ball_vy = 10;
                            next_vx_po = 1;
                            next_vy_po = 1;
                        end 
                    end
                    else if(final_dist == dist_p2_ball) begin
                        if(ball_x < p2_x && key_down[right_ult] == 1) begin
                            next_ball_vx = 15;
                            next_ball_vy = 10;
                            next_vx_po = 0;
                            next_vy_po = 1;
                        end 
                    end
                end
            end
        end
        p1_WIN: begin
            next_ball_vx = ball_vx;
            next_ball_vy = ball_vy;
            next_vx_po = vx_po;
            next_vy_po = vy_po;
        end
        p2_WIN: begin
            next_ball_vx = ball_vx;
            next_ball_vy = ball_vy;
            next_vx_po = vx_po;
            next_vy_po = vy_po;
        end
        default: begin
            next_ball_vx = 0;
            next_ball_vy = 0;
            next_vx_po = 0;
            next_vy_po = 0;
        end
    endcase
end
// ----------------------------------------------------end the speed and speed and the direction for the ball ------------------------------------------// 

// ----------------------------------------------------other thing monitor ........ the position and the movement or if it's valid to move -------------------//
reg music_play;

always @(*) begin
    case(state)
        IDLE: begin
            next_ball_x=70;
            next_ball_y=40;
            next_p1_score = 0;
            next_p2_score = 0;
            next_left_valid = 0;
            next_right_valid = 0;
            next_state = IDLE;
            reset = 0;
            next_light = 0;
            music_play = 0;
            if(key_down[space] == 1) begin
                next_state = TWO_PLAYER;
            end
            if(key_down[a_press] == 1) begin
                next_state = AI;
            end
        end
        TWO_PLAYER: begin
            next_ball_x = ball_x;
            next_ball_y = ball_y;
            next_p1_score = p1_score;
            next_p2_score = p2_score;
            next_left_valid = 1;
            next_right_valid = 1;
            next_state = TWO_PLAYER;
            reset = 0;
            next_light = light;
            music_play = 1;
            // if the ball collide with the player
            // the time the ball fall into the ground 
            if(ball_y >= 200 - 10) begin
                reset = 1;
                next_ball_y = 40;
                if(ball_x < 160 - 4 ) begin
                    next_ball_x = 250;
                    next_p2_score = p2_score + 1;
                end
                else begin
                    next_ball_x = 70;
                    next_p1_score = p1_score + 1;
                end
            end
            // if anyone win
            if(p1_score >= 7 ) begin
                next_light=10;
                next_state = p1_WIN;
            end else if(p2_score >= 7)begin
                next_light=10;
                next_state = p2_WIN;
            end
            // the movement for the ball (containing the boundary )
            if(exe_clk == 1) begin // vx = 0 ->l / vx = 1 -> r / vy = 0 -> up / vy = 1 -> down
                if(vx_po == 0) begin
                    if((ball_x - ball_vx) >= 0) next_ball_x = ball_x - ball_vx;
                end
                if(vx_po == 1) begin
                    if((ball_x + ball_vx) <= 320)  next_ball_x = ball_x + ball_vx;
                end
                if(vy_po == 0) begin
                    if((ball_y - ball_vy) >= 0) next_ball_y = ball_y - ball_vy; 
                end
                if(vy_po == 1) begin
                    if((ball_y + ball_vy) <= 200 ) next_ball_y = ball_y + ball_vy; 
                end
            end
        end
        AI: begin
            next_ball_x = ball_x;
            next_ball_y = ball_y;
            next_p1_score = p1_score;
            next_p2_score = p2_score;
            next_left_valid = 1;
            next_right_valid = 1;
            next_state = AI;
            reset = 0;
            next_light = light;
            music_play = 1;
            // if the ball collide with the player
            // the time the ball fall into the ground 
            if(ball_y >= 200 - 10) begin
                reset = 1;
                next_ball_y = 40;
                if(ball_x < 160 - 4 ) begin
                    next_ball_x = 250;
                    next_p2_score = p2_score + 1;
                end
                else begin
                    next_ball_x = 70;
                    next_p1_score = p1_score + 1;
                end
            end
            // if anyone win
            if(p1_score >= 7 ) begin
                next_light=10;
                next_state = p1_WIN;
            end else if(p2_score >= 7)begin
                next_light=10;
                next_state = p2_WIN;
            end
            // the movement for the ball (containing the boundary )
            if(exe_clk == 1) begin // vx = 0 ->l / vx = 1 -> r / vy = 0 -> up / vy = 1 -> down
                if(vx_po == 0) begin
                    if((ball_x - ball_vx) >= 0) next_ball_x = ball_x - ball_vx;
                end
                if(vx_po == 1) begin
                    if((ball_x + ball_vx) <= 320)  next_ball_x = ball_x + ball_vx;
                end
                if(vy_po == 0) begin
                    if((ball_y - ball_vy) >= 0) next_ball_y = ball_y - ball_vy; 
                end
                if(vy_po == 1) begin
                    if((ball_y + ball_vy) <= 200 ) next_ball_y = ball_y + ball_vy; 
                end
            end
        end
        p1_WIN: begin
            next_ball_x = ball_x;
            next_ball_y = ball_y;
            next_p1_score = 0;
            next_p2_score = 0;
            next_left_valid = 1;
            next_right_valid = 1;
            next_state = p1_WIN;
            reset = 1;
            next_light = light;
            music_play = 0;
            if(second_clk == 1) begin
                next_light = light - 1;
            end
            if(light == 0) begin
                next_state = IDLE;
            end
        end
        p2_WIN: begin
            next_ball_x = ball_x;
            next_ball_y = ball_y;
            next_p1_score = 0;
            next_p2_score = 0;
            next_left_valid = 1;
            next_right_valid = 1;
            next_state = p2_WIN;
            reset = 1;
            next_light = light;
            music_play = 0;
            if(second_clk == 1) begin
                next_light = light - 1;
            end
            if(light == 0) begin
                next_state = IDLE;
            end
        end
        default: begin
            next_ball_x=200;
            next_ball_y=40;
            next_p1_score = 0;
            next_p2_score = 0;
            next_left_valid = 0;
            next_right_valid = 0;
            next_state = IDLE;
            reset = 0;
            next_light = 0;
            music_play = 0;
        end
    endcase
end
// ----------------------------------------------------other thing monitor ........ the position and the movement or if it's valid to move -------------------//


// ---------------------------------------------------end the implementation for FSM ----------------------------------------------------------------- //

wire p1_move_left,p1_move_right,p2_move_left,p2_move_right; // handle the player moving left or right
wire p1_up_1p,p1_down_1p,p2_up_1p,p2_down_1p; // handling the player moving down or up
wire AI_up,AI_down,AI_right,AI_left; //handling AI moving up or down

reg [15:0] score_nums;  // ex: 0305=3:5
always@(*)begin
    score_nums[15:12]=0;
    score_nums[11:8]=p1_score;
    score_nums[7:4]=0;
    score_nums[3:0]=p2_score;
end

//---------------------------------------------------------------LED-------------------------------------------------
led_final led_part(.led(led), .state(state) , .second_clk(second_clk));
//---------------------------------------------------------------LED-------------------------------------------------

//----------------------------------------------------------------begin seven segment------------------------------------------------------------------//
seven_segment_final seven_segment_part(.nums(score_nums),.rst(rst),.clk(clk),.display(DISPLAY),.digit(DIGIT));
//----------------------------------------------------------------end seven segment--------------------------------------------------------------------//

handle_keypressed move_left_right_handle(.clk(clk), .rst(rst), .pl_l(key_down[p1_left_key]),
    .p1_r(key_down[p1_right_key]), .p2_l(key_down[p2_left_key]), .p2_r(key_down[p2_right_key]), 
    .p1_l_cmd(p1_move_left), .p1_r_cmd(p1_move_right), .p2_l_cmd(p2_move_left), .p2_r_cmd(p2_move_right)
);

jump_control jp(.clk(clk), .rst(rst), .p1_y(p1_y), .p2_y(p2_y), .p1_u(key_down[p1_up_key]),
    .p2_u(key_down[p2_up_key]), .p1_up_cmd(p1_up_1p), .p1_drop_cmd(p1_down_1p), .p2_up_cmd(p2_up_1p),
    .p2_drop_cmd(p2_down_1p)
);

player_movement play_mo(
    .player_1_left(p1_move_left), .player_1_right(p1_move_right), .player_1_up(p1_up_1p),
    .player_1_down(p1_down_1p), .player_2_left(p2_move_left), .player_2_right(p2_move_right),
    .player_2_up(p2_up_1p), .player_2_down(p2_down_1p), .left_valid(left_valid), .right_valid(right_valid) , .p1_x(p1_x), 
    .p1_y(p1_y), .p2_x(p2_x), .p2_y(p2_y), .next_p1_x(next_p1_x), .next_p1_y(next_p1_y), 
    .next_p2_x(next_p2_x), .next_p2_y(next_p2_y) , .rst(reset) , .state(state) , 
    .AI_left(AI_left) , .AI_right(AI_right), .AI_up(AI_up),.AI_down(AI_down)
);

AI_movement AI_move(
    .clk(clk), .state(state), .ball_x(ball_x) ,.ball_y(ball_y),.ball_vx(ball_vx),.ball_vy(ball_vy),
    .vx_po(vx_po),.vy_po(vy_po), .p2_x(p2_x),.p2_y(p2_y) , .rst(rst),
    .AI_right(AI_right),.AI_left(AI_left),.AI_up(AI_up),.AI_down(AI_down)
    
);

//-----------------------------------------------------------------begin display--------------------------------------------------------//
display_final display_part(.clk(clk), .rst(rst), .p1_x(p1_x) , .p1_y(p1_y) , .p2_x(p2_x), .p2_y(p2_y), .ball_x(ball_x), .ball_y(ball_y),
.vgaRed(vgaRed), .vgaGreen(vgaGreen), .vgaBlue(vgaBlue),.hsync(hsync),.vsync(vsync));
//-----------------------------------------------------------------end display----------------------------------------------------------//

//-------------------------------------------------------------begin music part -------------------------------------------------------//
// declaration 
music_final music_part( .clk(clk), .rst(rst), .playing(music_play) , .audio_mclk(audio_mclk), .audio_lrck(audio_lrck), .audio_sck(audio_sck), .audio_sdin(audio_sdin));
//-------------------------------------------------------------end music part -------------------------------------------------------//
endmodule

module KeyboardDecoder(
	output reg [511:0] key_down,
	output wire [8:0] last_change,
	output reg key_valid,
	inout wire PS2_DATA,
	inout wire PS2_CLK, 	
	input wire rst,
	input wire clk
    );
    
    parameter [1:0] INIT			= 2'b00;
    parameter [1:0] WAIT_FOR_SIGNAL = 2'b01;
    parameter [1:0] GET_SIGNAL_DOWN = 2'b10;
    parameter [1:0] WAIT_RELEASE    = 2'b11;
    
	parameter [7:0] IS_INIT			= 8'hAA;
    parameter [7:0] IS_EXTEND		= 8'hE0;
    parameter [7:0] IS_BREAK		= 8'hF0;
    
    reg [9:0] key;		// key = {been_extend, been_break, key_in}
    reg [1:0] state;
    reg been_ready, been_extend, been_break;
    
    wire [7:0] key_in;
    wire is_extend;
    wire is_break;
    wire valid;
    wire err;
    
    wire [511:0] key_decode = 1 << last_change;
    assign last_change = {key[9], key[7:0]};
    
    KeyboardCtrl_0 inst (
		.key_in(key_in),
		.is_extend(is_extend),
		.is_break(is_break),
		.valid(valid),
		.err(err),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);
	
	OnePulse op (
		.signal_single_pulse(pulse_been_ready),
		.signal(been_ready),
		.clock(clk)
	);
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		state <= INIT;
    		been_ready  <= 1'b0;
    		been_extend <= 1'b0;
    		been_break  <= 1'b0;
    		key <= 10'b0_0_0000_0000;
    	end else begin
    		state <= state;
			been_ready  <= been_ready;
			been_extend <= (is_extend) ? 1'b1 : been_extend;
			been_break  <= (is_break ) ? 1'b1 : been_break;
			key <= key;
    		case (state)
    			INIT : begin
    					if (key_in == IS_INIT) begin
    						state <= WAIT_FOR_SIGNAL;
    						been_ready  <= 1'b0;
							been_extend <= 1'b0;
							been_break  <= 1'b0;
							key <= 10'b0_0_0000_0000;
    					end else begin
    						state <= INIT;
    					end
    				end
    			WAIT_FOR_SIGNAL : begin
    					if (valid == 0) begin
    						state <= WAIT_FOR_SIGNAL;
    						been_ready <= 1'b0;
    					end else begin
    						state <= GET_SIGNAL_DOWN;
    					end
    				end
    			GET_SIGNAL_DOWN : begin
						state <= WAIT_RELEASE;
						key <= {been_extend, been_break, key_in};
						been_ready  <= 1'b1;
    				end
    			WAIT_RELEASE : begin
    					if (valid == 1) begin
    						state <= WAIT_RELEASE;
    					end else begin
    						state <= WAIT_FOR_SIGNAL;
    						been_extend <= 1'b0;
    						been_break  <= 1'b0;
    					end
    				end
    			default : begin
    					state <= INIT;
						been_ready  <= 1'b0;
						been_extend <= 1'b0;
						been_break  <= 1'b0;
						key <= 10'b0_0_0000_0000;
    				end
    		endcase
    	end
    end
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		key_valid <= 1'b0;
    		key_down <= 511'b0;
    	end else if (key_decode[last_change] && pulse_been_ready) begin
    		key_valid <= 1'b1;
    		if (key[8] == 0) begin
    			key_down <= key_down | key_decode;
    		end else begin
    			key_down <= key_down & (~key_decode);
    		end
    	end else begin
    		key_valid <= 1'b0;
			key_down <= key_down;
    	end
    end

endmodule

module led_final (
    input [2:0] state,
    input second_clk,
    output reg[15:0] led
);


    always@(posedge second_clk)begin
        if(state==3'b100)begin
            led[15:8]=~led[15:8];
        end else if(state==3'b101)begin
            led[7:0]=~led[7:0];
        end else led[15:0]=0;
    end


endmodule 

module seven_segment_final(
	input  [15:0] nums,
	input  rst,
	input  clk,
    output  reg[6:0] display,
	output  reg[3:0] digit
);
    
    reg [15:0] clk_divider;
    reg [3:0] display_num;
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		clk_divider <= 15'b0;
    	end else begin
    		clk_divider <= clk_divider + 15'b1;
    	end
    end
    
    always @ (posedge clk_divider[15], posedge rst) begin
    	if (rst) begin
    		display_num <= 4'b0000;
    		digit <= 4'b1111;
    	end else begin
    		case (digit)
    			4'b1110 : begin
    					display_num <= nums[7:4];
    					digit <= 4'b1101;
    				end
    			4'b1101 : begin
						display_num <= nums[11:8];
						digit <= 4'b1011;
					end
    			4'b1011 : begin
						display_num <= nums[15:12];
						digit <= 4'b0111;
					end
    			4'b0111 : begin
						display_num <= nums[3:0];
						digit <= 4'b1110;
					end
    			default : begin
						display_num <= nums[3:0];
						digit <= 4'b1110;
					end				
    		endcase
    	end
    end
    
    always @ (*) begin
    	case (display_num)
    		0 : display = 7'b1000000;	//0000
			1 : display = 7'b1111001;   //0001                                                
			2 : display = 7'b0100100;   //0010                                                
			3 : display = 7'b0110000;   //0011                                             
			4 : display = 7'b0011001;   //0100                                               
			5 : display = 7'b0010010;   //0101                                               
			6 : display = 7'b0000010;   //0110
			7 : display = 7'b1111000;   //0111
			8 : display = 7'b0000000;   //1000
			9 : display = 7'b0010000;	//1001
			default : display = 7'b1111111;
    	endcase
    end
    
endmodule


module handle_keypressed(
    input clk,
    input rst,
    input pl_l,
    input p1_r,
    input p2_l,
    input p2_r,
    output reg p1_l_cmd,
    output reg p1_r_cmd,
    output reg p2_l_cmd,
    output reg p2_r_cmd
    );

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
        end else if(pl_l == 1)begin
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
        end else if(p1_r == 1)begin
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
        end else if(p2_l == 1)begin
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
        end else if(p2_r == 1)begin
            p2_right_counter=p2_right_counter+1;
        end else begin
            p2_right_counter=0;
        end
    end


    always @(*) begin
        p1_l_cmd = p1_move_left;
        p1_r_cmd = p1_move_right;
        p2_l_cmd = p2_move_left;
        p2_r_cmd = p2_move_right;
    end
endmodule

module jump_control(
    input clk,
    input rst,
    input [15:0]p1_y,
    input [15:0]p2_y,
    input p1_u,
    input p2_u,
    output reg p1_up_cmd,
    output reg p1_drop_cmd,
    output reg p2_up_cmd,
    output reg p2_drop_cmd
    );

    reg [22:0] p1_jump_counter,p2_jump_counter;
    reg p1_jump_state,p1_drop_state,p1_up_out,p1_down_out;
    reg p2_jump_state,p2_drop_state,p2_up_out,p2_down_out;

    always@(posedge clk,posedge rst)begin
        p1_up_out=0; p1_down_out=0;
        if(rst)begin
            p1_jump_state=0; p1_drop_state=0;        
        end 
        else begin
            if(p1_jump_state)begin
                if (p1_y<=120)begin
                    p1_jump_state=0;
                    p1_drop_state=1;
                end
                else if(p1_jump_counter==500000)begin 
                    p1_jump_counter=0;
                    p1_up_out=1;
                end
                else p1_jump_counter=p1_jump_counter+1;
            end 
            else if(p1_drop_state)begin
                if (p1_y>=200)begin
                    p1_jump_state=0; p1_drop_state=0;
                end
                else if(p1_jump_counter==500000)begin 
                    p1_jump_counter=0;
                    p1_down_out = 1;
                end
                else p1_jump_counter=p1_jump_counter+1;
            end 
            else begin
                if(p1_u == 1)begin
                    p1_jump_state=1;
                end
                p1_jump_counter=0;
            end
        end
    end

    always@(posedge clk,posedge rst)begin
        p2_up_out=0; p2_down_out=0;
        if(rst)begin
            p2_jump_state=0;
            p2_drop_state=0;        
        end 
        else begin
            if(p2_jump_state)begin
                if (p2_y<=120)begin
                    p2_jump_state=0;
                    p2_drop_state=1;
                end
                else if(p2_jump_counter==500000)begin 
                    p2_jump_counter=0;
                    p2_up_out=1;
                end
                else p2_jump_counter=p2_jump_counter+1;
            end 
            else if(p2_drop_state)begin
                if (p2_y>=200)begin
                    p2_jump_state=0; p2_drop_state=0;
                end
                else if(p2_jump_counter==500000)begin 
                    p2_jump_counter=0;
                    p2_down_out = 1;
                end
                else p2_jump_counter=p2_jump_counter+1;
            end 
            else begin
                if(p2_u == 1)begin
                    p2_jump_state=1;
                end
                p2_jump_counter=0;
            end
        end
    end

    always @(*) begin
        p1_up_cmd = p1_up_out;
        p1_drop_cmd = p1_down_out;
        p2_up_cmd = p2_up_out;
        p2_drop_cmd = p2_down_out;
    end
endmodule

module player_movement(
    input player_1_left,
    input player_1_right,
    input player_1_up,
    input player_1_down,
    input player_2_left,
    input player_2_right,
    input player_2_up,
    input player_2_down,
    input left_valid,
    input right_valid,
    input [15:0] p1_x,
    input [15:0] p1_y,
    input [15:0] p2_x,
    input [15:0] p2_y,
    input rst,
    output reg[15:0]next_p1_x,
    output reg[15:0]next_p1_y,
    output reg[15:0]next_p2_x,
    output reg[15:0]next_p2_y,
    input [2:0] state,
    input AI_left,
    input AI_right,
    input AI_up,
    input AI_down
    );
    
    always @(*) begin
        next_p1_x = p1_x;
        if(rst == 1) begin
            next_p1_x = 70;
        end
        else begin
            if(left_valid) begin
                if(player_1_left == 1 && p1_x >= 20) begin
                    next_p1_x = p1_x - 1;
                end
                else if(player_1_right == 1 && p1_x<= 160-24 ) begin
                    next_p1_x = p1_x + 1;
                end
            end
        end
    end

    always @(*) begin
        next_p1_y = p1_y;
        if(rst == 1) begin
            next_p1_y = 200;
        end
        else begin
            if(left_valid) begin
                if(player_1_down == 1 ) begin
                    next_p1_y = p1_y + 1;
                end
                if(player_1_up == 1) begin
                    next_p1_y = p1_y - 1;
                end
            end
        end
    end




    always @(*) begin
        next_p2_x = p2_x;
        if(rst == 1) begin
            next_p2_x = 250;
        end
        else begin
            if(state==3'b011)begin //AI
                if(AI_left == 1  && p2_x >= 160 + 24  ) begin
                    next_p2_x = p2_x - 1;
                end
                else if(AI_right == 1 && p2_x <= 320 - 20 ) begin
                    next_p2_x = p2_x + 1;
                end
            end
            else if(right_valid) begin
                if(player_2_left == 1  && p2_x >= 160 + 24  ) begin
                    next_p2_x = p2_x - 1;
                end
                else if(player_2_right == 1 && p2_x <= 320 - 20 ) begin
                    next_p2_x = p2_x + 1;
                end
            end
        end
    end

    always @(*) begin
        next_p2_y = p2_y;
        if(rst == 1) begin
            next_p2_y = 200;
        end
        else begin
            if(state==3'b011)begin //AI
                if(AI_down == 1) begin
                    next_p2_y = p2_y + 1;
                end
                else if(AI_up == 1) begin
                    next_p2_y = p2_y - 1;
                end
            end
            else if(right_valid) begin
                if(player_2_down == 1) begin
                    next_p2_y = p2_y + 1;
                end
                else if(player_2_up == 1) begin
                    next_p2_y = p2_y - 1;
                end 
            end
        end
    end
    
endmodule

module AI_movement (
    input clk,
    input rst,
    input [2:0] state,
    input [15:0] ball_x,
    input [15:0] ball_y,
    input [5:0] ball_vx,
    input [5:0] ball_vy,
    input  vx_po,
    input  vy_po,
    input [15:0] p2_x,
    input [15:0] p2_y,

    output reg AI_right,
    output reg AI_left,
    output reg AI_up,
    output reg AI_down

);
    wire [3:0] random_out;
    LFSR random_generator(.rst(rst),.clk(clk),.random(random_out));

    reg [25:0] move_left_counter;

    reg [22:0] p2_ball_dist;
    always@(*)begin
        p2_ball_dist=0;
        if(p2_x>=ball_x) p2_ball_dist=p2_ball_dist+((p2_x-ball_x)*(p2_x-ball_x));
        else  p2_ball_dist=p2_ball_dist+((ball_x-p2_x)*(ball_x-p2_x));
        if(p2_y>=ball_y) p2_ball_dist=p2_ball_dist+((p2_y-ball_y)*(p2_y-ball_y));
        else  p2_ball_dist=p2_ball_dist+((ball_y-p2_y)*(ball_y-p2_y));
    end

    always@(posedge clk)begin
        if(AI_right==1) AI_right=0;
        if(AI_left==1) AI_left=0;
        else if(ball_x<=140)begin
            if(move_left_counter==1500000)begin
                move_left_counter=0;
                if(vx_po==1) AI_right=1;
                else if(vy_po==1) AI_left=1;
            end else begin
                move_left_counter=move_left_counter+1;
            end
        end else if(ball_x>140)begin
            if(move_left_counter==650000)begin
                move_left_counter=0;
                if(p2_x>=ball_x+20) AI_left=1;
                else AI_right=1;  
            end else begin
                move_left_counter=move_left_counter+1;
            end
        end
    end 


    reg AI_jump_state,AI_drop_state;
    reg [25:0] AI_jump_counter;
    reg [28:0] AI_enable_jump_cnt;

    always@(posedge clk,posedge rst)begin
        AI_up=0; AI_down=0;
        if(rst)begin
            AI_jump_state=0;AI_drop_state=0;AI_enable_jump_cnt=0;
        end
        else begin
            if(AI_jump_state)begin
                if(p2_y<=100)begin
                    AI_jump_state=0;
                    AI_drop_state=1;
                end else if(AI_jump_counter==500000)begin
                    AI_jump_counter=0;
                    AI_up=1;
                end else AI_jump_counter=AI_jump_counter+1;
            end else if(AI_drop_state)begin
                if(p2_y>=200)begin
                    AI_jump_state=0;
                    AI_drop_state=0;
                end else if(AI_jump_counter==500000)begin
                    AI_jump_counter=0;
                    AI_down=1;
                end else AI_jump_counter=AI_jump_counter+1;
            end else begin
                if(vy_po==1 && ball_y>=100 && ball_y<=120 && p2_x<=190 && ball_x>=160)begin
                    AI_jump_state=1; 
                end else if(ball_x>=160 && p2_ball_dist>=8000 && p2_ball_dist<=12000)begin
                    if(AI_enable_jump_cnt==0 )begin
                        if(random_out[0])begin
                            AI_jump_state=1;
                        end
                        AI_enable_jump_cnt=200000000;
                    end 
                end
                AI_jump_counter=0;
            end
            if(AI_enable_jump_cnt>0)AI_enable_jump_cnt=AI_enable_jump_cnt-1;
        end
    end

endmodule

module LFSR(
    input wire clk,
    input wire rst,
    output reg [3:0] random
);
always @(posedge clk,posedge rst)begin
    if(rst==1'b1) random[3:0]<=4'b1000;
    else begin
        random [2:0] <= random[3:1];
        random [3] <= random[1] ^ random[0];
    end
end

endmodule

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
reg [13:0] pixel_addr_ball; //100*100
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
        if(h_cnt >= p1_x<<1 ) pixel_addr_player1= pixel_addr_player1+ (h_cnt - (p1_x<<1));
        else pixel_addr_player1= pixel_addr_player1- ((p1_x<<1) - h_cnt );
        if(v_cnt >= p1_y<<1) pixel_addr_player1= pixel_addr_player1+ (v_cnt -(p1_y<<1))*64;
        else pixel_addr_player1= pixel_addr_player1- ((p1_y<<1) - v_cnt )*64;
    end else begin
        pixel_addr_player1=0;
    end
end

always @(*) begin
    //draw p2
    if(pixel_out==pixel_player2)begin
        pixel_addr_player2=2080;
        if(h_cnt >= p2_x<<1 ) pixel_addr_player2= pixel_addr_player2+ (h_cnt - (p2_x<<1));
        else pixel_addr_player2= pixel_addr_player2- ((p2_x<<1) - h_cnt );
        if(v_cnt >= p2_y<<1) pixel_addr_player2= pixel_addr_player2+ (v_cnt -(p2_y<<1))*64;
        else pixel_addr_player2= pixel_addr_player2- ((p2_y<<1) - v_cnt )*64;
    end else begin
        pixel_addr_player2=0;
    end
end

always @(*) begin
    //draw the ball
    if(pixel_out==pixel_ball)begin
        pixel_addr_ball=4950;
        pixel_addr_ball= pixel_addr_ball+ (h_cnt -(ball_x<<1));
        if(v_cnt >= ball_y<<1) pixel_addr_ball= pixel_addr_ball+ (v_cnt -(ball_y<<1))*100;
        else pixel_addr_ball= pixel_addr_ball- ((ball_y<<1) - v_cnt )*100;
    end else begin
        pixel_addr_ball=0;
    end
end

reg [32:0]dist_sq;
reg [32:0]dist_sq_to_p2;

wire ball_white;
reg [15:0] pos_ball_10000;
ball_display bd0(.pos(pos_ball_10000), .white(ball_white));

always @(*) begin
    dist_sq=0;
    if(h_cnt >= (p1_x<<1)) dist_sq= dist_sq+ (h_cnt -(p1_x<<1))*(h_cnt -(p1_x<<1));
    else dist_sq= dist_sq+ ((p1_x<<1) - h_cnt )*((p1_x<<1) - h_cnt );
    if(v_cnt >= (p1_y<<1)) dist_sq= dist_sq+ (v_cnt -(p1_y<<1))*(v_cnt -(p1_y<<1));
    else dist_sq= dist_sq+ ((p1_y<<1) -v_cnt )*((p1_y<<1) - v_cnt );  // distance between p1 and current location

    dist_sq_to_p2=0;
    if(h_cnt >= (p2_x<<1)) dist_sq_to_p2= dist_sq_to_p2+ (h_cnt -(p2_x<<1))*(h_cnt -(p2_x<<1));
    else dist_sq_to_p2= dist_sq_to_p2+ ((p2_x<<1) - h_cnt )*((p2_x<<1) - h_cnt );
    if(v_cnt >= (p2_y<<1)) dist_sq_to_p2= dist_sq_to_p2+ (v_cnt -(p2_y<<1))*(v_cnt -(p2_y<<1));
    else dist_sq_to_p2= dist_sq_to_p2+ ((p2_y<<1) -v_cnt )*((p2_y<<1) - v_cnt );   // distance between p2 and current location

    pos_ball_10000=4950;
    pos_ball_10000=pos_ball_10000+ h_cnt-(ball_x<<1);
    if(v_cnt>= ball_y<<1) pos_ball_10000=pos_ball_10000+(v_cnt-(ball_y<<1))*100;
    else pos_ball_10000=pos_ball_10000-((ball_y<<1)-v_cnt)*100; // index of ball (10000)

    if(dist_sq<=800) pixel_out=pixel_player1; // the display size of p1
    else if(dist_sq_to_p2<=800)pixel_out=pixel_player2; //the display size for p2
    else if(((v_cnt >= (ball_y<<1) && v_cnt-(ball_y<<1) <= 50 )||(v_cnt < ball_y<<1 && (ball_y<<1)-v_cnt <= 50))
    && (((h_cnt >= ball_x<<1 && h_cnt-(ball_x<<1) <= 50 ))||(h_cnt < ball_x<<1 && (ball_x<<1)-h_cnt <= 50 )) 
    && ball_white==0) pixel_out=pixel_ball;
    else pixel_out=pixel_background;
end


endmodule

module clock_divider_1(clk_25MHz, clk);
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

module OnePulse (
	output reg signal_single_pulse,
	input wire signal,
	input wire clock
	);
	
	reg signal_delay;

	always @(posedge clock) begin
		if (signal == 1'b1 & signal_delay == 1'b0)
		  signal_single_pulse <= 1'b1;
		else
		  signal_single_pulse <= 1'b0;

		signal_delay <= signal;
	end
endmodule

`timescale 1ns/1ps
/////////////////////////////////////////////////////////////////
// Module Name: vga
/////////////////////////////////////////////////////////////////

module vga_controller (
    input wire pclk, reset,
    output wire hsync, vsync, valid,
    output wire [9:0]h_cnt,
    output wire [9:0]v_cnt
    );

    reg [9:0]pixel_cnt;
    reg [9:0]line_cnt;
    reg hsync_i,vsync_i;

    parameter HD = 640;
    parameter HF = 16;
    parameter HS = 96;
    parameter HB = 48;
    parameter HT = 800; 
    parameter VD = 480;
    parameter VF = 10;
    parameter VS = 2;
    parameter VB = 33;
    parameter VT = 525;
    parameter hsync_default = 1'b1;
    parameter vsync_default = 1'b1;

    always @(posedge pclk)
        if (reset)
            pixel_cnt <= 0;
        else
            if (pixel_cnt < (HT - 1))
                pixel_cnt <= pixel_cnt + 1;
            else
                pixel_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            hsync_i <= hsync_default;
        else
            if ((pixel_cnt >= (HD + HF - 1)) && (pixel_cnt < (HD + HF + HS - 1)))
                hsync_i <= ~hsync_default;
            else
                hsync_i <= hsync_default; 

    always @(posedge pclk)
        if (reset)
            line_cnt <= 0;
        else
            if (pixel_cnt == (HT -1))
                if (line_cnt < (VT - 1))
                    line_cnt <= line_cnt + 1;
                else
                    line_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            vsync_i <= vsync_default; 
        else if ((line_cnt >= (VD + VF - 1)) && (line_cnt < (VD + VF + VS - 1)))
            vsync_i <= ~vsync_default; 
        else
            vsync_i <= vsync_default; 

    assign hsync = hsync_i;
    assign vsync = vsync_i;
    assign valid = ((pixel_cnt < HD) && (line_cnt < VD));

    assign h_cnt = (pixel_cnt < HD) ? pixel_cnt : 10'd0;
    assign v_cnt = (line_cnt < VD) ? line_cnt : 10'd0;

endmodule

module ball_display(
    input [15:0]pos,
    output reg white
);



always@(*)begin

    if(pos==1228||
pos==1327||pos==1328||pos==1427||pos==1428||pos==1526||pos==1527||
pos==1528||pos==1555||pos==1625||pos==1626||pos==1627||pos==1654||
pos==1655||pos==1725||pos==1726||pos==1727||pos==1753||pos==1754||
pos==1755||pos==1825||pos==1826||pos==1827||pos==1852||pos==1853||
pos==1854||pos==1924||pos==1925||pos==1926||pos==1927||pos==1951||
pos==1952||pos==1953||pos==1954||pos==2024||pos==2025||pos==2026||
pos==2027||pos==2050||pos==2051||pos==2052||pos==2053||pos==2054||
pos==2124||pos==2125||pos==2126||pos==2127||pos==2150||pos==2151||
pos==2152||pos==2153||pos==2223||pos==2224||pos==2225||pos==2226||
pos==2227||pos==2249||pos==2250||pos==2251||pos==2252||pos==2253||
pos==2323||pos==2324||pos==2325||pos==2326||pos==2327||pos==2336||
pos==2348||pos==2349||pos==2350||pos==2351||pos==2352||pos==2422||
pos==2423||pos==2424||pos==2425||pos==2426||pos==2427||pos==2428||
pos==2429||pos==2430||pos==2431||pos==2432||pos==2433||pos==2434||
pos==2435||pos==2436||pos==2437||pos==2438||pos==2439||pos==2440||
pos==2441||pos==2442||pos==2443||pos==2444||pos==2445||pos==2446||
pos==2447||pos==2448||pos==2449||pos==2450||pos==2451||pos==2452||
pos==2522||pos==2523||pos==2524||pos==2525||pos==2526||pos==2527||
pos==2528||pos==2529||pos==2530||pos==2531||pos==2532||pos==2533||
pos==2534||pos==2535||pos==2536||pos==2537||pos==2538||pos==2539||
pos==2540||pos==2541||pos==2542||pos==2543||pos==2544||pos==2545||
pos==2546||pos==2547||pos==2548||pos==2549||pos==2550||pos==2551||
pos==2552||pos==2622||pos==2623||pos==2624||pos==2625||pos==2626||
pos==2627||pos==2628||pos==2629||pos==2630||pos==2631||pos==2632||
pos==2633||pos==2634||pos==2635||pos==2636||pos==2637||pos==2638||
pos==2639||pos==2640||pos==2641||pos==2642||pos==2643||pos==2644||
pos==2645||pos==2646||pos==2647||pos==2648||pos==2649||pos==2650||
pos==2651||pos==2652||pos==2722||pos==2723||pos==2724||pos==2725||
pos==2726||pos==2727||pos==2728||pos==2729||pos==2730||pos==2731||
pos==2732||pos==2733||pos==2734||pos==2735||pos==2736||pos==2737||
pos==2738||pos==2739||pos==2740||pos==2741||pos==2742||pos==2743||
pos==2744||pos==2745||pos==2746||pos==2747||pos==2748||pos==2749||
pos==2750||pos==2751||pos==2752||pos==2822||pos==2823||pos==2824||
pos==2825||pos==2826||pos==2827||pos==2828||pos==2829||pos==2830||
pos==2831||pos==2832||pos==2833||pos==2834||pos==2835||pos==2836||
pos==2837||pos==2838||pos==2839||pos==2840||pos==2841||pos==2842||
pos==2843||pos==2844||pos==2845||pos==2846||pos==2847||pos==2848||
pos==2849||pos==2850||pos==2851||pos==2852||pos==2922||pos==2923||
pos==2924||pos==2925||pos==2926||pos==2927||pos==2928||pos==2929||
pos==2930||pos==2931||pos==2932||pos==2933||pos==2934||pos==2935||
pos==2936||pos==2937||pos==2938||pos==2939||pos==2940||pos==2941||
pos==2942||pos==2943||pos==2944||pos==2945||pos==2946||pos==2947||
pos==2948||pos==2949||pos==2950||pos==2951||pos==2952||pos==3022||
pos==3023||pos==3024||pos==3025||pos==3026||pos==3027||pos==3028||
pos==3029||pos==3030||pos==3031||pos==3032||pos==3033||pos==3034||
pos==3035||pos==3036||pos==3037||pos==3038||pos==3039||pos==3040||
pos==3041||pos==3042||pos==3043||pos==3044||pos==3045||pos==3046||
pos==3047||pos==3048||pos==3049||pos==3050||pos==3051||pos==3052||
pos==3122||pos==3123||pos==3124||pos==3125||pos==3126||pos==3127||
pos==3128||pos==3129||pos==3130||pos==3131||pos==3132||pos==3133||
pos==3134||pos==3135||pos==3136||pos==3137||pos==3138||pos==3139||
pos==3140||pos==3141||pos==3142||pos==3143||pos==3144||pos==3145||
pos==3146||pos==3147||pos==3148||pos==3149||pos==3150||pos==3151||
pos==3152||pos==3153||pos==3222||pos==3223||pos==3224||pos==3225||
pos==3226||pos==3227||pos==3228||pos==3229||pos==3230||pos==3231||
pos==3232||pos==3233||pos==3234||pos==3235||pos==3236||pos==3237||
pos==3238||pos==3239||pos==3240||pos==3241||pos==3242||pos==3243||
pos==3244||pos==3245||pos==3246||pos==3247||pos==3248||pos==3249||
pos==3250||pos==3251||pos==3252||pos==3253||pos==3254||pos==3322||
pos==3323||pos==3324||pos==3325||pos==3326||pos==3327||pos==3328||
pos==3329||pos==3330||pos==3331||pos==3332||pos==3333||pos==3334||
pos==3335||pos==3336||pos==3337||pos==3338||pos==3339||pos==3340||
pos==3341||pos==3342||pos==3343||pos==3344||pos==3345||pos==3346||
pos==3347||pos==3348||pos==3349||pos==3350||pos==3351||pos==3352||
pos==3353||pos==3354||pos==3355||pos==3422||pos==3423||pos==3424||
pos==3425||pos==3426||pos==3427||pos==3428||pos==3429||pos==3430||
pos==3431||pos==3432||pos==3433||pos==3434||pos==3435||pos==3436||
pos==3437||pos==3438||pos==3439||pos==3440||pos==3441||pos==3442||
pos==3443||pos==3444||pos==3445||pos==3446||pos==3447||pos==3448||
pos==3449||pos==3450||pos==3451||pos==3452||pos==3453||pos==3454||
pos==3455||pos==3456||pos==3522||pos==3523||pos==3524||pos==3525||
pos==3526||pos==3527||pos==3528||pos==3529||pos==3530||pos==3531||
pos==3532||pos==3533||pos==3534||pos==3535||pos==3536||pos==3537||
pos==3538||pos==3539||pos==3540||pos==3541||pos==3542||pos==3543||
pos==3544||pos==3545||pos==3546||pos==3547||pos==3548||pos==3549||
pos==3550||pos==3551||pos==3552||pos==3553||pos==3554||pos==3555||
pos==3556||pos==3622||pos==3623||pos==3624||pos==3625||pos==3626||
pos==3627||pos==3628||pos==3629||pos==3630||pos==3631||pos==3632||
pos==3633||pos==3634||pos==3635||pos==3636||pos==3637||pos==3638||
pos==3639||pos==3640||pos==3641||pos==3642||pos==3643||pos==3644||
pos==3645||pos==3646||pos==3647||pos==3648||pos==3649||pos==3650||
pos==3651||pos==3652||pos==3653||pos==3654||pos==3655||pos==3656||
pos==3657||pos==3722||pos==3723||pos==3724||pos==3725||pos==3726||
pos==3727||pos==3728||pos==3729||pos==3730||pos==3731||pos==3732||
pos==3733||pos==3734||pos==3735||pos==3736||pos==3737||pos==3738||
pos==3739||pos==3740||pos==3741||pos==3742||pos==3743||pos==3744||
pos==3745||pos==3746||pos==3747||pos==3748||pos==3749||pos==3750||
pos==3751||pos==3752||pos==3753||pos==3754||pos==3755||pos==3756||
pos==3757||pos==3758||pos==3821||pos==3822||pos==3823||pos==3824||
pos==3825||pos==3826||pos==3827||pos==3828||pos==3829||pos==3830||
pos==3831||pos==3832||pos==3833||pos==3834||pos==3835||pos==3836||
pos==3837||pos==3838||pos==3839||pos==3840||pos==3841||pos==3842||
pos==3843||pos==3844||pos==3845||pos==3846||pos==3847||pos==3848||
pos==3849||pos==3850||pos==3851||pos==3852||pos==3853||pos==3854||
pos==3855||pos==3856||pos==3857||pos==3858||pos==3920||pos==3921||
pos==3922||pos==3923||pos==3924||pos==3925||pos==3926||pos==3927||
pos==3928||pos==3929||pos==3930||pos==3931||pos==3932||pos==3933||
pos==3934||pos==3935||pos==3936||pos==3937||pos==3938||pos==3939||
pos==3940||pos==3941||pos==3942||pos==3943||pos==3944||pos==3945||
pos==3946||pos==3947||pos==3948||pos==3949||pos==3950||pos==3951||
pos==3952||pos==3953||pos==3954||pos==3955||pos==3956||pos==3957||
pos==3958||pos==3959||pos==4020||pos==4021||pos==4022||pos==4023||
pos==4024||pos==4025||pos==4026||pos==4027||pos==4028||pos==4029||
pos==4030||pos==4031||pos==4032||pos==4033||pos==4034||pos==4035||
pos==4036||pos==4037||pos==4038||pos==4039||pos==4040||pos==4041||
pos==4042||pos==4043||pos==4044||pos==4045||pos==4046||pos==4047||
pos==4048||pos==4049||pos==4050||pos==4051||pos==4052||pos==4053||
pos==4054||pos==4055||pos==4056||pos==4057||pos==4058||pos==4059||
pos==4119||pos==4120||pos==4121||pos==4122||pos==4123||pos==4124||
pos==4125||pos==4126||pos==4127||pos==4128||pos==4129||pos==4130||
pos==4131||pos==4132||pos==4133||pos==4134||pos==4135||pos==4136||
pos==4137||pos==4138||pos==4139||pos==4140||pos==4141||pos==4142||
pos==4143||pos==4144||pos==4145||pos==4146||pos==4147||pos==4148||
pos==4149||pos==4150||pos==4151||pos==4152||pos==4153||pos==4154||
pos==4155||pos==4156||pos==4157||pos==4158||pos==4159||pos==4160||
pos==4219||pos==4220||pos==4221||pos==4222||pos==4223||pos==4224||
pos==4225||pos==4226||pos==4227||pos==4228||pos==4229||pos==4230||
pos==4231||pos==4232||pos==4233||pos==4234||pos==4235||pos==4236||
pos==4237||pos==4238||pos==4239||pos==4240||pos==4241||pos==4242||
pos==4243||pos==4244||pos==4245||pos==4246||pos==4247||pos==4248||
pos==4249||pos==4250||pos==4251||pos==4252||pos==4253||pos==4254||
pos==4255||pos==4256||pos==4257||pos==4258||pos==4259||pos==4260||
pos==4318||pos==4319||pos==4320||pos==4321||pos==4322||pos==4323||
pos==4324||pos==4325||pos==4326||pos==4327||pos==4328||pos==4329||
pos==4330||pos==4331||pos==4332||pos==4333||pos==4334||pos==4335||
pos==4336||pos==4337||pos==4338||pos==4339||pos==4340||pos==4341||
pos==4342||pos==4343||pos==4344||pos==4345||pos==4346||pos==4347||
pos==4348||pos==4349||pos==4350||pos==4351||pos==4352||pos==4353||
pos==4354||pos==4355||pos==4356||pos==4357||pos==4358||pos==4359||
pos==4360||pos==4418||pos==4419||pos==4420||pos==4421||pos==4422||
pos==4423||pos==4424||pos==4425||pos==4426||pos==4427||pos==4428||
pos==4429||pos==4430||pos==4431||pos==4432||pos==4433||pos==4434||
pos==4435||pos==4436||pos==4437||pos==4438||pos==4439||pos==4440||
pos==4441||pos==4442||pos==4443||pos==4444||pos==4445||pos==4446||
pos==4447||pos==4448||pos==4449||pos==4450||pos==4451||pos==4452||
pos==4453||pos==4454||pos==4455||pos==4456||pos==4457||pos==4458||
pos==4459||pos==4460||pos==4461||pos==4517||pos==4518||pos==4519||
pos==4520||pos==4521||pos==4522||pos==4523||pos==4524||pos==4525||
pos==4526||pos==4527||pos==4528||pos==4529||pos==4530||pos==4531||
pos==4532||pos==4533||pos==4534||pos==4535||pos==4536||pos==4537||
pos==4538||pos==4539||pos==4540||pos==4541||pos==4542||pos==4543||
pos==4544||pos==4545||pos==4546||pos==4547||pos==4548||pos==4549||
pos==4550||pos==4551||pos==4552||pos==4553||pos==4554||pos==4555||
pos==4556||pos==4557||pos==4558||pos==4559||pos==4560||pos==4561||
pos==4617||pos==4618||pos==4619||pos==4620||pos==4621||pos==4622||
pos==4623||pos==4624||pos==4625||pos==4626||pos==4627||pos==4628||
pos==4629||pos==4630||pos==4631||pos==4632||pos==4633||pos==4634||
pos==4635||pos==4636||pos==4637||pos==4638||pos==4639||pos==4640||
pos==4641||pos==4642||pos==4643||pos==4644||pos==4645||pos==4646||
pos==4647||pos==4648||pos==4649||pos==4650||pos==4651||pos==4652||
pos==4653||pos==4654||pos==4655||pos==4656||pos==4657||pos==4658||
pos==4659||pos==4660||pos==4661||pos==4716||pos==4717||pos==4718||
pos==4719||pos==4720||pos==4721||pos==4722||pos==4723||pos==4724||
pos==4725||pos==4726||pos==4727||pos==4728||pos==4729||pos==4730||
pos==4731||pos==4732||pos==4733||pos==4734||pos==4735||pos==4736||
pos==4737||pos==4738||pos==4739||pos==4740||pos==4741||pos==4742||
pos==4743||pos==4744||pos==4745||pos==4746||pos==4747||pos==4748||
pos==4749||pos==4750||pos==4751||pos==4752||pos==4753||pos==4754||
pos==4755||pos==4756||pos==4757||pos==4758||pos==4759||pos==4760||
pos==4761||pos==4816||pos==4817||pos==4818||pos==4819||pos==4820||
pos==4821||pos==4822||pos==4823||pos==4824||pos==4825||pos==4826||
pos==4827||pos==4828||pos==4829||pos==4830||pos==4831||pos==4832||
pos==4833||pos==4834||pos==4835||pos==4836||pos==4837||pos==4838||
pos==4839||pos==4840||pos==4841||pos==4842||pos==4843||pos==4844||
pos==4845||pos==4846||pos==4847||pos==4848||pos==4849||pos==4850||
pos==4851||pos==4852||pos==4853||pos==4854||pos==4855||pos==4856||
pos==4857||pos==4858||pos==4859||pos==4860||pos==4861||pos==4916||
pos==4917||pos==4918||pos==4919||pos==4920||pos==4921||pos==4922||
pos==4923||pos==4924||pos==4925||pos==4926||pos==4927||pos==4928||
pos==4929||pos==4930||pos==4931||pos==4932||pos==4933||pos==4934||
pos==4935||pos==4936||pos==4937||pos==4938||pos==4939||pos==4940||
pos==4941||pos==4942||pos==4943||pos==4944||pos==4945||pos==4946||
pos==4947||pos==4948||pos==4949||pos==4950||pos==4951||pos==4952||
pos==4953||pos==4954||pos==4955||pos==4956||pos==4957||pos==4958||
pos==4959||pos==4960||pos==4961||pos==4962||pos==5016||pos==5017||
pos==5018||pos==5019||pos==5020||pos==5021||pos==5022||pos==5023||
pos==5024||pos==5025||pos==5026||pos==5027||pos==5028||pos==5029||
pos==5030||pos==5031||pos==5032||pos==5033||pos==5034||pos==5035||
pos==5036||pos==5037||pos==5038||pos==5039||pos==5040||pos==5041||
pos==5042||pos==5043||pos==5044||pos==5045||pos==5046||pos==5047||
pos==5048||pos==5049||pos==5050||pos==5051||pos==5052||pos==5053||
pos==5054||pos==5055||pos==5056||pos==5057||pos==5058||pos==5059||
pos==5060||pos==5061||pos==5062||pos==5116||pos==5117||pos==5118||
pos==5119||pos==5120||pos==5121||pos==5122||pos==5123||pos==5124||
pos==5125||pos==5126||pos==5127||pos==5128||pos==5129||pos==5130||
pos==5131||pos==5132||pos==5133||pos==5134||pos==5135||pos==5136||
pos==5137||pos==5138||pos==5139||pos==5140||pos==5141||pos==5142||
pos==5143||pos==5144||pos==5145||pos==5146||pos==5147||pos==5148||
pos==5149||pos==5150||pos==5151||pos==5152||pos==5153||pos==5154||
pos==5155||pos==5156||pos==5157||pos==5158||pos==5159||pos==5160||
pos==5161||pos==5162||pos==5216||pos==5217||pos==5218||pos==5219||
pos==5220||pos==5221||pos==5222||pos==5223||pos==5224||pos==5225||
pos==5226||pos==5227||pos==5228||pos==5229||pos==5230||pos==5231||
pos==5232||pos==5233||pos==5234||pos==5235||pos==5236||pos==5237||
pos==5238||pos==5239||pos==5240||pos==5241||pos==5242||pos==5243||
pos==5244||pos==5245||pos==5246||pos==5247||pos==5248||pos==5249||
pos==5250||pos==5251||pos==5252||pos==5253||pos==5254||pos==5255||
pos==5256||pos==5257||pos==5258||pos==5259||pos==5260||pos==5261||
pos==5262||pos==5283||pos==5284||pos==5285||pos==5286||pos==5287||
pos==5288||pos==5289||pos==5316||pos==5317||pos==5318||pos==5319||
pos==5320||pos==5321||pos==5322||pos==5323||pos==5324||pos==5325||
pos==5326||pos==5327||pos==5328||pos==5329||pos==5330||pos==5331||
pos==5332||pos==5333||pos==5334||pos==5335||pos==5336||pos==5337||
pos==5338||pos==5339||pos==5340||pos==5341||pos==5342||pos==5343||
pos==5344||pos==5345||pos==5346||pos==5347||pos==5348||pos==5349||
pos==5350||pos==5351||pos==5352||pos==5353||pos==5354||pos==5355||
pos==5356||pos==5357||pos==5358||pos==5359||pos==5360||pos==5361||
pos==5362||pos==5379||pos==5380||pos==5381||pos==5382||pos==5383||
pos==5384||pos==5385||pos==5386||pos==5387||pos==5388||pos==5389||
pos==5415||pos==5416||pos==5417||pos==5418||pos==5419||pos==5420||
pos==5421||pos==5422||pos==5423||pos==5424||pos==5425||pos==5426||
pos==5427||pos==5428||pos==5429||pos==5430||pos==5431||pos==5432||
pos==5433||pos==5434||pos==5435||pos==5436||pos==5437||pos==5438||
pos==5439||pos==5440||pos==5441||pos==5442||pos==5443||pos==5444||
pos==5445||pos==5446||pos==5447||pos==5448||pos==5449||pos==5450||
pos==5451||pos==5452||pos==5453||pos==5454||pos==5455||pos==5456||
pos==5457||pos==5458||pos==5459||pos==5460||pos==5461||pos==5462||
pos==5477||pos==5478||pos==5479||pos==5480||pos==5481||pos==5482||
pos==5483||pos==5484||pos==5485||pos==5486||pos==5487||pos==5488||
pos==5489||pos==5515||pos==5516||pos==5517||pos==5518||pos==5519||
pos==5520||pos==5521||pos==5522||pos==5523||pos==5524||pos==5525||
pos==5526||pos==5527||pos==5528||pos==5529||pos==5530||pos==5531||
pos==5532||pos==5533||pos==5534||pos==5535||pos==5536||pos==5537||
pos==5538||pos==5539||pos==5540||pos==5541||pos==5542||pos==5543||
pos==5544||pos==5545||pos==5546||pos==5547||pos==5548||pos==5549||
pos==5550||pos==5551||pos==5552||pos==5553||pos==5554||pos==5555||
pos==5556||pos==5557||pos==5558||pos==5559||pos==5560||pos==5561||
pos==5562||pos==5575||pos==5576||pos==5577||pos==5578||pos==5579||
pos==5580||pos==5581||pos==5582||pos==5583||pos==5584||pos==5585||
pos==5586||pos==5587||pos==5588||pos==5589||pos==5615||pos==5616||
pos==5617||pos==5618||pos==5619||pos==5620||pos==5621||pos==5622||
pos==5623||pos==5624||pos==5625||pos==5626||pos==5627||pos==5628||
pos==5629||pos==5630||pos==5631||pos==5632||pos==5633||pos==5634||
pos==5635||pos==5636||pos==5637||pos==5638||pos==5639||pos==5640||
pos==5641||pos==5642||pos==5643||pos==5644||pos==5645||pos==5646||
pos==5647||pos==5648||pos==5649||pos==5650||pos==5651||pos==5652||
pos==5653||pos==5654||pos==5655||pos==5656||pos==5657||pos==5658||
pos==5659||pos==5660||pos==5661||pos==5662||pos==5673||pos==5674||
pos==5675||pos==5676||pos==5677||pos==5678||pos==5679||pos==5680||
pos==5681||pos==5682||pos==5683||pos==5684||pos==5685||pos==5686||
pos==5687||pos==5688||pos==5689||pos==5714||pos==5715||pos==5716||
pos==5717||pos==5718||pos==5719||pos==5720||pos==5721||pos==5722||
pos==5723||pos==5724||pos==5725||pos==5726||pos==5727||pos==5728||
pos==5729||pos==5730||pos==5731||pos==5732||pos==5733||pos==5734||
pos==5735||pos==5736||pos==5737||pos==5738||pos==5739||pos==5740||
pos==5741||pos==5742||pos==5743||pos==5744||pos==5745||pos==5746||
pos==5747||pos==5748||pos==5749||pos==5750||pos==5751||pos==5752||
pos==5753||pos==5754||pos==5755||pos==5756||pos==5757||pos==5758||
pos==5759||pos==5760||pos==5761||pos==5762||pos==5772||pos==5773||
pos==5774||pos==5775||pos==5776||pos==5777||pos==5778||pos==5779||
pos==5780||pos==5781||pos==5782||pos==5783||pos==5784||pos==5785||
pos==5786||pos==5787||pos==5788||pos==5789||pos==5814||pos==5815||
pos==5816||pos==5817||pos==5818||pos==5819||pos==5820||pos==5821||
pos==5822||pos==5823||pos==5824||pos==5825||pos==5826||pos==5827||
pos==5828||pos==5829||pos==5830||pos==5831||pos==5832||pos==5833||
pos==5834||pos==5835||pos==5836||pos==5837||pos==5838||pos==5839||
pos==5840||pos==5841||pos==5842||pos==5843||pos==5844||pos==5845||
pos==5846||pos==5847||pos==5848||pos==5849||pos==5850||pos==5851||
pos==5852||pos==5853||pos==5854||pos==5855||pos==5856||pos==5857||
pos==5858||pos==5859||pos==5860||pos==5861||pos==5862||pos==5872||
pos==5873||pos==5874||pos==5875||pos==5876||pos==5877||pos==5878||
pos==5879||pos==5880||pos==5881||pos==5882||pos==5883||pos==5884||
pos==5885||pos==5886||pos==5887||pos==5888||pos==5889||pos==5914||
pos==5915||pos==5916||pos==5917||pos==5918||pos==5919||pos==5920||
pos==5921||pos==5922||pos==5923||pos==5924||pos==5925||pos==5926||
pos==5927||pos==5928||pos==5929||pos==5930||pos==5931||pos==5932||
pos==5933||pos==5934||pos==5935||pos==5936||pos==5937||pos==5938||
pos==5939||pos==5940||pos==5941||pos==5942||pos==5943||pos==5944||
pos==5945||pos==5946||pos==5947||pos==5948||pos==5949||pos==5950||
pos==5951||pos==5952||pos==5953||pos==5954||pos==5955||pos==5956||
pos==5957||pos==5958||pos==5959||pos==5960||pos==5961||pos==5962||
pos==5972||pos==5973||pos==5974||pos==5975||pos==5976||pos==5977||
pos==5978||pos==5979||pos==5980||pos==5981||pos==5982||pos==5983||
pos==5984||pos==5985||pos==5986||pos==5987||pos==5988||pos==5989||
pos==6014||pos==6015||pos==6016||pos==6017||pos==6018||pos==6019||
pos==6020||pos==6021||pos==6022||pos==6023||pos==6024||pos==6025||
pos==6026||pos==6027||pos==6028||pos==6029||pos==6030||pos==6031||
pos==6032||pos==6033||pos==6034||pos==6035||pos==6036||pos==6037||
pos==6038||pos==6039||pos==6040||pos==6041||pos==6042||pos==6043||
pos==6044||pos==6045||pos==6046||pos==6047||pos==6048||pos==6049||
pos==6050||pos==6051||pos==6052||pos==6053||pos==6054||pos==6055||
pos==6056||pos==6057||pos==6058||pos==6059||pos==6060||pos==6061||
pos==6062||pos==6072||pos==6073||pos==6074||pos==6075||pos==6076||
pos==6077||pos==6078||pos==6079||pos==6080||pos==6081||pos==6082||
pos==6083||pos==6084||pos==6085||pos==6086||pos==6087||pos==6088||
pos==6114||pos==6115||pos==6116||pos==6117||pos==6118||pos==6119||
pos==6120||pos==6121||pos==6122||pos==6123||pos==6124||pos==6125||
pos==6126||pos==6127||pos==6128||pos==6129||pos==6130||pos==6131||
pos==6132||pos==6133||pos==6134||pos==6135||pos==6136||pos==6137||
pos==6138||pos==6139||pos==6140||pos==6141||pos==6142||pos==6143||
pos==6144||pos==6145||pos==6146||pos==6147||pos==6148||pos==6149||
pos==6150||pos==6151||pos==6152||pos==6153||pos==6154||pos==6155||
pos==6156||pos==6157||pos==6158||pos==6159||pos==6160||pos==6161||
pos==6162||pos==6172||pos==6173||pos==6174||pos==6175||pos==6176||
pos==6177||pos==6178||pos==6179||pos==6180||pos==6181||pos==6182||
pos==6183||pos==6184||pos==6185||pos==6186||pos==6187||pos==6188||
pos==6214||pos==6215||pos==6216||pos==6217||pos==6218||pos==6219||
pos==6220||pos==6221||pos==6222||pos==6223||pos==6224||pos==6225||
pos==6226||pos==6227||pos==6228||pos==6229||pos==6230||pos==6231||
pos==6232||pos==6233||pos==6234||pos==6235||pos==6236||pos==6237||
pos==6238||pos==6239||pos==6240||pos==6241||pos==6242||pos==6243||
pos==6244||pos==6245||pos==6246||pos==6247||pos==6248||pos==6249||
pos==6250||pos==6251||pos==6252||pos==6253||pos==6254||pos==6255||
pos==6256||pos==6257||pos==6258||pos==6259||pos==6260||pos==6261||
pos==6262||pos==6272||pos==6273||pos==6274||pos==6275||pos==6276||
pos==6277||pos==6278||pos==6279||pos==6280||pos==6281||pos==6282||
pos==6283||pos==6284||pos==6285||pos==6286||pos==6287||pos==6288||
pos==6314||pos==6315||pos==6316||pos==6317||pos==6318||pos==6319||
pos==6320||pos==6321||pos==6322||pos==6323||pos==6324||pos==6325||
pos==6326||pos==6327||pos==6328||pos==6329||pos==6330||pos==6331||
pos==6332||pos==6333||pos==6334||pos==6335||pos==6336||pos==6337||
pos==6338||pos==6339||pos==6340||pos==6341||pos==6342||pos==6343||
pos==6344||pos==6345||pos==6346||pos==6347||pos==6348||pos==6349||
pos==6350||pos==6351||pos==6352||pos==6353||pos==6354||pos==6355||
pos==6356||pos==6357||pos==6358||pos==6359||pos==6360||pos==6361||
pos==6362||pos==6372||pos==6373||pos==6374||pos==6375||pos==6376||
pos==6377||pos==6378||pos==6379||pos==6380||pos==6381||pos==6382||
pos==6383||pos==6384||pos==6385||pos==6386||pos==6387||pos==6388||
pos==6414||pos==6415||pos==6416||pos==6417||pos==6418||pos==6419||
pos==6420||pos==6421||pos==6422||pos==6423||pos==6424||pos==6425||
pos==6426||pos==6427||pos==6428||pos==6429||pos==6430||pos==6431||
pos==6432||pos==6433||pos==6434||pos==6435||pos==6436||pos==6437||
pos==6438||pos==6439||pos==6440||pos==6441||pos==6442||pos==6443||
pos==6444||pos==6445||pos==6446||pos==6447||pos==6448||pos==6449||
pos==6450||pos==6451||pos==6452||pos==6453||pos==6454||pos==6455||
pos==6456||pos==6457||pos==6458||pos==6459||pos==6460||pos==6461||
pos==6462||pos==6468||pos==6469||pos==6470||pos==6471||pos==6472||
pos==6473||pos==6474||pos==6475||pos==6476||pos==6477||pos==6478||
pos==6479||pos==6480||pos==6481||pos==6482||pos==6483||pos==6484||
pos==6485||pos==6486||pos==6487||pos==6488||pos==6515||pos==6516||
pos==6517||pos==6518||pos==6519||pos==6520||pos==6521||pos==6522||
pos==6523||pos==6524||pos==6525||pos==6526||pos==6527||pos==6528||
pos==6529||pos==6530||pos==6531||pos==6532||pos==6533||pos==6534||
pos==6535||pos==6536||pos==6537||pos==6538||pos==6539||pos==6540||
pos==6541||pos==6542||pos==6543||pos==6544||pos==6545||pos==6546||
pos==6547||pos==6548||pos==6549||pos==6550||pos==6551||pos==6552||
pos==6553||pos==6554||pos==6555||pos==6556||pos==6557||pos==6558||
pos==6559||pos==6560||pos==6561||pos==6562||pos==6568||pos==6569||
pos==6570||pos==6571||pos==6572||pos==6573||pos==6574||pos==6575||
pos==6576||pos==6577||pos==6578||pos==6579||pos==6580||pos==6581||
pos==6582||pos==6583||pos==6584||pos==6585||pos==6586||pos==6587||
pos==6588||pos==6615||pos==6616||pos==6617||pos==6618||pos==6619||
pos==6620||pos==6621||pos==6622||pos==6623||pos==6624||pos==6625||
pos==6626||pos==6627||pos==6628||pos==6629||pos==6630||pos==6631||
pos==6632||pos==6633||pos==6634||pos==6635||pos==6636||pos==6637||
pos==6638||pos==6639||pos==6640||pos==6641||pos==6642||pos==6643||
pos==6644||pos==6645||pos==6646||pos==6647||pos==6648||pos==6649||
pos==6650||pos==6651||pos==6652||pos==6653||pos==6654||pos==6655||
pos==6656||pos==6657||pos==6658||pos==6659||pos==6660||pos==6661||
pos==6662||pos==6663||pos==6664||pos==6665||pos==6666||pos==6667||
pos==6668||pos==6669||pos==6670||pos==6671||pos==6672||pos==6673||
pos==6674||pos==6675||pos==6676||pos==6677||pos==6678||pos==6679||
pos==6680||pos==6681||pos==6682||pos==6683||pos==6684||pos==6685||
pos==6686||pos==6687||pos==6715||pos==6716||pos==6717||pos==6718||
pos==6719||pos==6720||pos==6721||pos==6722||pos==6723||pos==6724||
pos==6725||pos==6726||pos==6727||pos==6728||pos==6729||pos==6730||
pos==6731||pos==6732||pos==6733||pos==6734||pos==6735||pos==6736||
pos==6737||pos==6738||pos==6739||pos==6740||pos==6741||pos==6742||
pos==6743||pos==6744||pos==6745||pos==6746||pos==6747||pos==6748||
pos==6749||pos==6750||pos==6751||pos==6752||pos==6753||pos==6754||
pos==6755||pos==6756||pos==6757||pos==6758||pos==6759||pos==6760||
pos==6761||pos==6762||pos==6763||pos==6764||pos==6765||pos==6766||
pos==6767||pos==6768||pos==6769||pos==6770||pos==6771||pos==6778||
pos==6779||pos==6780||pos==6781||pos==6782||pos==6783||pos==6784||
pos==6785||pos==6786||pos==6815||pos==6816||pos==6817||pos==6818||
pos==6819||pos==6820||pos==6821||pos==6822||pos==6823||pos==6824||
pos==6825||pos==6826||pos==6827||pos==6828||pos==6829||pos==6830||
pos==6831||pos==6832||pos==6833||pos==6834||pos==6835||pos==6836||
pos==6837||pos==6838||pos==6839||pos==6840||pos==6841||pos==6842||
pos==6843||pos==6844||pos==6845||pos==6846||pos==6847||pos==6848||
pos==6849||pos==6850||pos==6851||pos==6852||pos==6853||pos==6854||
pos==6855||pos==6856||pos==6857||pos==6858||pos==6859||pos==6860||
pos==6861||pos==6862||pos==6863||pos==6864||pos==6865||pos==6866||
pos==6867||pos==6868||pos==6869||pos==6881||pos==6882||pos==6883||
pos==6884||pos==6885||pos==6886||pos==6916||pos==6917||pos==6918||
pos==6919||pos==6920||pos==6921||pos==6922||pos==6923||pos==6924||
pos==6925||pos==6926||pos==6927||pos==6928||pos==6929||pos==6930||
pos==6931||pos==6932||pos==6933||pos==6934||pos==6935||pos==6936||
pos==6937||pos==6938||pos==6939||pos==6940||pos==6941||pos==6942||
pos==6943||pos==6944||pos==6945||pos==6946||pos==6947||pos==6948||
pos==6949||pos==6950||pos==6951||pos==6952||pos==6953||pos==6954||
pos==6955||pos==6956||pos==6957||pos==6958||pos==6959||pos==6960||
pos==6961||pos==6962||pos==6963||pos==6964||pos==6965||pos==6966||
pos==6967||pos==6968||pos==6983||pos==6984||pos==6985||pos==6986||
pos==7016||pos==7017||pos==7018||pos==7019||pos==7020||pos==7021||
pos==7022||pos==7023||pos==7024||pos==7025||pos==7026||pos==7027||
pos==7028||pos==7029||pos==7030||pos==7031||pos==7032||pos==7033||
pos==7034||pos==7035||pos==7036||pos==7037||pos==7038||pos==7039||
pos==7040||pos==7041||pos==7042||pos==7043||pos==7044||pos==7045||
pos==7046||pos==7047||pos==7048||pos==7049||pos==7050||pos==7051||
pos==7052||pos==7053||pos==7054||pos==7055||pos==7056||pos==7057||
pos==7058||pos==7059||pos==7060||pos==7068||pos==7085||pos==7086||
pos==7116||pos==7117||pos==7118||pos==7119||pos==7120||pos==7121||
pos==7122||pos==7123||pos==7124||pos==7125||pos==7126||pos==7127||
pos==7128||pos==7129||pos==7130||pos==7131||pos==7132||pos==7133||
pos==7134||pos==7135||pos==7136||pos==7137||pos==7138||pos==7139||
pos==7140||pos==7141||pos==7142||pos==7143||pos==7144||pos==7145||
pos==7146||pos==7147||pos==7148||pos==7149||pos==7150||pos==7151||
pos==7152||pos==7153||pos==7154||pos==7155||pos==7156||pos==7157||
pos==7158||pos==7159||pos==7160||pos==7186||pos==7216||pos==7217||
pos==7218||pos==7219||pos==7220||pos==7221||pos==7222||pos==7223||
pos==7224||pos==7225||pos==7226||pos==7227||pos==7228||pos==7229||
pos==7230||pos==7231||pos==7232||pos==7233||pos==7234||pos==7235||
pos==7236||pos==7237||pos==7238||pos==7239||pos==7240||pos==7241||
pos==7242||pos==7243||pos==7244||pos==7245||pos==7246||pos==7247||
pos==7248||pos==7249||pos==7250||pos==7251||pos==7252||pos==7253||
pos==7254||pos==7255||pos==7256||pos==7257||pos==7258||pos==7259||
pos==7316||pos==7317||pos==7318||pos==7319||pos==7320||pos==7321||
pos==7322||pos==7323||pos==7324||pos==7325||pos==7326||pos==7327||
pos==7328||pos==7329||pos==7330||pos==7331||pos==7332||pos==7333||
pos==7334||pos==7335||pos==7336||pos==7337||pos==7338||pos==7339||
pos==7340||pos==7341||pos==7342||pos==7343||pos==7344||pos==7345||
pos==7346||pos==7347||pos==7348||pos==7349||pos==7350||pos==7351||
pos==7352||pos==7353||pos==7354||pos==7355||pos==7356||pos==7357||
pos==7358||pos==7359||pos==7416||pos==7417||pos==7418||pos==7419||
pos==7420||pos==7421||pos==7422||pos==7423||pos==7424||pos==7425||
pos==7426||pos==7427||pos==7428||pos==7429||pos==7430||pos==7431||
pos==7432||pos==7433||pos==7434||pos==7435||pos==7436||pos==7437||
pos==7438||pos==7439||pos==7440||pos==7441||pos==7442||pos==7443||
pos==7444||pos==7445||pos==7446||pos==7447||pos==7448||pos==7449||
pos==7450||pos==7451||pos==7452||pos==7453||pos==7454||pos==7455||
pos==7456||pos==7457||pos==7458||pos==7517||pos==7518||pos==7519||
pos==7520||pos==7521||pos==7522||pos==7523||pos==7524||pos==7525||
pos==7526||pos==7527||pos==7528||pos==7529||pos==7530||pos==7531||
pos==7532||pos==7533||pos==7534||pos==7535||pos==7536||pos==7537||
pos==7538||pos==7539||pos==7540||pos==7541||pos==7542||pos==7543||
pos==7544||pos==7545||pos==7546||pos==7547||pos==7548||pos==7549||
pos==7550||pos==7551||pos==7552||pos==7553||pos==7554||pos==7555||
pos==7556||pos==7557||pos==7617||pos==7618||pos==7619||pos==7620||
pos==7621||pos==7622||pos==7623||pos==7624||pos==7625||pos==7626||
pos==7627||pos==7628||pos==7629||pos==7630||pos==7631||pos==7632||
pos==7633||pos==7634||pos==7635||pos==7636||pos==7637||pos==7638||
pos==7639||pos==7640||pos==7641||pos==7642||pos==7643||pos==7644||
pos==7645||pos==7646||pos==7647||pos==7648||pos==7649||pos==7650||
pos==7651||pos==7652||pos==7653||pos==7654||pos==7655||pos==7656||
pos==7657||pos==7718||pos==7719||pos==7720||pos==7721||pos==7722||
pos==7723||pos==7724||pos==7725||pos==7726||pos==7727||pos==7728||
pos==7729||pos==7730||pos==7731||pos==7732||pos==7733||pos==7734||
pos==7735||pos==7736||pos==7737||pos==7738||pos==7739||pos==7740||
pos==7741||pos==7742||pos==7743||pos==7744||pos==7745||pos==7746||
pos==7747||pos==7748||pos==7749||pos==7750||pos==7751||pos==7752||
pos==7753||pos==7754||pos==7755||pos==7756||pos==7757||pos==7818||
pos==7819||pos==7820||pos==7821||pos==7822||pos==7823||pos==7824||
pos==7825||pos==7826||pos==7827||pos==7828||pos==7829||pos==7830||
pos==7831||pos==7832||pos==7833||pos==7834||pos==7835||pos==7836||
pos==7837||pos==7838||pos==7839||pos==7840||pos==7841||pos==7842||
pos==7843||pos==7844||pos==7845||pos==7846||pos==7847||pos==7848||
pos==7849||pos==7850||pos==7851||pos==7852||pos==7853||pos==7854||
pos==7855||pos==7856||pos==7918||pos==7919||pos==7920||pos==7921||
pos==7922||pos==7923||pos==7924||pos==7925||pos==7926||pos==7927||
pos==7928||pos==7929||pos==7930||pos==7931||pos==7932||pos==7933||
pos==7934||pos==7935||pos==7936||pos==7937||pos==7938||pos==7939||
pos==7940||pos==7941||pos==7942||pos==7943||pos==7944||pos==7945||
pos==7946||pos==7947||pos==7948||pos==7949||pos==7950||pos==7951||
pos==7952||pos==7953||pos==7954||pos==7955||pos==7956||pos==8019||
pos==8020||pos==8021||pos==8022||pos==8023||pos==8024||pos==8025||
pos==8026||pos==8027||pos==8028||pos==8029||pos==8030||pos==8031||
pos==8032||pos==8033||pos==8034||pos==8035||pos==8036||pos==8037||
pos==8038||pos==8039||pos==8040||pos==8041||pos==8042||pos==8043||
pos==8044||pos==8045||pos==8046||pos==8047||pos==8048||pos==8049||
pos==8050||pos==8051||pos==8052||pos==8053||pos==8054||pos==8055||
pos==8056||pos==8119||pos==8120||pos==8121||pos==8122||pos==8123||
pos==8124||pos==8125||pos==8126||pos==8127||pos==8128||pos==8129||
pos==8130||pos==8131||pos==8132||pos==8133||pos==8134||pos==8135||
pos==8136||pos==8137||pos==8138||pos==8139||pos==8140||pos==8141||
pos==8142||pos==8143||pos==8144||pos==8145||pos==8146||pos==8147||
pos==8148||pos==8149||pos==8150||pos==8151||pos==8152||pos==8153||
pos==8154||pos==8155||pos==8156||pos==8220||pos==8221||pos==8222||
pos==8223||pos==8224||pos==8225||pos==8226||pos==8227||pos==8228||
pos==8229||pos==8230||pos==8231||pos==8232||pos==8233||pos==8234||
pos==8235||pos==8236||pos==8237||pos==8238||pos==8239||pos==8240||
pos==8241||pos==8242||pos==8243||pos==8244||pos==8245||pos==8246||
pos==8247||pos==8248||pos==8249||pos==8250||pos==8251||pos==8252||
pos==8253||pos==8254||pos==8255||pos==8256||pos==8320||pos==8321||
pos==8322||pos==8323||pos==8324||pos==8325||pos==8326||pos==8327||
pos==8328||pos==8329||pos==8330||pos==8331||pos==8332||pos==8333||
pos==8334||pos==8335||pos==8336||pos==8337||pos==8338||pos==8339||
pos==8340||pos==8341||pos==8342||pos==8343||pos==8344||pos==8345||
pos==8346||pos==8347||pos==8348||pos==8349||pos==8350||pos==8351||
pos==8352||pos==8353||pos==8354||pos==8355||pos==8356||pos==8421||
pos==8422||pos==8423||pos==8424||pos==8425||pos==8426||pos==8427||
pos==8428||pos==8429||pos==8430||pos==8431||pos==8432||pos==8433||
pos==8434||pos==8435||pos==8436||pos==8437||pos==8438||pos==8439||
pos==8440||pos==8441||pos==8442||pos==8443||pos==8444||pos==8445||
pos==8446||pos==8447||pos==8448||pos==8449||pos==8450||pos==8451||
pos==8452||pos==8453||pos==8522||pos==8523||pos==8524||pos==8525||
pos==8526||pos==8527||pos==8528||pos==8529||pos==8530||pos==8531||
pos==8532||pos==8533||pos==8534||pos==8535||pos==8536||pos==8537||
pos==8538||pos==8539||pos==8540||pos==8541||pos==8542||pos==8543||
pos==8544||pos==8545||pos==8546||pos==8547||pos==8548||pos==8549||
pos==8550||pos==8551||pos==8623||pos==8624||pos==8625||pos==8626||
pos==8627||pos==8628||pos==8629||pos==8630||pos==8631||pos==8632||
pos==8633||pos==8634||pos==8635||pos==8636||pos==8637||pos==8638||
pos==8639||pos==8640||pos==8641||pos==8642||pos==8643||pos==8644||
pos==8645||pos==8646||pos==8647||pos==8648||pos==8649||pos==8650||
pos==8725||pos==8726||pos==8727||pos==8728||pos==8729||pos==8730||
pos==8731||pos==8732||pos==8733||pos==8734||pos==8735||pos==8736||
pos==8737||pos==8738||pos==8739||pos==8740||pos==8741||pos==8742||
pos==8743||pos==8744||pos==8745||pos==8746||pos==8747||pos==8748||
pos==8749||pos==8826||pos==8827||pos==8828||pos==8829||pos==8830||
pos==8831||pos==8832||pos==8833||pos==8834||pos==8835||pos==8836||
pos==8837||pos==8838||pos==8839||pos==8840||pos==8841||pos==8842||
pos==8843||pos==8844||pos==8845||pos==8846||pos==8847||pos==8927||
pos==8928||pos==8929||pos==8930||pos==8931||pos==8932||pos==8933||
pos==8934||pos==8935||pos==8936||pos==8937||pos==8938||pos==8939||
pos==8940||pos==8941||pos==8942||pos==8943||pos==8944||pos==8945||
pos==8946||pos==9028||pos==9029||pos==9030||pos==9031||pos==9032||
pos==9033||pos==9034||pos==9035||pos==9036||pos==9037||pos==9038||
pos==9039||pos==9040||pos==9041||pos==9042||pos==9043||pos==9044||
pos==9045||pos==9046||pos==9129||pos==9130||pos==9131||pos==9132||
pos==9133||pos==9134||pos==9135||pos==9136||pos==9137||pos==9138||
pos==9139||pos==9140||pos==9141||pos==9142||pos==9143||pos==9144) white=0;
    else white=1;

end

endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NTHU
// Engineer: Peter Su
// 
// Create Date: 2021/12/25 23:18:08
// Design Name: 
// Module Name: music_final
// Project Name: Pickchu 
//////////////////////////////////////////////////////////////////////////////////

module music_final(
    input clk,
    input rst,
    input playing,
    output audio_mclk,
    output audio_lrck, 
    output audio_sck,
    output audio_sdin
    );
    // all the parameters defined first
    wire [15:0] audio_in_left, audio_in_right;
    wire [11:0] ibeatNum;               // Beat counter
    wire [31:0] freqL, freqR ,fin_freqL , fin_freqR;  // Raw frequency, produced by music module
    reg [31:0] r_freqL , r_freqR ;
    wire [21:0] freq_outL, freq_outR;    // Processed frequency, adapted to the clock rate of Basys3
    wire clkDiv22;
    clock_divider #(.n(21)) clock_22(.clk(clk), .clk_div(clkDiv22));
    // handling the freq
    assign freqL =  fin_freqL;
    assign freqR =  fin_freqR;
    // other can be determined later

    assign freq_outL = (50000000 / freqL );
    assign freq_outR = (50000000 / freqR );

    speaker_control sc(
        .clk(clk), 
        .rst(rst), 
        .audio_in_left(audio_in_left),      // left channel audio data input
        .audio_in_right(audio_in_right),    // right channel audio data input
        .audio_mclk(audio_mclk),            // master clock
        .audio_lrck(audio_lrck),            // left-right clock
        .audio_sck(audio_sck),              // serial clock
        .audio_sdin(audio_sdin)             // serial audio data input
    );

    // the note_gen control (modified) 

    note_gen noteGen_00(
        .clk(clk), 
        .rst(rst),
        .volume(2),
        .play(playing),
        .note_div_left(freq_outL), 
        .note_div_right(freq_outR), 
        .audio_left(audio_in_left),     // left sound audio
        .audio_right(audio_in_right)    // right sound audio
    );

    music_example music_00 (
        .ibeatNum(ibeatNum),
        .en(1),
        .toneL(fin_freqL),
        .toneR(fin_freqR)
    );

    player_control #(.LEN(1535)) playerCtrl_00 ( 
        .clk(clkDiv22),
        .reset(!playing),
        .play(1),
        .ibeat(ibeatNum)
    );

endmodule

module clock_divider(clk, clk_div);   
    parameter n = 26;     
    input clk;   
    output clk_div;   
    
    reg [n-1:0] num;
    wire [n-1:0] next_num;
    
    always@(posedge clk)begin
    	num<=next_num;
    end
    
    assign next_num = num +1;
    assign clk_div = num[n-1];
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NTHU
// Engineer: Peter Su
// 
// Create Date: 2021/12/25 23:18:08
// Design Name: 
// Module Name: music_final
// Project Name: Pickchu 
//////////////////////////////////////////////////////////////////////////////////

module music_final(
    input clk,
    input rst,
    input playing,
    output audio_mclk,
    output audio_lrck, 
    output audio_sck,
    output audio_sdin
    );
    // all the parameters defined first
    wire [15:0] audio_in_left, audio_in_right;
    wire [11:0] ibeatNum;               // Beat counter
    wire [31:0] freqL, freqR ,fin_freqL , fin_freqR;  // Raw frequency, produced by music module
    reg [31:0] r_freqL , r_freqR ;
    wire [21:0] freq_outL, freq_outR;    // Processed frequency, adapted to the clock rate of Basys3
    wire clkDiv22;
    clock_divider #(.n(21)) clock_22(.clk(clk), .clk_div(clkDiv22));
    // handling the freq
    assign freqL =  fin_freqL;
    assign freqR =  fin_freqR;
    // other can be determined later

    assign freq_outL = (50000000 / freqL );
    assign freq_outR = (50000000 / freqR );

    speaker_control sc(
        .clk(clk), 
        .rst(rst), 
        .audio_in_left(audio_in_left),      // left channel audio data input
        .audio_in_right(audio_in_right),    // right channel audio data input
        .audio_mclk(audio_mclk),            // master clock
        .audio_lrck(audio_lrck),            // left-right clock
        .audio_sck(audio_sck),              // serial clock
        .audio_sdin(audio_sdin)             // serial audio data input
    );

    // the note_gen control (modified) 

    note_gen noteGen_00(
        .clk(clk), 
        .rst(rst),
        .volume(2),
        .play(playing),
        .note_div_left(freq_outL), 
        .note_div_right(freq_outR), 
        .audio_left(audio_in_left),     // left sound audio
        .audio_right(audio_in_right)    // right sound audio
    );

    music_example music_00 (
        .ibeatNum(ibeatNum),
        .en(1),
        .toneL(fin_freqL),
        .toneR(fin_freqR)
    );

    player_control #(.LEN(1535)) playerCtrl_00 ( 
        .clk(clkDiv22),
        .reset(!playing),
        .play(1),
        .ibeat(ibeatNum)
    );

endmodule

module clock_divider(clk, clk_div);   
    parameter n = 26;     
    input clk;   
    output clk_div;   
    
    reg [n-1:0] num;
    wire [n-1:0] next_num;
    
    always@(posedge clk)begin
    	num<=next_num;
    end
    
    assign next_num = num +1;
    assign clk_div = num[n-1];
    
endmodule

module speaker_control(
    clk,  // clock from the crystal
    rst,  // active high reset
    audio_in_left, // left channel audio data input
    audio_in_right, // right channel audio data input
    audio_mclk, // master clock
    audio_lrck, // left-right clock, Word Select clock, or sample rate clock
    audio_sck, // serial clock
    audio_sdin // serial audio data input
);

    // I/O declaration
    input clk;  // clock from the crystal
    input rst;  // active high reset
    input [15:0] audio_in_left; // left channel audio data input
    input [15:0] audio_in_right; // right channel audio data input
    output audio_mclk; // master clock
    output audio_lrck; // left-right clock
    output audio_sck; // serial clock
    output audio_sdin; // serial audio data input
    reg audio_sdin;

    // Declare internal signal nodes 
    wire [8:0] clk_cnt_next;
    reg [8:0] clk_cnt;
    reg [15:0] audio_left, audio_right;

    // Counter for the clock divider
    assign clk_cnt_next = clk_cnt + 1'b1;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            clk_cnt <= 9'd0;
        else
            clk_cnt <= clk_cnt_next;

    // Assign divided clock output
    assign audio_mclk = clk_cnt[1];
    assign audio_lrck = clk_cnt[8];
    assign audio_sck = 1'b1; // use internal serial clock mode

    // audio input data buffer
    always @(posedge clk_cnt[8] or posedge rst)
        if (rst == 1'b1)
            begin
                audio_left <= 16'd0;
                audio_right <= 16'd0;
            end
        else
            begin
                audio_left <= audio_in_left;
                audio_right <= audio_in_right;
            end

    always @*
        case (clk_cnt[8:4])
            5'b00000: audio_sdin = audio_right[0];
            5'b00001: audio_sdin = audio_left[15];
            5'b00010: audio_sdin = audio_left[14];
            5'b00011: audio_sdin = audio_left[13];
            5'b00100: audio_sdin = audio_left[12];
            5'b00101: audio_sdin = audio_left[11];
            5'b00110: audio_sdin = audio_left[10];
            5'b00111: audio_sdin = audio_left[9];
            5'b01000: audio_sdin = audio_left[8];
            5'b01001: audio_sdin = audio_left[7];
            5'b01010: audio_sdin = audio_left[6];
            5'b01011: audio_sdin = audio_left[5];
            5'b01100: audio_sdin = audio_left[4];
            5'b01101: audio_sdin = audio_left[3];
            5'b01110: audio_sdin = audio_left[2];
            5'b01111: audio_sdin = audio_left[1];
            5'b10000: audio_sdin = audio_left[0];
            5'b10001: audio_sdin = audio_right[15];
            5'b10010: audio_sdin = audio_right[14];
            5'b10011: audio_sdin = audio_right[13];
            5'b10100: audio_sdin = audio_right[12];
            5'b10101: audio_sdin = audio_right[11];
            5'b10110: audio_sdin = audio_right[10];
            5'b10111: audio_sdin = audio_right[9];
            5'b11000: audio_sdin = audio_right[8];
            5'b11001: audio_sdin = audio_right[7];
            5'b11010: audio_sdin = audio_right[6];
            5'b11011: audio_sdin = audio_right[5];
            5'b11100: audio_sdin = audio_right[4];
            5'b11101: audio_sdin = audio_right[3];
            5'b11110: audio_sdin = audio_right[2];
            5'b11111: audio_sdin = audio_right[1];
            default: audio_sdin = 1'b0;
        endcase

endmodule

module note_gen(
    clk, // clock from crystal
    rst, // active high reset
    volume,
    play,
    note_div_left, // div for note generation
    note_div_right,
    audio_left,
    audio_right
);

    // I/O declaration
    input clk; // clock from crystal
    input rst; // active low reset
    input [2:0] volume;
    input play;
    input [21:0] note_div_left, note_div_right; // div for note generation
    output [15:0] audio_left, audio_right;
    // Declare internal signals
    reg [21:0] clk_cnt_next, clk_cnt;
    reg [21:0] clk_cnt_next_2, clk_cnt_2;
    reg b_clk, b_clk_next;
    reg c_clk, c_clk_next;

        // Note frequency generation
    // clk_cnt, clk_cnt_2, b_clk, c_clk
    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            begin
                clk_cnt <= 22'd0;
                clk_cnt_2 <= 22'd0;
                b_clk <= 1'b0;
                c_clk <= 1'b0;
            end
        else
            begin
                clk_cnt <= clk_cnt_next;
                clk_cnt_2 <= clk_cnt_next_2;
                b_clk <= b_clk_next;
                c_clk <= c_clk_next;
            end
    
    // clk_cnt_next, b_clk_next
    always @*
        if (clk_cnt == note_div_left)
            begin
                clk_cnt_next = 22'd0;
                b_clk_next = ~b_clk;
            end
        else
            begin
                clk_cnt_next = clk_cnt + 1'b1;
                b_clk_next = b_clk;
            end

    // clk_cnt_next_2, c_clk_next
    always @*
        if (clk_cnt_2 == note_div_right)
            begin
                clk_cnt_next_2 = 22'd0;
                c_clk_next = ~c_clk;
            end
        else
            begin
                clk_cnt_next_2 = clk_cnt_2 + 1'b1;
                c_clk_next = c_clk;
            end
    // Assign the amplitude of the note
    // Volume is controlled here
    reg [15:0] vol;
    always @(*) begin
        if(!play) vol = 0;
        else vol = 14'd1024*volume;
    end

    assign audio_left = (note_div_left == 22'd1) ? 16'h0000 : (b_clk == 1'b0) ? vol : -vol;
    assign audio_right = (note_div_right == 22'd1) ? 16'h0000 : (c_clk == 1'b0) ? vol : -vol;
endmodule

`define lllc  32'd32  // C1
`define llc  32'd65  // C2
`define llf  32'd87   // F2
`define llg  32'd98   // G2
`define lla  32'd110   // A2
`define llb  32'd123   // B2
`define lc  32'd131   // C3
`define ld  32'd147   // C3
`define le  32'd165   // C3
`define lf  32'd174   // F3
`define lg  32'd196  // G3
`define la  32'd220   // C3
`define lsa   32'd233   // #A3
`define lb  32'd247   // C3
`define c   32'd262   // C4
`define d   32'd294   // D4
`define e   32'd330   // E4
`define f   32'd349   // F4
`define sf   32'd370   // #F4
`define g   32'd392   // G4
`define a   32'd440   // A4
`define sa   32'd466   // #A4
`define b   32'd494   // B4
`define hc   32'd524   // C4
`define hd   32'd588   // D4
`define he   32'd660   // E4
`define hf   32'd698   // F4
`define hg   32'd784   // G4
`define ha   32'd880   // A4
`define hb   32'd988   // B4


`define sil   32'd50000000 // slience

module music_example (
	input [11:0] ibeatNum,
    input en,
	output reg [31:0] toneL,
    output reg [31:0] toneR
);

always @(*) begin
    if(en) begin
        case(ibeatNum)
                12'd0: toneR = `g;
                12'd1: toneR = `g;
                12'd2: toneR = `g;
                12'd3: toneR = `g;
                12'd4: toneR = `sf;
                12'd5: toneR = `sf;
                12'd6: toneR = `sf;
                12'd7: toneR = `sf;
                12'd8: toneR = `g;
                12'd9: toneR = `g;
                12'd10: toneR = `g;
                12'd11: toneR = `g;
                12'd12: toneR = `a;
                12'd13: toneR = `a;
                12'd14: toneR = `a;
                12'd15: toneR = `a;
                12'd16: toneR = `g;
                12'd17: toneR = `g;
                12'd18: toneR = `g;
                12'd19: toneR = `g;
                12'd20: toneR = `g;
                12'd21: toneR = `g;
                12'd22: toneR = `g;
                12'd23: toneR = `g;
                12'd24: toneR = `g;
                12'd25: toneR = `g;
                12'd26: toneR = `g;
                12'd27: toneR = `g;
                12'd28: toneR = `sil;
                12'd29: toneR = `sil;
                12'd30: toneR = `sil;
                12'd31: toneR = `sil;
                12'd32: toneR = `g;
                12'd33: toneR = `g;
                12'd34: toneR = `g;
                12'd35: toneR = `g;
                12'd36: toneR = `sf;
                12'd37: toneR = `sf;
                12'd38: toneR = `sf;
                12'd39: toneR = `sf;
                12'd40: toneR = `g;
                12'd41: toneR = `g;
                12'd42: toneR = `g;
                12'd43: toneR = `g;
                12'd44: toneR = `a;
                12'd45: toneR = `a;
                12'd46: toneR = `a;
                12'd47: toneR = `a;
                12'd48: toneR = `g;
                12'd49: toneR = `g;
                12'd50: toneR = `g;
                12'd51: toneR = `g;
                12'd52: toneR = `g;
                12'd53: toneR = `g;
                12'd54: toneR = `g;
                12'd55: toneR = `g;
                12'd56: toneR = `g;
                12'd57: toneR = `g;
                12'd58: toneR = `g;
                12'd59: toneR = `g;
                12'd60: toneR = `sil;
                12'd61: toneR = `sil;
                12'd62: toneR = `sil;
                12'd63: toneR = `sil;
                12'd64: toneR = `g;
                12'd65: toneR = `g;
                12'd66: toneR = `g;
                12'd67: toneR = `sil;
                12'd68: toneR = `g;
                12'd69: toneR = `g;
                12'd70: toneR = `g;
                12'd71: toneR = `sil;
                12'd72: toneR = `g;
                12'd73: toneR = `g;
                12'd74: toneR = `g;
                12'd75: toneR = `g;
                12'd76: toneR = `g;
                12'd77: toneR = `g;
                12'd78: toneR = `g;
                12'd79: toneR = `g;
                12'd80: toneR = `a;
                12'd81: toneR = `a;
                12'd82: toneR = `a;
                12'd83: toneR = `a;
                12'd84: toneR = `a;
                12'd85: toneR = `a;
                12'd86: toneR = `a;
                12'd87: toneR = `a;
                12'd88: toneR = `sa;
                12'd89: toneR = `sa;
                12'd90: toneR = `sa;
                12'd91: toneR = `sa;
                12'd92: toneR = `sa;
                12'd93: toneR = `sa;
                12'd94: toneR = `sa;
                12'd95: toneR = `sa;
                12'd96: toneR = `b;
                12'd97: toneR = `b;
                12'd98: toneR = `b;
                12'd99: toneR = `b;
                12'd100: toneR = `b;
                12'd101: toneR = `b;
                12'd102: toneR = `b;
                12'd103: toneR = `b;
                12'd104: toneR = `g;
                12'd105: toneR = `g;
                12'd106: toneR = `g;
                12'd107: toneR = `g;
                12'd108: toneR = `g;
                12'd109: toneR = `g;
                12'd110: toneR = `g;
                12'd111: toneR = `g;
                12'd112: toneR = `a;
                12'd113: toneR = `a;
                12'd114: toneR = `a;
                12'd115: toneR = `a;
                12'd116: toneR = `a;
                12'd117: toneR = `a;
                12'd118: toneR = `a;
                12'd119: toneR = `a;
                12'd120: toneR = `b;
                12'd121: toneR = `b;
                12'd122: toneR = `b;
                12'd123: toneR = `b;
                12'd124: toneR = `b;
                12'd125: toneR = `b;
                12'd126: toneR = `b;
                12'd127: toneR = `b;
                12'd128: toneR = `hc;
                12'd129: toneR = `hc;
                12'd130: toneR = `hc;
                12'd131: toneR = `hc;
                12'd132: toneR = `hc;
                12'd133: toneR = `hc;
                12'd134: toneR = `hc;
                12'd135: toneR = `hc;
                12'd136: toneR = `b;
                12'd137: toneR = `b;
                12'd138: toneR = `b;
                12'd139: toneR = `b;
                12'd140: toneR = `b;
                12'd141: toneR = `b;
                12'd142: toneR = `b;
                12'd143: toneR = `b;
                12'd144: toneR = `hc;
                12'd145: toneR = `hc;
                12'd146: toneR = `hc;
                12'd147: toneR = `hc;
                12'd148: toneR = `hc;
                12'd149: toneR = `hc;
                12'd150: toneR = `hc;
                12'd151: toneR = `hc;
                12'd152: toneR = `b;
                12'd153: toneR = `b;
                12'd154: toneR = `b;
                12'd155: toneR = `b;
                12'd156: toneR = `hc;
                12'd157: toneR = `hc;
                12'd158: toneR = `hc;
                12'd159: toneR = `hc;
                12'd160: toneR = `sil;
                12'd161: toneR = `sil;
                12'd162: toneR = `sil;
                12'd163: toneR = `sil;
                12'd164: toneR = `sil;
                12'd165: toneR = `sil;
                12'd166: toneR = `sil;
                12'd167: toneR = `sil;
                12'd168: toneR = `b;
                12'd169: toneR = `b;
                12'd170: toneR = `b;
                12'd171: toneR = `b;
                12'd172: toneR = `b;
                12'd173: toneR = `b;
                12'd174: toneR = `b;
                12'd175: toneR = `b;
                12'd176: toneR = `hc;
                12'd177: toneR = `hc;
                12'd178: toneR = `hc;
                12'd179: toneR = `hc;
                12'd180: toneR = `hc;
                12'd181: toneR = `hc;
                12'd182: toneR = `hc;
                12'd183: toneR = `hc;
                12'd184: toneR = `b;
                12'd185: toneR = `b;
                12'd186: toneR = `b;
                12'd187: toneR = `b;
                12'd188: toneR = `b;
                12'd189: toneR = `b;
                12'd190: toneR = `b;
                12'd191: toneR = `b;
                12'd192: toneR = `a;
                12'd193: toneR = `a;
                12'd194: toneR = `a;
                12'd195: toneR = `a;
                12'd196: toneR = `a;
                12'd197: toneR = `a;
                12'd198: toneR = `a;
                12'd199: toneR = `a;
                12'd200: toneR = `g;
                12'd201: toneR = `g;
                12'd202: toneR = `g;
                12'd203: toneR = `g;
                12'd204: toneR = `g;
                12'd205: toneR = `g;
                12'd206: toneR = `g;
                12'd207: toneR = `g;
                12'd208: toneR = `a;
                12'd209: toneR = `a;
                12'd210: toneR = `a;
                12'd211: toneR = `a;
                12'd212: toneR = `a;
                12'd213: toneR = `a;
                12'd214: toneR = `a;
                12'd215: toneR = `a;
                12'd216: toneR = `g;
                12'd217: toneR = `g;
                12'd218: toneR = `g;
                12'd219: toneR = `g;
                12'd220: toneR = `a;
                12'd221: toneR = `a;
                12'd222: toneR = `a;
                12'd223: toneR = `a;
                12'd224: toneR = `sil;
                12'd225: toneR = `sil;
                12'd226: toneR = `sil;
                12'd227: toneR = `sil;
                12'd228: toneR = `sil;
                12'd229: toneR = `sil;
                12'd230: toneR = `sil;
                12'd231: toneR = `sil;
                12'd232: toneR = `g;
                12'd233: toneR = `g;
                12'd234: toneR = `g;
                12'd235: toneR = `g;
                12'd236: toneR = `g;
                12'd237: toneR = `g;
                12'd238: toneR = `g;
                12'd239: toneR = `g;
                12'd240: toneR = `a;
                12'd241: toneR = `a;
                12'd242: toneR = `a;
                12'd243: toneR = `a;
                12'd244: toneR = `a;
                12'd245: toneR = `a;
                12'd246: toneR = `a;
                12'd247: toneR = `a;
                12'd248: toneR = `b;
                12'd249: toneR = `b;
                12'd250: toneR = `b;
                12'd251: toneR = `b;
                12'd252: toneR = `b;
                12'd253: toneR = `b;
                12'd254: toneR = `b;
                12'd255: toneR = `b;
                12'd256: toneR = `hc;
                12'd257: toneR = `hc;
                12'd258: toneR = `hc;
                12'd259: toneR = `hc;
                12'd260: toneR = `hc;
                12'd261: toneR = `hc;
                12'd262: toneR = `hc;
                12'd263: toneR = `hc;
                12'd264: toneR = `b;
                12'd265: toneR = `b;
                12'd266: toneR = `b;
                12'd267: toneR = `b;
                12'd268: toneR = `b;
                12'd269: toneR = `b;
                12'd270: toneR = `b;
                12'd271: toneR = `b;
                12'd272: toneR = `hc;
                12'd273: toneR = `hc;
                12'd274: toneR = `hc;
                12'd275: toneR = `hc;
                12'd276: toneR = `hc;
                12'd277: toneR = `hc;
                12'd278: toneR = `hc;
                12'd279: toneR = `hc;
                12'd280: toneR = `b;
                12'd281: toneR = `b;
                12'd282: toneR = `b;
                12'd283: toneR = `b;
                12'd284: toneR = `hc;
                12'd285: toneR = `hc;
                12'd286: toneR = `hc;
                12'd287: toneR = `hc;
                12'd288: toneR = `sil;
                12'd289: toneR = `sil;
                12'd290: toneR = `sil;
                12'd291: toneR = `sil;
                12'd292: toneR = `sil;
                12'd293: toneR = `sil;
                12'd294: toneR = `sil;
                12'd295: toneR = `sil;
                12'd296: toneR = `b;
                12'd297: toneR = `b;
                12'd298: toneR = `b;
                12'd299: toneR = `b;
                12'd300: toneR = `b;
                12'd301: toneR = `b;
                12'd302: toneR = `b;
                12'd303: toneR = `b;
                12'd304: toneR = `hc;
                12'd305: toneR = `hc;
                12'd306: toneR = `hc;
                12'd307: toneR = `hc;
                12'd308: toneR = `hc;
                12'd309: toneR = `hc;
                12'd310: toneR = `hc;
                12'd311: toneR = `hc;
                12'd312: toneR = `b;
                12'd313: toneR = `b;
                12'd314: toneR = `b;
                12'd315: toneR = `b;
                12'd316: toneR = `b;
                12'd317: toneR = `b;
                12'd318: toneR = `b;
                12'd319: toneR = `b;
                12'd320: toneR = `a;
                12'd321: toneR = `a;
                12'd322: toneR = `a;
                12'd323: toneR = `a;
                12'd324: toneR = `a;
                12'd325: toneR = `a;
                12'd326: toneR = `a;
                12'd327: toneR = `a;
                12'd328: toneR = `g;
                12'd329: toneR = `g;
                12'd330: toneR = `g;
                12'd331: toneR = `g;
                12'd332: toneR = `g;
                12'd333: toneR = `g;
                12'd334: toneR = `g;
                12'd335: toneR = `g;
                12'd336: toneR = `a;
                12'd337: toneR = `a;
                12'd338: toneR = `a;
                12'd339: toneR = `a;
                12'd340: toneR = `a;
                12'd341: toneR = `a;
                12'd342: toneR = `a;
                12'd343: toneR = `a;
                12'd344: toneR = `g;
                12'd345: toneR = `g;
                12'd346: toneR = `g;
                12'd347: toneR = `g;
                12'd348: toneR = `a;
                12'd349: toneR = `a;
                12'd350: toneR = `a;
                12'd351: toneR = `a;
                12'd352: toneR = `sil;
                12'd353: toneR = `sil;
                12'd354: toneR = `sil;
                12'd355: toneR = `sil;
                12'd356: toneR = `sil;
                12'd357: toneR = `sil;
                12'd358: toneR = `sil;
                12'd359: toneR = `sil;
                12'd360: toneR = `g;
                12'd361: toneR = `g;
                12'd362: toneR = `g;
                12'd363: toneR = `g;
                12'd364: toneR = `g;
                12'd365: toneR = `g;
                12'd366: toneR = `g;
                12'd367: toneR = `g;
                12'd368: toneR = `a;
                12'd369: toneR = `a;
                12'd370: toneR = `a;
                12'd371: toneR = `a;
                12'd372: toneR = `a;
                12'd373: toneR = `a;
                12'd374: toneR = `a;
                12'd375: toneR = `a;
                12'd376: toneR = `b;
                12'd377: toneR = `b;
                12'd378: toneR = `b;
                12'd379: toneR = `b;
                12'd380: toneR = `b;
                12'd381: toneR = `b;
                12'd382: toneR = `b;
                12'd383: toneR = `b;
                12'd384: toneR = `hc;
                12'd385: toneR = `hc;
                12'd386: toneR = `hc;
                12'd387: toneR = `hc;
                12'd388: toneR = `hc;
                12'd389: toneR = `hc;
                12'd390: toneR = `hc;
                12'd391: toneR = `hc;
                12'd392: toneR = `b;
                12'd393: toneR = `b;
                12'd394: toneR = `b;
                12'd395: toneR = `b;
                12'd396: toneR = `b;
                12'd397: toneR = `b;
                12'd398: toneR = `b;
                12'd399: toneR = `b;
                12'd400: toneR = `hc;
                12'd401: toneR = `hc;
                12'd402: toneR = `hc;
                12'd403: toneR = `hc;
                12'd404: toneR = `hc;
                12'd405: toneR = `hc;
                12'd406: toneR = `hc;
                12'd407: toneR = `hc;
                12'd408: toneR = `b;
                12'd409: toneR = `b;
                12'd410: toneR = `b;
                12'd411: toneR = `b;
                12'd412: toneR = `hc;
                12'd413: toneR = `hc;
                12'd414: toneR = `hc;
                12'd415: toneR = `hc;
                12'd416: toneR = `sil;
                12'd417: toneR = `sil;
                12'd418: toneR = `sil;
                12'd419: toneR = `sil;
                12'd420: toneR = `sil;
                12'd421: toneR = `sil;
                12'd422: toneR = `sil;
                12'd423: toneR = `sil;
                12'd424: toneR = `b;
                12'd425: toneR = `b;
                12'd426: toneR = `b;
                12'd427: toneR = `b;
                12'd428: toneR = `b;
                12'd429: toneR = `b;
                12'd430: toneR = `b;
                12'd431: toneR = `b;
                12'd432: toneR = `hc;
                12'd433: toneR = `hc;
                12'd434: toneR = `hc;
                12'd435: toneR = `hc;
                12'd436: toneR = `hc;
                12'd437: toneR = `hc;
                12'd438: toneR = `hc;
                12'd439: toneR = `hc;
                12'd440: toneR = `b;
                12'd441: toneR = `b;
                12'd442: toneR = `b;
                12'd443: toneR = `b;
                12'd444: toneR = `b;
                12'd445: toneR = `b;
                12'd446: toneR = `b;
                12'd447: toneR = `b;
                12'd448: toneR = `a;
                12'd449: toneR = `a;
                12'd450: toneR = `a;
                12'd451: toneR = `a;
                12'd452: toneR = `a;
                12'd453: toneR = `a;
                12'd454: toneR = `a;
                12'd455: toneR = `a;
                12'd456: toneR = `g;
                12'd457: toneR = `g;
                12'd458: toneR = `g;
                12'd459: toneR = `g;
                12'd460: toneR = `g;
                12'd461: toneR = `g;
                12'd462: toneR = `g;
                12'd463: toneR = `g;
                12'd464: toneR = `a;
                12'd465: toneR = `a;
                12'd466: toneR = `a;
                12'd467: toneR = `a;
                12'd468: toneR = `a;
                12'd469: toneR = `a;
                12'd470: toneR = `a;
                12'd471: toneR = `a;
                12'd472: toneR = `g;
                12'd473: toneR = `g;
                12'd474: toneR = `g;
                12'd475: toneR = `g;
                12'd476: toneR = `a;
                12'd477: toneR = `a;
                12'd478: toneR = `a;
                12'd479: toneR = `a;
                12'd480: toneR = `sil;
                12'd481: toneR = `sil;
                12'd482: toneR = `sil;
                12'd483: toneR = `sil;
                12'd484: toneR = `sil;
                12'd485: toneR = `sil;
                12'd486: toneR = `sil;
                12'd487: toneR = `sil;
                12'd488: toneR = `g;
                12'd489: toneR = `g;
                12'd490: toneR = `g;
                12'd491: toneR = `g;
                12'd492: toneR = `g;
                12'd493: toneR = `g;
                12'd494: toneR = `g;
                12'd495: toneR = `g;
                12'd496: toneR = `a;
                12'd497: toneR = `a;
                12'd498: toneR = `a;
                12'd499: toneR = `a;
                12'd500: toneR = `a;
                12'd501: toneR = `a;
                12'd502: toneR = `a;
                12'd503: toneR = `a;
                12'd504: toneR = `b;
                12'd505: toneR = `b;
                12'd506: toneR = `b;
                12'd507: toneR = `b;
                12'd508: toneR = `b;
                12'd509: toneR = `b;
                12'd510: toneR = `b;
                12'd511: toneR = `b;
                12'd512: toneR = `e;
                12'd513: toneR = `e;
                12'd514: toneR = `e;
                12'd515: toneR = `e;
                12'd516: toneR = `e;
                12'd517: toneR = `e;
                12'd518: toneR = `e;
                12'd519: toneR = `sil;
                12'd520: toneR = `e;
                12'd521: toneR = `e;
                12'd522: toneR = `e;
                12'd523: toneR = `e;
                12'd524: toneR = `e;
                12'd525: toneR = `e;
                12'd526: toneR = `e;
                12'd527: toneR = `e;
                12'd528: toneR = `f;
                12'd529: toneR = `f;
                12'd530: toneR = `f;
                12'd531: toneR = `f;
                12'd532: toneR = `f;
                12'd533: toneR = `f;
                12'd534: toneR = `f;
                12'd535: toneR = `f;
                12'd536: toneR = `g;
                12'd537: toneR = `g;
                12'd538: toneR = `g;
                12'd539: toneR = `g;
                12'd540: toneR = `g;
                12'd541: toneR = `g;
                12'd542: toneR = `g;
                12'd543: toneR = `g;
                12'd544: toneR = `c;
                12'd545: toneR = `c;
                12'd546: toneR = `c;
                12'd547: toneR = `c;
                12'd548: toneR = `c;
                12'd549: toneR = `c;
                12'd550: toneR = `c;
                12'd551: toneR = `c;
                12'd552: toneR = `hc;
                12'd553: toneR = `hc;
                12'd554: toneR = `hc;
                12'd555: toneR = `hc;
                12'd556: toneR = `hc;
                12'd557: toneR = `hc;
                12'd558: toneR = `hc;
                12'd559: toneR = `hc;
                12'd560: toneR = `b;
                12'd561: toneR = `b;
                12'd562: toneR = `b;
                12'd563: toneR = `b;
                12'd564: toneR = `b;
                12'd565: toneR = `b;
                12'd566: toneR = `b;
                12'd567: toneR = `b;
                12'd568: toneR = `a;
                12'd569: toneR = `a;
                12'd570: toneR = `a;
                12'd571: toneR = `a;
                12'd572: toneR = `a;
                12'd573: toneR = `a;
                12'd574: toneR = `a;
                12'd575: toneR = `a;
                12'd576: toneR = `g;
                12'd577: toneR = `g;
                12'd578: toneR = `g;
                12'd579: toneR = `g;
                12'd580: toneR = `g;
                12'd581: toneR = `g;
                12'd582: toneR = `g;
                12'd583: toneR = `g;
                12'd584: toneR = `g;
                12'd585: toneR = `g;
                12'd586: toneR = `g;
                12'd587: toneR = `g;
                12'd588: toneR = `g;
                12'd589: toneR = `g;
                12'd590: toneR = `g;
                12'd591: toneR = `g;
                12'd592: toneR = `f;
                12'd593: toneR = `f;
                12'd594: toneR = `f;
                12'd595: toneR = `f;
                12'd596: toneR = `f;
                12'd597: toneR = `f;
                12'd598: toneR = `f;
                12'd599: toneR = `f;
                12'd600: toneR = `f;
                12'd601: toneR = `f;
                12'd602: toneR = `f;
                12'd603: toneR = `f;
                12'd604: toneR = `f;
                12'd605: toneR = `f;
                12'd606: toneR = `f;
                12'd607: toneR = `f;
                12'd608: toneR = `sil;
                12'd609: toneR = `sil;
                12'd610: toneR = `sil;
                12'd611: toneR = `sil;
                12'd612: toneR = `sil;
                12'd613: toneR = `sil;
                12'd614: toneR = `sil;
                12'd615: toneR = `sil;
                12'd616: toneR = `sil;
                12'd617: toneR = `sil;
                12'd618: toneR = `sil;
                12'd619: toneR = `sil;
                12'd620: toneR = `sil;
                12'd621: toneR = `sil;
                12'd622: toneR = `sil;
                12'd623: toneR = `sil;
                12'd624: toneR = `d;
                12'd625: toneR = `d;
                12'd626: toneR = `d;
                12'd627: toneR = `d;
                12'd628: toneR = `d;
                12'd629: toneR = `d;
                12'd630: toneR = `d;
                12'd631: toneR = `sil;
                12'd632: toneR = `d;
                12'd633: toneR = `d;
                12'd634: toneR = `d;
                12'd635: toneR = `d;
                12'd636: toneR = `d;
                12'd637: toneR = `d;
                12'd638: toneR = `d;
                12'd639: toneR = `d;
                12'd640: toneR = `e;
                12'd641: toneR = `e;
                12'd642: toneR = `e;
                12'd643: toneR = `e;
                12'd644: toneR = `e;
                12'd645: toneR = `e;
                12'd646: toneR = `e;
                12'd647: toneR = `e;
                12'd648: toneR = `f;
                12'd649: toneR = `f;
                12'd650: toneR = `f;
                12'd651: toneR = `f;
                12'd652: toneR = `f;
                12'd653: toneR = `f;
                12'd654: toneR = `f;
                12'd655: toneR = `f;
                12'd656: toneR = `lb;
                12'd657: toneR = `lb;
                12'd658: toneR = `lb;
                12'd659: toneR = `lb;
                12'd660: toneR = `lb;
                12'd661: toneR = `lb;
                12'd662: toneR = `lb;
                12'd663: toneR = `lb;
                12'd664: toneR = `b;
                12'd665: toneR = `b;
                12'd666: toneR = `b;
                12'd667: toneR = `b;
                12'd668: toneR = `b;
                12'd669: toneR = `b;
                12'd670: toneR = `b;
                12'd671: toneR = `b;
                12'd672: toneR = `a;
                12'd673: toneR = `a;
                12'd674: toneR = `a;
                12'd675: toneR = `a;
                12'd676: toneR = `a;
                12'd677: toneR = `a;
                12'd678: toneR = `a;
                12'd679: toneR = `a;
                12'd680: toneR = `g;
                12'd681: toneR = `g;
                12'd682: toneR = `g;
                12'd683: toneR = `g;
                12'd684: toneR = `g;
                12'd685: toneR = `g;
                12'd686: toneR = `g;
                12'd687: toneR = `g;
                12'd688: toneR = `a;
                12'd689: toneR = `a;
                12'd690: toneR = `a;
                12'd691: toneR = `a;
                12'd692: toneR = `a;
                12'd693: toneR = `a;
                12'd694: toneR = `a;
                12'd695: toneR = `a;
                12'd696: toneR = `a;
                12'd697: toneR = `a;
                12'd698: toneR = `a;
                12'd699: toneR = `a;
                12'd700: toneR = `a;
                12'd701: toneR = `a;
                12'd702: toneR = `a;
                12'd703: toneR = `a;
                12'd704: toneR = `g;
                12'd705: toneR = `g;
                12'd706: toneR = `g;
                12'd707: toneR = `g;
                12'd708: toneR = `g;
                12'd709: toneR = `g;
                12'd710: toneR = `g;
                12'd711: toneR = `g;
                12'd712: toneR = `g;
                12'd713: toneR = `g;
                12'd714: toneR = `g;
                12'd715: toneR = `g;
                12'd716: toneR = `g;
                12'd717: toneR = `g;
                12'd718: toneR = `g;
                12'd719: toneR = `g;
                12'd720: toneR = `sil;
                12'd721: toneR = `sil;
                12'd722: toneR = `sil;
                12'd723: toneR = `sil;
                12'd724: toneR = `sil;
                12'd725: toneR = `sil;
                12'd726: toneR = `sil;
                12'd727: toneR = `sil;
                12'd728: toneR = `sil;
                12'd729: toneR = `sil;
                12'd730: toneR = `sil;
                12'd731: toneR = `sil;
                12'd732: toneR = `sil;
                12'd733: toneR = `sil;
                12'd734: toneR = `sil;
                12'd735: toneR = `sil;
                12'd736: toneR = `e;
                12'd737: toneR = `e;
                12'd738: toneR = `e;
                12'd739: toneR = `e;
                12'd740: toneR = `e;
                12'd741: toneR = `e;
                12'd742: toneR = `e;
                12'd743: toneR = `sil;
                12'd744: toneR = `e;
                12'd745: toneR = `e;
                12'd746: toneR = `e;
                12'd747: toneR = `e;
                12'd748: toneR = `e;
                12'd749: toneR = `e;
                12'd750: toneR = `e;
                12'd751: toneR = `e;
                12'd752: toneR = `f;
                12'd753: toneR = `f;
                12'd754: toneR = `f;
                12'd755: toneR = `f;
                12'd756: toneR = `f;
                12'd757: toneR = `f;
                12'd758: toneR = `f;
                12'd759: toneR = `f;
                12'd760: toneR = `g;
                12'd761: toneR = `g;
                12'd762: toneR = `g;
                12'd763: toneR = `g;
                12'd764: toneR = `g;
                12'd765: toneR = `g;
                12'd766: toneR = `g;
                12'd767: toneR = `g;
                12'd768: toneR = `c;
                12'd769: toneR = `c;
                12'd770: toneR = `c;
                12'd771: toneR = `c;
                12'd772: toneR = `c;
                12'd773: toneR = `c;
                12'd774: toneR = `c;
                12'd775: toneR = `c;
                12'd776: toneR = `hc;
                12'd777: toneR = `hc;
                12'd778: toneR = `hc;
                12'd779: toneR = `hc;
                12'd780: toneR = `hc;
                12'd781: toneR = `hc;
                12'd782: toneR = `hc;
                12'd783: toneR = `hc;
                12'd784: toneR = `b;
                12'd785: toneR = `b;
                12'd786: toneR = `b;
                12'd787: toneR = `b;
                12'd788: toneR = `b;
                12'd789: toneR = `b;
                12'd790: toneR = `b;
                12'd791: toneR = `b;
                12'd792: toneR = `a;
                12'd793: toneR = `a;
                12'd794: toneR = `a;
                12'd795: toneR = `a;
                12'd796: toneR = `a;
                12'd797: toneR = `a;
                12'd798: toneR = `a;
                12'd799: toneR = `a;
                12'd800: toneR = `g;
                12'd801: toneR = `g;
                12'd802: toneR = `g;
                12'd803: toneR = `g;
                12'd804: toneR = `g;
                12'd805: toneR = `g;
                12'd806: toneR = `g;
                12'd807: toneR = `g;
                12'd808: toneR = `g;
                12'd809: toneR = `g;
                12'd810: toneR = `g;
                12'd811: toneR = `g;
                12'd812: toneR = `g;
                12'd813: toneR = `g;
                12'd814: toneR = `g;
                12'd815: toneR = `g;
                12'd816: toneR = `f;
                12'd817: toneR = `f;
                12'd818: toneR = `f;
                12'd819: toneR = `f;
                12'd820: toneR = `f;
                12'd821: toneR = `f;
                12'd822: toneR = `f;
                12'd823: toneR = `f;
                12'd824: toneR = `f;
                12'd825: toneR = `f;
                12'd826: toneR = `f;
                12'd827: toneR = `f;
                12'd828: toneR = `f;
                12'd829: toneR = `f;
                12'd830: toneR = `f;
                12'd831: toneR = `sil;
                12'd832: toneR = `f;
                12'd833: toneR = `f;
                12'd834: toneR = `f;
                12'd835: toneR = `f;
                12'd836: toneR = `f;
                12'd837: toneR = `f;
                12'd838: toneR = `f;
                12'd839: toneR = `f;
                12'd840: toneR = `g;
                12'd841: toneR = `g;
                12'd842: toneR = `g;
                12'd843: toneR = `g;
                12'd844: toneR = `g;
                12'd845: toneR = `g;
                12'd846: toneR = `g;
                12'd847: toneR = `g;
                12'd848: toneR = `a;
                12'd849: toneR = `a;
                12'd850: toneR = `a;
                12'd851: toneR = `a;
                12'd852: toneR = `a;
                12'd853: toneR = `a;
                12'd854: toneR = `a;
                12'd855: toneR = `a;
                12'd856: toneR = `b;
                12'd857: toneR = `b;
                12'd858: toneR = `b;
                12'd859: toneR = `b;
                12'd860: toneR = `b;
                12'd861: toneR = `b;
                12'd862: toneR = `b;
                12'd863: toneR = `b;
                12'd864: toneR = `sil;
                12'd865: toneR = `sil;
                12'd866: toneR = `sil;
                12'd867: toneR = `sil;
                12'd868: toneR = `sil;
                12'd869: toneR = `sil;
                12'd870: toneR = `sil;
                12'd871: toneR = `sil;
                12'd872: toneR = `g;
                12'd873: toneR = `g;
                12'd874: toneR = `g;
                12'd875: toneR = `g;
                12'd876: toneR = `g;
                12'd877: toneR = `g;
                12'd878: toneR = `g;
                12'd879: toneR = `g;
                12'd880: toneR = `g;
                12'd881: toneR = `g;
                12'd882: toneR = `g;
                12'd883: toneR = `g;
                12'd884: toneR = `g;
                12'd885: toneR = `g;
                12'd886: toneR = `g;
                12'd887: toneR = `g;
                12'd888: toneR = `a;
                12'd889: toneR = `a;
                12'd890: toneR = `a;
                12'd891: toneR = `a;
                12'd892: toneR = `a;
                12'd893: toneR = `a;
                12'd894: toneR = `a;
                12'd895: toneR = `a;
                12'd896: toneR = `a;
                12'd897: toneR = `a;
                12'd898: toneR = `a;
                12'd899: toneR = `a;
                12'd900: toneR = `a;
                12'd901: toneR = `a;
                12'd902: toneR = `a;
                12'd903: toneR = `a;
                12'd904: toneR = `b;
                12'd905: toneR = `b;
                12'd906: toneR = `b;
                12'd907: toneR = `b;
                12'd908: toneR = `b;
                12'd909: toneR = `b;
                12'd910: toneR = `b;
                12'd911: toneR = `b;
                12'd912: toneR = `b;
                12'd913: toneR = `b;
                12'd914: toneR = `b;
                12'd915: toneR = `b;
                12'd916: toneR = `b;
                12'd917: toneR = `b;
                12'd918: toneR = `b;
                12'd919: toneR = `b;
                12'd920: toneR = `hc;
                12'd921: toneR = `hc;
                12'd922: toneR = `hc;
                12'd923: toneR = `hc;
                12'd924: toneR = `hc;
                12'd925: toneR = `hc;
                12'd926: toneR = `hc;
                12'd927: toneR = `hc;
                12'd928: toneR = `hc;
                12'd929: toneR = `hc;
                12'd930: toneR = `hc;
                12'd931: toneR = `hc;
                12'd932: toneR = `hc;
                12'd933: toneR = `hc;
                12'd934: toneR = `hc;
                12'd935: toneR = `hc;
                12'd936: toneR = `hc;
                12'd937: toneR = `hc;
                12'd938: toneR = `hc;
                12'd939: toneR = `hc;
                12'd940: toneR = `hc;
                12'd941: toneR = `hc;
                12'd942: toneR = `hc;
                12'd943: toneR = `hc;
                12'd944: toneR = `hc;
                12'd945: toneR = `hc;
                12'd946: toneR = `hc;
                12'd947: toneR = `hc;
                12'd948: toneR = `hc;
                12'd949: toneR = `hc;
                12'd950: toneR = `hc;
                12'd951: toneR = `hc;
                12'd952: toneR = `hc;
                12'd953: toneR = `hc;
                12'd954: toneR = `hc;
                12'd955: toneR = `hc;
                12'd956: toneR = `hc;
                12'd957: toneR = `hc;
                12'd958: toneR = `hc;
                12'd959: toneR = `hc;
                12'd960: toneR = `sil;
                12'd961: toneR = `sil;
                12'd962: toneR = `sil;
                12'd963: toneR = `sil;
                12'd964: toneR = `sil;
                12'd965: toneR = `sil;
                12'd966: toneR = `sil;
                12'd967: toneR = `sil;
                12'd968: toneR = `sil;
                12'd969: toneR = `sil;
                12'd970: toneR = `sil;
                12'd971: toneR = `sil;
                12'd972: toneR = `sil;
                12'd973: toneR = `sil;
                12'd974: toneR = `sil;
                12'd975: toneR = `sil;
                12'd976: toneR = `sil;
                12'd977: toneR = `sil;
                12'd978: toneR = `sil;
                12'd979: toneR = `sil;
                12'd980: toneR = `sil;
                12'd981: toneR = `sil;
                12'd982: toneR = `sil;
                12'd983: toneR = `sil;
                12'd984: toneR = `hc;
                12'd985: toneR = `hc;
                12'd986: toneR = `hc;
                12'd987: toneR = `hc;
                12'd988: toneR = `hc;
                12'd989: toneR = `hc;
                12'd990: toneR = `hc;
                12'd991: toneR = `hc;
                12'd992: toneR = `b;
                12'd993: toneR = `b;
                12'd994: toneR = `b;
                12'd995: toneR = `b;
                12'd996: toneR = `b;
                12'd997: toneR = `b;
                12'd998: toneR = `b;
                12'd999: toneR = `b;
                12'd1000: toneR = `sa;
                12'd1001: toneR = `sa;
                12'd1002: toneR = `sa;
                12'd1003: toneR = `sa;
                12'd1004: toneR = `sa;
                12'd1005: toneR = `sa;
                12'd1006: toneR = `sa;
                12'd1007: toneR = `sa;
                12'd1008: toneR = `a;
                12'd1009: toneR = `a;
                12'd1010: toneR = `a;
                12'd1011: toneR = `a;
                12'd1012: toneR = `a;
                12'd1013: toneR = `a;
                12'd1014: toneR = `a;
                12'd1015: toneR = `a;
                12'd1016: toneR = `a;
                12'd1017: toneR = `a;
                12'd1018: toneR = `a;
                12'd1019: toneR = `a;
                12'd1020: toneR = `a;
                12'd1021: toneR = `a;
                12'd1022: toneR = `a;
                12'd1023: toneR = `a;
                12'd1024: toneR = `hc;
                12'd1025: toneR = `hc;
                12'd1026: toneR = `hc;
                12'd1027: toneR = `hc;
                12'd1028: toneR = `hc;
                12'd1029: toneR = `hc;
                12'd1030: toneR = `hc;
                12'd1031: toneR = `hc;
                12'd1032: toneR = `hc;
                12'd1033: toneR = `hc;
                12'd1034: toneR = `hc;
                12'd1035: toneR = `hc;
                12'd1036: toneR = `hc;
                12'd1037: toneR = `hc;
                12'd1038: toneR = `hc;
                12'd1039: toneR = `hc;
                12'd1040: toneR = `hd;
                12'd1041: toneR = `hd;
                12'd1042: toneR = `hd;
                12'd1043: toneR = `hd;
                12'd1044: toneR = `hd;
                12'd1045: toneR = `hd;
                12'd1046: toneR = `hd;
                12'd1047: toneR = `hd;
                12'd1048: toneR = `hd;
                12'd1049: toneR = `hd;
                12'd1050: toneR = `hd;
                12'd1051: toneR = `hd;
                12'd1052: toneR = `hd;
                12'd1053: toneR = `hd;
                12'd1054: toneR = `hd;
                12'd1055: toneR = `hd;
                12'd1056: toneR = `hc;
                12'd1057: toneR = `hc;
                12'd1058: toneR = `hc;
                12'd1059: toneR = `hc;
                12'd1060: toneR = `hc;
                12'd1061: toneR = `hc;
                12'd1062: toneR = `hc;
                12'd1063: toneR = `hc;
                12'd1064: toneR = `hc;
                12'd1065: toneR = `hc;
                12'd1066: toneR = `hc;
                12'd1067: toneR = `hc;
                12'd1068: toneR = `hc;
                12'd1069: toneR = `hc;
                12'd1070: toneR = `hc;
                12'd1071: toneR = `hc;
                12'd1072: toneR = `g;
                12'd1073: toneR = `g;
                12'd1074: toneR = `g;
                12'd1075: toneR = `g;
                12'd1076: toneR = `g;
                12'd1077: toneR = `g;
                12'd1078: toneR = `g;
                12'd1079: toneR = `g;
                12'd1080: toneR = `g;
                12'd1081: toneR = `g;
                12'd1082: toneR = `g;
                12'd1083: toneR = `g;
                12'd1084: toneR = `g;
                12'd1085: toneR = `g;
                12'd1086: toneR = `g;
                12'd1087: toneR = `g;
                12'd1088: toneR = `sil;
                12'd1089: toneR = `sil;
                12'd1090: toneR = `sil;
                12'd1091: toneR = `sil;
                12'd1092: toneR = `sil;
                12'd1093: toneR = `sil;
                12'd1094: toneR = `sil;
                12'd1095: toneR = `sil;
                12'd1096: toneR = `sil;
                12'd1097: toneR = `sil;
                12'd1098: toneR = `sil;
                12'd1099: toneR = `sil;
                12'd1100: toneR = `sil;
                12'd1101: toneR = `sil;
                12'd1102: toneR = `sil;
                12'd1103: toneR = `sil;
                12'd1104: toneR = `sil;
                12'd1105: toneR = `sil;
                12'd1106: toneR = `sil;
                12'd1107: toneR = `sil;
                12'd1108: toneR = `sil;
                12'd1109: toneR = `sil;
                12'd1110: toneR = `sil;
                12'd1111: toneR = `sil;
                12'd1112: toneR = `hc;
                12'd1113: toneR = `hc;
                12'd1114: toneR = `hc;
                12'd1115: toneR = `hc;
                12'd1116: toneR = `hc;
                12'd1117: toneR = `hc;
                12'd1118: toneR = `hc;
                12'd1119: toneR = `hc;
                12'd1120: toneR = `b;
                12'd1121: toneR = `b;
                12'd1122: toneR = `b;
                12'd1123: toneR = `b;
                12'd1124: toneR = `b;
                12'd1125: toneR = `b;
                12'd1126: toneR = `b;
                12'd1127: toneR = `b;
                12'd1128: toneR = `sa;
                12'd1129: toneR = `sa;
                12'd1130: toneR = `sa;
                12'd1131: toneR = `sa;
                12'd1132: toneR = `sa;
                12'd1133: toneR = `sa;
                12'd1134: toneR = `sa;
                12'd1135: toneR = `sa;
                12'd1136: toneR = `a;
                12'd1137: toneR = `a;
                12'd1138: toneR = `a;
                12'd1139: toneR = `a;
                12'd1140: toneR = `a;
                12'd1141: toneR = `a;
                12'd1142: toneR = `a;
                12'd1143: toneR = `a;
                12'd1144: toneR = `a;
                12'd1145: toneR = `a;
                12'd1146: toneR = `a;
                12'd1147: toneR = `a;
                12'd1148: toneR = `a;
                12'd1149: toneR = `a;
                12'd1150: toneR = `a;
                12'd1151: toneR = `a;
                12'd1152: toneR = `hc;
                12'd1153: toneR = `hc;
                12'd1154: toneR = `hc;
                12'd1155: toneR = `hc;
                12'd1156: toneR = `hc;
                12'd1157: toneR = `hc;
                12'd1158: toneR = `hc;
                12'd1159: toneR = `hc;
                12'd1160: toneR = `hc;
                12'd1161: toneR = `hc;
                12'd1162: toneR = `hc;
                12'd1163: toneR = `hc;
                12'd1164: toneR = `hc;
                12'd1165: toneR = `hc;
                12'd1166: toneR = `hc;
                12'd1167: toneR = `hc;
                12'd1168: toneR = `hd;
                12'd1169: toneR = `hd;
                12'd1170: toneR = `hd;
                12'd1171: toneR = `hd;
                12'd1172: toneR = `hd;
                12'd1173: toneR = `hd;
                12'd1174: toneR = `hd;
                12'd1175: toneR = `hd;
                12'd1176: toneR = `hd;
                12'd1177: toneR = `hd;
                12'd1178: toneR = `hd;
                12'd1179: toneR = `hd;
                12'd1180: toneR = `hd;
                12'd1181: toneR = `hd;
                12'd1182: toneR = `hd;
                12'd1183: toneR = `hd;
                12'd1184: toneR = `hc;
                12'd1185: toneR = `hc;
                12'd1186: toneR = `hc;
                12'd1187: toneR = `hc;
                12'd1188: toneR = `hc;
                12'd1189: toneR = `hc;
                12'd1190: toneR = `hc;
                12'd1191: toneR = `hc;
                12'd1192: toneR = `hc;
                12'd1193: toneR = `hc;
                12'd1194: toneR = `hc;
                12'd1195: toneR = `hc;
                12'd1196: toneR = `hc;
                12'd1197: toneR = `hc;
                12'd1198: toneR = `hc;
                12'd1199: toneR = `hc;
                12'd1200: toneR = `g;
                12'd1201: toneR = `g;
                12'd1202: toneR = `g;
                12'd1203: toneR = `g;
                12'd1204: toneR = `g;
                12'd1205: toneR = `g;
                12'd1206: toneR = `g;
                12'd1207: toneR = `g;
                12'd1208: toneR = `g;
                12'd1209: toneR = `g;
                12'd1210: toneR = `g;
                12'd1211: toneR = `g;
                12'd1212: toneR = `g;
                12'd1213: toneR = `g;
                12'd1214: toneR = `g;
                12'd1215: toneR = `g;
                12'd1216: toneR = `sil;
                12'd1217: toneR = `sil;
                12'd1218: toneR = `sil;
                12'd1219: toneR = `sil;
                12'd1220: toneR = `sil;
                12'd1221: toneR = `sil;
                12'd1222: toneR = `sil;
                12'd1223: toneR = `sil;
                12'd1224: toneR = `sil;
                12'd1225: toneR = `sil;
                12'd1226: toneR = `sil;
                12'd1227: toneR = `sil;
                12'd1228: toneR = `sil;
                12'd1229: toneR = `sil;
                12'd1230: toneR = `sil;
                12'd1231: toneR = `sil;
                12'd1232: toneR = `sil;
                12'd1233: toneR = `sil;
                12'd1234: toneR = `sil;
                12'd1235: toneR = `sil;
                12'd1236: toneR = `sil;
                12'd1237: toneR = `sil;
                12'd1238: toneR = `sil;
                12'd1239: toneR = `sil;
                12'd1240: toneR = `hc;
                12'd1241: toneR = `hc;
                12'd1242: toneR = `hc;
                12'd1243: toneR = `hc;
                12'd1244: toneR = `hc;
                12'd1245: toneR = `hc;
                12'd1246: toneR = `hc;
                12'd1247: toneR = `hc;
                12'd1248: toneR = `b;
                12'd1249: toneR = `b;
                12'd1250: toneR = `b;
                12'd1251: toneR = `b;
                12'd1252: toneR = `b;
                12'd1253: toneR = `b;
                12'd1254: toneR = `b;
                12'd1255: toneR = `b;
                12'd1256: toneR = `sa;
                12'd1257: toneR = `sa;
                12'd1258: toneR = `sa;
                12'd1259: toneR = `sa;
                12'd1260: toneR = `sa;
                12'd1261: toneR = `sa;
                12'd1262: toneR = `sa;
                12'd1263: toneR = `sa;
                12'd1264: toneR = `a;
                12'd1265: toneR = `a;
                12'd1266: toneR = `a;
                12'd1267: toneR = `a;
                12'd1268: toneR = `a;
                12'd1269: toneR = `a;
                12'd1270: toneR = `a;
                12'd1271: toneR = `a;
                12'd1272: toneR = `a;
                12'd1273: toneR = `a;
                12'd1274: toneR = `a;
                12'd1275: toneR = `a;
                12'd1276: toneR = `a;
                12'd1277: toneR = `a;
                12'd1278: toneR = `a;
                12'd1279: toneR = `a;
                12'd1280: toneR = `hc;
                12'd1281: toneR = `hc;
                12'd1282: toneR = `hc;
                12'd1283: toneR = `hc;
                12'd1284: toneR = `hc;
                12'd1285: toneR = `hc;
                12'd1286: toneR = `hc;
                12'd1287: toneR = `hc;
                12'd1288: toneR = `hc;
                12'd1289: toneR = `hc;
                12'd1290: toneR = `hc;
                12'd1291: toneR = `hc;
                12'd1292: toneR = `hc;
                12'd1293: toneR = `hc;
                12'd1294: toneR = `hc;
                12'd1295: toneR = `hc;
                12'd1296: toneR = `hd;
                12'd1297: toneR = `hd;
                12'd1298: toneR = `hd;
                12'd1299: toneR = `hd;
                12'd1300: toneR = `hd;
                12'd1301: toneR = `hd;
                12'd1302: toneR = `hd;
                12'd1303: toneR = `hd;
                12'd1304: toneR = `hd;
                12'd1305: toneR = `hd;
                12'd1306: toneR = `hd;
                12'd1307: toneR = `hd;
                12'd1308: toneR = `hd;
                12'd1309: toneR = `hd;
                12'd1310: toneR = `hd;
                12'd1311: toneR = `hd;
                12'd1312: toneR = `hc;
                12'd1313: toneR = `hc;
                12'd1314: toneR = `hc;
                12'd1315: toneR = `hc;
                12'd1316: toneR = `hc;
                12'd1317: toneR = `hc;
                12'd1318: toneR = `hc;
                12'd1319: toneR = `hc;
                12'd1320: toneR = `hd;
                12'd1321: toneR = `hd;
                12'd1322: toneR = `hd;
                12'd1323: toneR = `hd;
                12'd1324: toneR = `hd;
                12'd1325: toneR = `hd;
                12'd1326: toneR = `hd;
                12'd1327: toneR = `hd;
                12'd1328: toneR = `he;
                12'd1329: toneR = `he;
                12'd1330: toneR = `he;
                12'd1331: toneR = `he;
                12'd1332: toneR = `he;
                12'd1333: toneR = `he;
                12'd1334: toneR = `he;
                12'd1335: toneR = `he;
                12'd1336: toneR = `hd;
                12'd1337: toneR = `hd;
                12'd1338: toneR = `hd;
                12'd1339: toneR = `hd;
                12'd1340: toneR = `hd;
                12'd1341: toneR = `hd;
                12'd1342: toneR = `hd;
                12'd1343: toneR = `hd;
                12'd1344: toneR = `he;
                12'd1345: toneR = `he;
                12'd1346: toneR = `he;
                12'd1347: toneR = `he;
                12'd1348: toneR = `he;
                12'd1349: toneR = `he;
                12'd1350: toneR = `he;
                12'd1351: toneR = `he;
                12'd1352: toneR = `hc;
                12'd1353: toneR = `hc;
                12'd1354: toneR = `hc;
                12'd1355: toneR = `hc;
                12'd1356: toneR = `hc;
                12'd1357: toneR = `hc;
                12'd1358: toneR = `hc;
                12'd1359: toneR = `hc;
                12'd1360: toneR = `sil;
                12'd1361: toneR = `sil;
                12'd1362: toneR = `sil;
                12'd1363: toneR = `sil;
                12'd1364: toneR = `sil;
                12'd1365: toneR = `sil;
                12'd1366: toneR = `sil;
                12'd1367: toneR = `sil;
                12'd1368: toneR = `hc;
                12'd1369: toneR = `hc;
                12'd1370: toneR = `hc;
                12'd1371: toneR = `hc;
                12'd1372: toneR = `hc;
                12'd1373: toneR = `hc;
                12'd1374: toneR = `hc;
                12'd1375: toneR = `hc;
                12'd1376: toneR = `hd;
                12'd1377: toneR = `hd;
                12'd1378: toneR = `hd;
                12'd1379: toneR = `hd;
                12'd1380: toneR = `hd;
                12'd1381: toneR = `hd;
                12'd1382: toneR = `hd;
                12'd1383: toneR = `hd;
                12'd1384: toneR = `he;
                12'd1385: toneR = `he;
                12'd1386: toneR = `he;
                12'd1387: toneR = `he;
                12'd1388: toneR = `he;
                12'd1389: toneR = `he;
                12'd1390: toneR = `he;
                12'd1391: toneR = `he;
                12'd1392: toneR = `hf;
                12'd1393: toneR = `hf;
                12'd1394: toneR = `hf;
                12'd1395: toneR = `hf;
                12'd1396: toneR = `hf;
                12'd1397: toneR = `hf;
                12'd1398: toneR = `hf;
                12'd1399: toneR = `hf;
                12'd1400: toneR = `hf;
                12'd1401: toneR = `hf;
                12'd1402: toneR = `hf;
                12'd1403: toneR = `hf;
                12'd1404: toneR = `hf;
                12'd1405: toneR = `hf;
                12'd1406: toneR = `hf;
                12'd1407: toneR = `hf;
                12'd1408: toneR = `a;
                12'd1409: toneR = `a;
                12'd1410: toneR = `a;
                12'd1411: toneR = `a;
                12'd1412: toneR = `a;
                12'd1413: toneR = `a;
                12'd1414: toneR = `a;
                12'd1415: toneR = `a;
                12'd1416: toneR = `a;
                12'd1417: toneR = `a;
                12'd1418: toneR = `a;
                12'd1419: toneR = `a;
                12'd1420: toneR = `a;
                12'd1421: toneR = `a;
                12'd1422: toneR = `a;
                12'd1423: toneR = `a;
                12'd1424: toneR = `b;
                12'd1425: toneR = `b;
                12'd1426: toneR = `b;
                12'd1427: toneR = `b;
                12'd1428: toneR = `b;
                12'd1429: toneR = `b;
                12'd1430: toneR = `b;
                12'd1431: toneR = `b;
                12'd1432: toneR = `b;
                12'd1433: toneR = `b;
                12'd1434: toneR = `b;
                12'd1435: toneR = `b;
                12'd1436: toneR = `b;
                12'd1437: toneR = `b;
                12'd1438: toneR = `b;
                12'd1439: toneR = `b;
                12'd1440: toneR = `hd;
                12'd1441: toneR = `hd;
                12'd1442: toneR = `hd;
                12'd1443: toneR = `hd;
                12'd1444: toneR = `hd;
                12'd1445: toneR = `hd;
                12'd1446: toneR = `hd;
                12'd1447: toneR = `hd;
                12'd1448: toneR = `hd;
                12'd1449: toneR = `hd;
                12'd1450: toneR = `hd;
                12'd1451: toneR = `hd;
                12'd1452: toneR = `hd;
                12'd1453: toneR = `hd;
                12'd1454: toneR = `hd;
                12'd1455: toneR = `hd;
                12'd1456: toneR = `hc;
                12'd1457: toneR = `hc;
                12'd1458: toneR = `hc;
                12'd1459: toneR = `hc;
                12'd1460: toneR = `hc;
                12'd1461: toneR = `hc;
                12'd1462: toneR = `hc;
                12'd1463: toneR = `hc;
                12'd1464: toneR = `hc;
                12'd1465: toneR = `hc;
                12'd1466: toneR = `hc;
                12'd1467: toneR = `hc;
                12'd1468: toneR = `hc;
                12'd1469: toneR = `hc;
                12'd1470: toneR = `hc;
                12'd1471: toneR = `hc;
                12'd1472: toneR = `sil;
                12'd1473: toneR = `sil;
                12'd1474: toneR = `sil;
                12'd1475: toneR = `sil;
                12'd1476: toneR = `sil;
                12'd1477: toneR = `sil;
                12'd1478: toneR = `sil;
                12'd1479: toneR = `sil;
                12'd1480: toneR = `sil;
                12'd1481: toneR = `sil;
                12'd1482: toneR = `sil;
                12'd1483: toneR = `sil;
                12'd1484: toneR = `sil;
                12'd1485: toneR = `sil;
                12'd1486: toneR = `sil;
                12'd1487: toneR = `sil;
                12'd1488: toneR = `sil;
                12'd1489: toneR = `sil;
                12'd1490: toneR = `sil;
                12'd1491: toneR = `sil;
                12'd1492: toneR = `sil;
                12'd1493: toneR = `sil;
                12'd1494: toneR = `sil;
                12'd1495: toneR = `sil;
                12'd1496: toneR = `sil;
                12'd1497: toneR = `sil;
                12'd1498: toneR = `sil;
                12'd1499: toneR = `sil;
                12'd1500: toneR = `sil;
                12'd1501: toneR = `sil;
                12'd1502: toneR = `sil;
                12'd1503: toneR = `sil;
                12'd1504: toneR = `sil;
                12'd1505: toneR = `sil;
                12'd1506: toneR = `sil;
                12'd1507: toneR = `sil;
                12'd1508: toneR = `sil;
                12'd1509: toneR = `sil;
                12'd1510: toneR = `sil;
                12'd1511: toneR = `sil;
                12'd1512: toneR = `sil;
                12'd1513: toneR = `sil;
                12'd1514: toneR = `sil;
                12'd1515: toneR = `sil;
                12'd1516: toneR = `sil;
                12'd1517: toneR = `sil;
                12'd1518: toneR = `sil;
                12'd1519: toneR = `sil;
                12'd1520: toneR = `sil;
                12'd1521: toneR = `sil;
                12'd1522: toneR = `sil;
                12'd1523: toneR = `sil;
                12'd1524: toneR = `sil;
                12'd1525: toneR = `sil;
                12'd1526: toneR = `sil;
                12'd1527: toneR = `sil;
                12'd1528: toneR = `sil;
                12'd1529: toneR = `sil;
                12'd1530: toneR = `sil;
                12'd1531: toneR = `sil;
                12'd1532: toneR = `sil;
                12'd1533: toneR = `sil;
                12'd1534: toneR = `sil;
                12'd1535: toneR = `sil;
            default:toneR = `sil;
        endcase
    end
    else toneR = `sil;
end

always @(*) begin
    if(en) begin
        case(ibeatNum)
                12'd0: toneL = `sil;
                12'd1: toneL = `sil;
                12'd2: toneL = `sil;
                12'd3: toneL = `sil;
                12'd4: toneL = `sil;
                12'd5: toneL = `sil;
                12'd6: toneL = `sil;
                12'd7: toneL = `sil;
                12'd8: toneL = `sil;
                12'd9: toneL = `sil;
                12'd10: toneL = `sil;
                12'd11: toneL = `sil;
                12'd12: toneL = `sil;
                12'd13: toneL = `sil;
                12'd14: toneL = `sil;
                12'd15: toneL = `sil;
                12'd16: toneL = `sil;
                12'd17: toneL = `sil;
                12'd18: toneL = `sil;
                12'd19: toneL = `sil;
                12'd20: toneL = `sil;
                12'd21: toneL = `sil;
                12'd22: toneL = `sil;
                12'd23: toneL = `sil;
                12'd24: toneL = `lg;
                12'd25: toneL = `lg;
                12'd26: toneL = `lg;
                12'd27: toneL = `lg;
                12'd28: toneL = `sil;
                12'd29: toneL = `sil;
                12'd30: toneL = `sil;
                12'd31: toneL = `sil;
                12'd32: toneL = `sil;
                12'd33: toneL = `sil;
                12'd34: toneL = `sil;
                12'd35: toneL = `sil;
                12'd36: toneL = `sil;
                12'd37: toneL = `sil;
                12'd38: toneL = `sil;
                12'd39: toneL = `sil;
                12'd40: toneL = `sil;
                12'd41: toneL = `sil;
                12'd42: toneL = `sil;
                12'd43: toneL = `sil;
                12'd44: toneL = `sil;
                12'd45: toneL = `sil;
                12'd46: toneL = `sil;
                12'd47: toneL = `sil;
                12'd48: toneL = `sil;
                12'd49: toneL = `sil;
                12'd50: toneL = `sil;
                12'd51: toneL = `sil;
                12'd52: toneL = `sil;
                12'd53: toneL = `sil;
                12'd54: toneL = `sil;
                12'd55: toneL = `sil;
                12'd56: toneL = `lg;
                12'd57: toneL = `lg;
                12'd58: toneL = `lg;
                12'd59: toneL = `lg;
                12'd60: toneL = `sil;
                12'd61: toneL = `sil;
                12'd62: toneL = `sil;
                12'd63: toneL = `sil;
                12'd64: toneL = `d;
                12'd65: toneL = `d;
                12'd66: toneL = `d;
                12'd67: toneL = `d;
                12'd68: toneL = `d;
                12'd69: toneL = `d;
                12'd70: toneL = `d;
                12'd71: toneL = `d;
                12'd72: toneL = `d;
                12'd73: toneL = `d;
                12'd74: toneL = `d;
                12'd75: toneL = `d;
                12'd76: toneL = `d;
                12'd77: toneL = `d;
                12'd78: toneL = `d;
                12'd79: toneL = `d;
                12'd80: toneL = `e;
                12'd81: toneL = `e;
                12'd82: toneL = `e;
                12'd83: toneL = `e;
                12'd84: toneL = `e;
                12'd85: toneL = `e;
                12'd86: toneL = `e;
                12'd87: toneL = `e;
                12'd88: toneL = `e;
                12'd89: toneL = `e;
                12'd90: toneL = `e;
                12'd91: toneL = `e;
                12'd92: toneL = `e;
                12'd93: toneL = `e;
                12'd94: toneL = `e;
                12'd95: toneL = `e;
                12'd96: toneL = `f;
                12'd97: toneL = `f;
                12'd98: toneL = `f;
                12'd99: toneL = `f;
                12'd100: toneL = `f;
                12'd101: toneL = `f;
                12'd102: toneL = `f;
                12'd103: toneL = `f;
                12'd104: toneL = `f;
                12'd105: toneL = `f;
                12'd106: toneL = `f;
                12'd107: toneL = `f;
                12'd108: toneL = `f;
                12'd109: toneL = `f;
                12'd110: toneL = `f;
                12'd111: toneL = `f;
                12'd112: toneL = `g;
                12'd113: toneL = `g;
                12'd114: toneL = `g;
                12'd115: toneL = `g;
                12'd116: toneL = `g;
                12'd117: toneL = `g;
                12'd118: toneL = `g;
                12'd119: toneL = `g;
                12'd120: toneL = `g;
                12'd121: toneL = `g;
                12'd122: toneL = `g;
                12'd123: toneL = `g;
                12'd124: toneL = `g;
                12'd125: toneL = `g;
                12'd126: toneL = `g;
                12'd127: toneL = `g;
                12'd128: toneL = `g;
                12'd129: toneL = `g;
                12'd130: toneL = `g;
                12'd131: toneL = `g;
                12'd132: toneL = `g;
                12'd133: toneL = `g;
                12'd134: toneL = `g;
                12'd135: toneL = `g;
                12'd136: toneL = `g;
                12'd137: toneL = `g;
                12'd138: toneL = `g;
                12'd139: toneL = `g;
                12'd140: toneL = `g;
                12'd141: toneL = `g;
                12'd142: toneL = `g;
                12'd143: toneL = `sil;
                12'd144: toneL = `g;
                12'd145: toneL = `g;
                12'd146: toneL = `g;
                12'd147: toneL = `g;
                12'd148: toneL = `g;
                12'd149: toneL = `g;
                12'd150: toneL = `g;
                12'd151: toneL = `g;
                12'd152: toneL = `sf;
                12'd153: toneL = `sf;
                12'd154: toneL = `sf;
                12'd155: toneL = `sf;
                12'd156: toneL = `g;
                12'd157: toneL = `g;
                12'd158: toneL = `g;
                12'd159: toneL = `g;
                12'd160: toneL = `g;
                12'd161: toneL = `g;
                12'd162: toneL = `g;
                12'd163: toneL = `g;
                12'd164: toneL = `g;
                12'd165: toneL = `g;
                12'd166: toneL = `g;
                12'd167: toneL = `g;
                12'd168: toneL = `g;
                12'd169: toneL = `g;
                12'd170: toneL = `g;
                12'd171: toneL = `g;
                12'd172: toneL = `sil;
                12'd173: toneL = `sil;
                12'd174: toneL = `sil;
                12'd175: toneL = `sil;
                12'd176: toneL = `sil;
                12'd177: toneL = `sil;
                12'd178: toneL = `sil;
                12'd179: toneL = `sil;
                12'd180: toneL = `sil;
                12'd181: toneL = `sil;
                12'd182: toneL = `sil;
                12'd183: toneL = `sil;
                12'd184: toneL = `sil;
                12'd185: toneL = `sil;
                12'd186: toneL = `sil;
                12'd187: toneL = `sil;
                12'd188: toneL = `sil;
                12'd189: toneL = `sil;
                12'd190: toneL = `sil;
                12'd191: toneL = `sil;
                12'd192: toneL = `f;
                12'd193: toneL = `f;
                12'd194: toneL = `f;
                12'd195: toneL = `f;
                12'd196: toneL = `f;
                12'd197: toneL = `f;
                12'd198: toneL = `f;
                12'd199: toneL = `f;
                12'd200: toneL = `f;
                12'd201: toneL = `f;
                12'd202: toneL = `f;
                12'd203: toneL = `f;
                12'd204: toneL = `f;
                12'd205: toneL = `f;
                12'd206: toneL = `f;
                12'd207: toneL = `sil;
                12'd208: toneL = `f;
                12'd209: toneL = `f;
                12'd210: toneL = `f;
                12'd211: toneL = `f;
                12'd212: toneL = `f;
                12'd213: toneL = `f;
                12'd214: toneL = `f;
                12'd215: toneL = `f;
                12'd216: toneL = `g;
                12'd217: toneL = `g;
                12'd218: toneL = `g;
                12'd219: toneL = `g;
                12'd220: toneL = `d;
                12'd221: toneL = `d;
                12'd222: toneL = `d;
                12'd223: toneL = `d;
                12'd224: toneL = `d;
                12'd225: toneL = `d;
                12'd226: toneL = `d;
                12'd227: toneL = `d;
                12'd228: toneL = `d;
                12'd229: toneL = `d;
                12'd230: toneL = `d;
                12'd231: toneL = `d;
                12'd232: toneL = `d;
                12'd233: toneL = `d;
                12'd234: toneL = `d;
                12'd235: toneL = `d;
                12'd236: toneL = `sil;
                12'd237: toneL = `sil;
                12'd238: toneL = `sil;
                12'd239: toneL = `sil;
                12'd240: toneL = `la;
                12'd241: toneL = `la;
                12'd242: toneL = `la;
                12'd243: toneL = `la;
                12'd244: toneL = `la;
                12'd245: toneL = `la;
                12'd246: toneL = `la;
                12'd247: toneL = `la;
                12'd248: toneL = `lb;
                12'd249: toneL = `lb;
                12'd250: toneL = `lb;
                12'd251: toneL = `lb;
                12'd252: toneL = `lb;
                12'd253: toneL = `lb;
                12'd254: toneL = `lb;
                12'd255: toneL = `lb;
                12'd256: toneL = `c;
                12'd257: toneL = `c;
                12'd258: toneL = `c;
                12'd259: toneL = `c;
                12'd260: toneL = `c;
                12'd261: toneL = `c;
                12'd262: toneL = `c;
                12'd263: toneL = `c;
                12'd264: toneL = `c;
                12'd265: toneL = `c;
                12'd266: toneL = `c;
                12'd267: toneL = `c;
                12'd268: toneL = `c;
                12'd269: toneL = `c;
                12'd270: toneL = `c;
                12'd271: toneL = `c;
                12'd272: toneL = `c;
                12'd273: toneL = `c;
                12'd274: toneL = `c;
                12'd275: toneL = `c;
                12'd276: toneL = `c;
                12'd277: toneL = `c;
                12'd278: toneL = `c;
                12'd279: toneL = `c;
                12'd280: toneL = `c;
                12'd281: toneL = `c;
                12'd282: toneL = `c;
                12'd283: toneL = `c;
                12'd284: toneL = `c;
                12'd285: toneL = `c;
                12'd286: toneL = `c;
                12'd287: toneL = `c;
                12'd288: toneL = `sil;
                12'd289: toneL = `sil;
                12'd290: toneL = `sil;
                12'd291: toneL = `sil;
                12'd292: toneL = `sil;
                12'd293: toneL = `sil;
                12'd294: toneL = `sil;
                12'd295: toneL = `sil;
                12'd296: toneL = `sil;
                12'd297: toneL = `sil;
                12'd298: toneL = `sil;
                12'd299: toneL = `sil;
                12'd300: toneL = `sil;
                12'd301: toneL = `sil;
                12'd302: toneL = `sil;
                12'd303: toneL = `sil;
                12'd304: toneL = `sil;
                12'd305: toneL = `sil;
                12'd306: toneL = `sil;
                12'd307: toneL = `sil;
                12'd308: toneL = `sil;
                12'd309: toneL = `sil;
                12'd310: toneL = `sil;
                12'd311: toneL = `sil;
                12'd312: toneL = `lg;
                12'd313: toneL = `lg;
                12'd314: toneL = `lg;
                12'd315: toneL = `lg;
                12'd316: toneL = `lg;
                12'd317: toneL = `lg;
                12'd318: toneL = `lg;
                12'd319: toneL = `lg;
                12'd320: toneL = `la;
                12'd321: toneL = `la;
                12'd322: toneL = `la;
                12'd323: toneL = `la;
                12'd324: toneL = `la;
                12'd325: toneL = `la;
                12'd326: toneL = `la;
                12'd327: toneL = `la;
                12'd328: toneL = `la;
                12'd329: toneL = `la;
                12'd330: toneL = `la;
                12'd331: toneL = `la;
                12'd332: toneL = `la;
                12'd333: toneL = `la;
                12'd334: toneL = `la;
                12'd335: toneL = `la;
                12'd336: toneL = `la;
                12'd337: toneL = `la;
                12'd338: toneL = `la;
                12'd339: toneL = `la;
                12'd340: toneL = `la;
                12'd341: toneL = `la;
                12'd342: toneL = `la;
                12'd343: toneL = `la;
                12'd344: toneL = `la;
                12'd345: toneL = `la;
                12'd346: toneL = `la;
                12'd347: toneL = `la;
                12'd348: toneL = `la;
                12'd349: toneL = `la;
                12'd350: toneL = `la;
                12'd351: toneL = `la;
                12'd352: toneL = `la;
                12'd353: toneL = `la;
                12'd354: toneL = `la;
                12'd355: toneL = `la;
                12'd356: toneL = `la;
                12'd357: toneL = `la;
                12'd358: toneL = `la;
                12'd359: toneL = `la;
                12'd360: toneL = `la;
                12'd361: toneL = `la;
                12'd362: toneL = `la;
                12'd363: toneL = `la;
                12'd364: toneL = `la;
                12'd365: toneL = `la;
                12'd366: toneL = `la;
                12'd367: toneL = `la;
                12'd368: toneL = `la;
                12'd369: toneL = `la;
                12'd370: toneL = `la;
                12'd371: toneL = `la;
                12'd372: toneL = `la;
                12'd373: toneL = `la;
                12'd374: toneL = `la;
                12'd375: toneL = `la;
                12'd376: toneL = `la;
                12'd377: toneL = `la;
                12'd378: toneL = `la;
                12'd379: toneL = `la;
                12'd380: toneL = `la;
                12'd381: toneL = `la;
                12'd382: toneL = `la;
                12'd383: toneL = `la;
                12'd384: toneL = `g;
                12'd385: toneL = `g;
                12'd386: toneL = `g;
                12'd387: toneL = `g;
                12'd388: toneL = `g;
                12'd389: toneL = `g;
                12'd390: toneL = `g;
                12'd391: toneL = `g;
                12'd392: toneL = `g;
                12'd393: toneL = `g;
                12'd394: toneL = `g;
                12'd395: toneL = `g;
                12'd396: toneL = `g;
                12'd397: toneL = `g;
                12'd398: toneL = `g;
                12'd399: toneL = `sil;
                12'd400: toneL = `g;
                12'd401: toneL = `g;
                12'd402: toneL = `g;
                12'd403: toneL = `g;
                12'd404: toneL = `g;
                12'd405: toneL = `g;
                12'd406: toneL = `g;
                12'd407: toneL = `g;
                12'd408: toneL = `sf;
                12'd409: toneL = `sf;
                12'd410: toneL = `sf;
                12'd411: toneL = `sf;
                12'd412: toneL = `g;
                12'd413: toneL = `g;
                12'd414: toneL = `g;
                12'd415: toneL = `g;
                12'd416: toneL = `g;
                12'd417: toneL = `g;
                12'd418: toneL = `g;
                12'd419: toneL = `g;
                12'd420: toneL = `g;
                12'd421: toneL = `g;
                12'd422: toneL = `g;
                12'd423: toneL = `g;
                12'd424: toneL = `g;
                12'd425: toneL = `g;
                12'd426: toneL = `g;
                12'd427: toneL = `g;
                12'd428: toneL = `sil;
                12'd429: toneL = `sil;
                12'd430: toneL = `sil;
                12'd431: toneL = `sil;
                12'd432: toneL = `sil;
                12'd433: toneL = `sil;
                12'd434: toneL = `sil;
                12'd435: toneL = `sil;
                12'd436: toneL = `sil;
                12'd437: toneL = `sil;
                12'd438: toneL = `sil;
                12'd439: toneL = `sil;
                12'd440: toneL = `sil;
                12'd441: toneL = `sil;
                12'd442: toneL = `sil;
                12'd443: toneL = `sil;
                12'd444: toneL = `sil;
                12'd445: toneL = `sil;
                12'd446: toneL = `sil;
                12'd447: toneL = `sil;
                12'd448: toneL = `sil;
                12'd449: toneL = `sil;
                12'd450: toneL = `sil;
                12'd451: toneL = `sil;
                12'd452: toneL = `sil;
                12'd453: toneL = `sil;
                12'd454: toneL = `sil;
                12'd455: toneL = `sil;
                12'd456: toneL = `sil;
                12'd457: toneL = `sil;
                12'd458: toneL = `sil;
                12'd459: toneL = `sil;
                12'd460: toneL = `sil;
                12'd461: toneL = `sil;
                12'd462: toneL = `sil;
                12'd463: toneL = `sil;
                12'd464: toneL = `sil;
                12'd465: toneL = `sil;
                12'd466: toneL = `sil;
                12'd467: toneL = `sil;
                12'd468: toneL = `sil;
                12'd469: toneL = `sil;
                12'd470: toneL = `sil;
                12'd471: toneL = `sil;
                12'd472: toneL = `sil;
                12'd473: toneL = `sil;
                12'd474: toneL = `sil;
                12'd475: toneL = `sil;
                12'd476: toneL = `sil;
                12'd477: toneL = `sil;
                12'd478: toneL = `sil;
                12'd479: toneL = `sil;
                12'd480: toneL = `sil;
                12'd481: toneL = `sil;
                12'd482: toneL = `sil;
                12'd483: toneL = `sil;
                12'd484: toneL = `sil;
                12'd485: toneL = `sil;
                12'd486: toneL = `sil;
                12'd487: toneL = `sil;
                12'd488: toneL = `d;
                12'd489: toneL = `d;
                12'd490: toneL = `d;
                12'd491: toneL = `d;
                12'd492: toneL = `d;
                12'd493: toneL = `d;
                12'd494: toneL = `d;
                12'd495: toneL = `d;
                12'd496: toneL = `c;
                12'd497: toneL = `c;
                12'd498: toneL = `c;
                12'd499: toneL = `c;
                12'd500: toneL = `c;
                12'd501: toneL = `c;
                12'd502: toneL = `c;
                12'd503: toneL = `c;
                12'd504: toneL = `lg;
                12'd505: toneL = `lg;
                12'd506: toneL = `lg;
                12'd507: toneL = `lg;
                12'd508: toneL = `lg;
                12'd509: toneL = `lg;
                12'd510: toneL = `lg;
                12'd511: toneL = `lg;
                12'd512: toneL = `sil;
                12'd513: toneL = `sil;
                12'd514: toneL = `sil;
                12'd515: toneL = `sil;
                12'd516: toneL = `sil;
                12'd517: toneL = `sil;
                12'd518: toneL = `sil;
                12'd519: toneL = `sil;
                12'd520: toneL = `c;
                12'd521: toneL = `c;
                12'd522: toneL = `c;
                12'd523: toneL = `c;
                12'd524: toneL = `c;
                12'd525: toneL = `c;
                12'd526: toneL = `c;
                12'd527: toneL = `c;
                12'd528: toneL = `d;
                12'd529: toneL = `d;
                12'd530: toneL = `d;
                12'd531: toneL = `d;
                12'd532: toneL = `d;
                12'd533: toneL = `d;
                12'd534: toneL = `d;
                12'd535: toneL = `d;
                12'd536: toneL = `e;
                12'd537: toneL = `e;
                12'd538: toneL = `e;
                12'd539: toneL = `e;
                12'd540: toneL = `e;
                12'd541: toneL = `e;
                12'd542: toneL = `e;
                12'd543: toneL = `e;
                12'd544: toneL = `sil;
                12'd545: toneL = `sil;
                12'd546: toneL = `sil;
                12'd547: toneL = `sil;
                12'd548: toneL = `sil;
                12'd549: toneL = `sil;
                12'd550: toneL = `sil;
                12'd551: toneL = `sil;
                12'd552: toneL = `lg;
                12'd553: toneL = `lg;
                12'd554: toneL = `lg;
                12'd555: toneL = `lg;
                12'd556: toneL = `lg;
                12'd557: toneL = `lg;
                12'd558: toneL = `lg;
                12'd559: toneL = `lg;
                12'd560: toneL = `lg;
                12'd561: toneL = `lg;
                12'd562: toneL = `lg;
                12'd563: toneL = `lg;
                12'd564: toneL = `lg;
                12'd565: toneL = `lg;
                12'd566: toneL = `lg;
                12'd567: toneL = `lg;
                12'd568: toneL = `la;
                12'd569: toneL = `la;
                12'd570: toneL = `la;
                12'd571: toneL = `la;
                12'd572: toneL = `la;
                12'd573: toneL = `la;
                12'd574: toneL = `la;
                12'd575: toneL = `la;
                12'd576: toneL = `sil;
                12'd577: toneL = `sil;
                12'd578: toneL = `sil;
                12'd579: toneL = `sil;
                12'd580: toneL = `sil;
                12'd581: toneL = `sil;
                12'd582: toneL = `sil;
                12'd583: toneL = `sil;
                12'd584: toneL = `sil;
                12'd585: toneL = `sil;
                12'd586: toneL = `sil;
                12'd587: toneL = `sil;
                12'd588: toneL = `sil;
                12'd589: toneL = `sil;
                12'd590: toneL = `sil;
                12'd591: toneL = `sil;
                12'd592: toneL = `sil;
                12'd593: toneL = `sil;
                12'd594: toneL = `sil;
                12'd595: toneL = `sil;
                12'd596: toneL = `sil;
                12'd597: toneL = `sil;
                12'd598: toneL = `sil;
                12'd599: toneL = `sil;
                12'd600: toneL = `sil;
                12'd601: toneL = `sil;
                12'd602: toneL = `sil;
                12'd603: toneL = `sil;
                12'd604: toneL = `sil;
                12'd605: toneL = `sil;
                12'd606: toneL = `sil;
                12'd607: toneL = `sil;
                12'd608: toneL = `lb;
                12'd609: toneL = `lb;
                12'd610: toneL = `lb;
                12'd611: toneL = `lb;
                12'd612: toneL = `lb;
                12'd613: toneL = `lb;
                12'd614: toneL = `lb;
                12'd615: toneL = `lb;
                12'd616: toneL = `lb;
                12'd617: toneL = `lb;
                12'd618: toneL = `lb;
                12'd619: toneL = `lb;
                12'd620: toneL = `lb;
                12'd621: toneL = `lb;
                12'd622: toneL = `lb;
                12'd623: toneL = `lb;
                12'd624: toneL = `lf;
                12'd625: toneL = `lf;
                12'd626: toneL = `lf;
                12'd627: toneL = `lf;
                12'd628: toneL = `lf;
                12'd629: toneL = `lf;
                12'd630: toneL = `lf;
                12'd631: toneL = `lf;
                12'd632: toneL = `lf;
                12'd633: toneL = `lf;
                12'd634: toneL = `lf;
                12'd635: toneL = `lf;
                12'd636: toneL = `lf;
                12'd637: toneL = `lf;
                12'd638: toneL = `lf;
                12'd639: toneL = `lf;
                12'd640: toneL = `llb;
                12'd641: toneL = `llb;
                12'd642: toneL = `llb;
                12'd643: toneL = `llb;
                12'd644: toneL = `llb;
                12'd645: toneL = `llb;
                12'd646: toneL = `llb;
                12'd647: toneL = `llb;
                12'd648: toneL = `llb;
                12'd649: toneL = `llb;
                12'd650: toneL = `llb;
                12'd651: toneL = `llb;
                12'd652: toneL = `llb;
                12'd653: toneL = `llb;
                12'd654: toneL = `llb;
                12'd655: toneL = `llb;
                12'd656: toneL = `lg;
                12'd657: toneL = `lg;
                12'd658: toneL = `lg;
                12'd659: toneL = `lg;
                12'd660: toneL = `lg;
                12'd661: toneL = `lg;
                12'd662: toneL = `lg;
                12'd663: toneL = `lg;
                12'd664: toneL = `lg;
                12'd665: toneL = `lg;
                12'd666: toneL = `lg;
                12'd667: toneL = `lg;
                12'd668: toneL = `lg;
                12'd669: toneL = `lg;
                12'd670: toneL = `lg;
                12'd671: toneL = `lg;
                12'd672: toneL = `e;
                12'd673: toneL = `e;
                12'd674: toneL = `e;
                12'd675: toneL = `e;
                12'd676: toneL = `e;
                12'd677: toneL = `e;
                12'd678: toneL = `e;
                12'd679: toneL = `e;
                12'd680: toneL = `e;
                12'd681: toneL = `e;
                12'd682: toneL = `e;
                12'd683: toneL = `e;
                12'd684: toneL = `e;
                12'd685: toneL = `e;
                12'd686: toneL = `e;
                12'd687: toneL = `e;
                12'd688: toneL = `e;
                12'd689: toneL = `e;
                12'd690: toneL = `e;
                12'd691: toneL = `e;
                12'd692: toneL = `e;
                12'd693: toneL = `e;
                12'd694: toneL = `e;
                12'd695: toneL = `e;
                12'd696: toneL = `e;
                12'd697: toneL = `e;
                12'd698: toneL = `e;
                12'd699: toneL = `e;
                12'd700: toneL = `e;
                12'd701: toneL = `e;
                12'd702: toneL = `e;
                12'd703: toneL = `e;
                12'd704: toneL = `sil;
                12'd705: toneL = `sil;
                12'd706: toneL = `sil;
                12'd707: toneL = `sil;
                12'd708: toneL = `sil;
                12'd709: toneL = `sil;
                12'd710: toneL = `sil;
                12'd711: toneL = `sil;
                12'd712: toneL = `sil;
                12'd713: toneL = `sil;
                12'd714: toneL = `sil;
                12'd715: toneL = `sil;
                12'd716: toneL = `sil;
                12'd717: toneL = `sil;
                12'd718: toneL = `sil;
                12'd719: toneL = `sil;
                12'd720: toneL = `sil;
                12'd721: toneL = `sil;
                12'd722: toneL = `sil;
                12'd723: toneL = `sil;
                12'd724: toneL = `sil;
                12'd725: toneL = `sil;
                12'd726: toneL = `sil;
                12'd727: toneL = `sil;
                12'd728: toneL = `sil;
                12'd729: toneL = `sil;
                12'd730: toneL = `sil;
                12'd731: toneL = `sil;
                12'd732: toneL = `sil;
                12'd733: toneL = `sil;
                12'd734: toneL = `sil;
                12'd735: toneL = `sil;
                12'd736: toneL = `sil;
                12'd737: toneL = `sil;
                12'd738: toneL = `sil;
                12'd739: toneL = `sil;
                12'd740: toneL = `sil;
                12'd741: toneL = `sil;
                12'd742: toneL = `sil;
                12'd743: toneL = `sil;
                12'd744: toneL = `c;
                12'd745: toneL = `c;
                12'd746: toneL = `c;
                12'd747: toneL = `c;
                12'd748: toneL = `c;
                12'd749: toneL = `c;
                12'd750: toneL = `c;
                12'd751: toneL = `c;
                12'd752: toneL = `d;
                12'd753: toneL = `d;
                12'd754: toneL = `d;
                12'd755: toneL = `d;
                12'd756: toneL = `d;
                12'd757: toneL = `d;
                12'd758: toneL = `d;
                12'd759: toneL = `d;
                12'd760: toneL = `e;
                12'd761: toneL = `e;
                12'd762: toneL = `e;
                12'd763: toneL = `e;
                12'd764: toneL = `e;
                12'd765: toneL = `e;
                12'd766: toneL = `e;
                12'd767: toneL = `e;
                12'd768: toneL = `sil;
                12'd769: toneL = `sil;
                12'd770: toneL = `sil;
                12'd771: toneL = `sil;
                12'd772: toneL = `sil;
                12'd773: toneL = `sil;
                12'd774: toneL = `sil;
                12'd775: toneL = `sil;
                12'd776: toneL = `lg;
                12'd777: toneL = `lg;
                12'd778: toneL = `lg;
                12'd779: toneL = `lg;
                12'd780: toneL = `lg;
                12'd781: toneL = `lg;
                12'd782: toneL = `lg;
                12'd783: toneL = `lg;
                12'd784: toneL = `lg;
                12'd785: toneL = `lg;
                12'd786: toneL = `lg;
                12'd787: toneL = `lg;
                12'd788: toneL = `lg;
                12'd789: toneL = `lg;
                12'd790: toneL = `lg;
                12'd791: toneL = `lg;
                12'd792: toneL = `la;
                12'd793: toneL = `la;
                12'd794: toneL = `la;
                12'd795: toneL = `la;
                12'd796: toneL = `la;
                12'd797: toneL = `la;
                12'd798: toneL = `la;
                12'd799: toneL = `la;
                12'd800: toneL = `la;
                12'd801: toneL = `la;
                12'd802: toneL = `la;
                12'd803: toneL = `la;
                12'd804: toneL = `la;
                12'd805: toneL = `la;
                12'd806: toneL = `la;
                12'd807: toneL = `la;
                12'd808: toneL = `la;
                12'd809: toneL = `la;
                12'd810: toneL = `la;
                12'd811: toneL = `la;
                12'd812: toneL = `la;
                12'd813: toneL = `la;
                12'd814: toneL = `la;
                12'd815: toneL = `la;
                12'd816: toneL = `la;
                12'd817: toneL = `la;
                12'd818: toneL = `la;
                12'd819: toneL = `la;
                12'd820: toneL = `la;
                12'd821: toneL = `la;
                12'd822: toneL = `la;
                12'd823: toneL = `la;
                12'd824: toneL = `sil;
                12'd825: toneL = `sil;
                12'd826: toneL = `sil;
                12'd827: toneL = `sil;
                12'd828: toneL = `sil;
                12'd829: toneL = `sil;
                12'd830: toneL = `sil;
                12'd831: toneL = `sil;
                12'd832: toneL = `d;
                12'd833: toneL = `d;
                12'd834: toneL = `d;
                12'd835: toneL = `d;
                12'd836: toneL = `d;
                12'd837: toneL = `d;
                12'd838: toneL = `d;
                12'd839: toneL = `d;
                12'd840: toneL = `d;
                12'd841: toneL = `d;
                12'd842: toneL = `d;
                12'd843: toneL = `d;
                12'd844: toneL = `d;
                12'd845: toneL = `d;
                12'd846: toneL = `d;
                12'd847: toneL = `d;
                12'd848: toneL = `sf;
                12'd849: toneL = `sf;
                12'd850: toneL = `sf;
                12'd851: toneL = `sf;
                12'd852: toneL = `sf;
                12'd853: toneL = `sf;
                12'd854: toneL = `sf;
                12'd855: toneL = `sf;
                12'd856: toneL = `sf;
                12'd857: toneL = `sf;
                12'd858: toneL = `sf;
                12'd859: toneL = `sf;
                12'd860: toneL = `sf;
                12'd861: toneL = `sf;
                12'd862: toneL = `sf;
                12'd863: toneL = `sf;
                12'd864: toneL = `sil;
                12'd865: toneL = `sil;
                12'd866: toneL = `sil;
                12'd867: toneL = `sil;
                12'd868: toneL = `sil;
                12'd869: toneL = `sil;
                12'd870: toneL = `sil;
                12'd871: toneL = `sil;
                12'd872: toneL = `e;
                12'd873: toneL = `e;
                12'd874: toneL = `e;
                12'd875: toneL = `e;
                12'd876: toneL = `e;
                12'd877: toneL = `e;
                12'd878: toneL = `e;
                12'd879: toneL = `e;
                12'd880: toneL = `e;
                12'd881: toneL = `e;
                12'd882: toneL = `e;
                12'd883: toneL = `e;
                12'd884: toneL = `e;
                12'd885: toneL = `e;
                12'd886: toneL = `e;
                12'd887: toneL = `e;
                12'd888: toneL = `sil;
                12'd889: toneL = `sil;
                12'd890: toneL = `sil;
                12'd891: toneL = `sil;
                12'd892: toneL = `sil;
                12'd893: toneL = `sil;
                12'd894: toneL = `sil;
                12'd895: toneL = `sil;
                12'd896: toneL = `sil;
                12'd897: toneL = `sil;
                12'd898: toneL = `sil;
                12'd899: toneL = `sil;
                12'd900: toneL = `sil;
                12'd901: toneL = `sil;
                12'd902: toneL = `sil;
                12'd903: toneL = `sil;
                12'd904: toneL = `sil;
                12'd905: toneL = `sil;
                12'd906: toneL = `sil;
                12'd907: toneL = `sil;
                12'd908: toneL = `sil;
                12'd909: toneL = `sil;
                12'd910: toneL = `sil;
                12'd911: toneL = `sil;
                12'd912: toneL = `sil;
                12'd913: toneL = `sil;
                12'd914: toneL = `sil;
                12'd915: toneL = `sil;
                12'd916: toneL = `sil;
                12'd917: toneL = `sil;
                12'd918: toneL = `sil;
                12'd919: toneL = `sil;
                12'd920: toneL = `c;
                12'd921: toneL = `c;
                12'd922: toneL = `c;
                12'd923: toneL = `c;
                12'd924: toneL = `c;
                12'd925: toneL = `c;
                12'd926: toneL = `c;
                12'd927: toneL = `c;
                12'd928: toneL = `c;
                12'd929: toneL = `c;
                12'd930: toneL = `c;
                12'd931: toneL = `c;
                12'd932: toneL = `c;
                12'd933: toneL = `c;
                12'd934: toneL = `c;
                12'd935: toneL = `c;
                12'd936: toneL = `c;
                12'd937: toneL = `c;
                12'd938: toneL = `c;
                12'd939: toneL = `c;
                12'd940: toneL = `c;
                12'd941: toneL = `c;
                12'd942: toneL = `c;
                12'd943: toneL = `c;
                12'd944: toneL = `c;
                12'd945: toneL = `c;
                12'd946: toneL = `c;
                12'd947: toneL = `c;
                12'd948: toneL = `c;
                12'd949: toneL = `c;
                12'd950: toneL = `c;
                12'd951: toneL = `c;
                12'd952: toneL = `sil;
                12'd953: toneL = `sil;
                12'd954: toneL = `sil;
                12'd955: toneL = `sil;
                12'd956: toneL = `sil;
                12'd957: toneL = `sil;
                12'd958: toneL = `sil;
                12'd959: toneL = `sil;
                12'd960: toneL = `c;
                12'd961: toneL = `c;
                12'd962: toneL = `c;
                12'd963: toneL = `c;
                12'd964: toneL = `c;
                12'd965: toneL = `c;
                12'd966: toneL = `c;
                12'd967: toneL = `c;
                12'd968: toneL = `lb;
                12'd969: toneL = `lb;
                12'd970: toneL = `lb;
                12'd971: toneL = `lb;
                12'd972: toneL = `lb;
                12'd973: toneL = `lb;
                12'd974: toneL = `lb;
                12'd975: toneL = `lb;
                12'd976: toneL = `lsa;
                12'd977: toneL = `lsa;
                12'd978: toneL = `lsa;
                12'd979: toneL = `lsa;
                12'd980: toneL = `lsa;
                12'd981: toneL = `lsa;
                12'd982: toneL = `lsa;
                12'd983: toneL = `lsa;
                12'd984: toneL = `lsa;
                12'd985: toneL = `lsa;
                12'd986: toneL = `lsa;
                12'd987: toneL = `lsa;
                12'd988: toneL = `lsa;
                12'd989: toneL = `lsa;
                12'd990: toneL = `lsa;
                12'd991: toneL = `lsa;
                12'd992: toneL = `sil;
                12'd993: toneL = `sil;
                12'd994: toneL = `sil;
                12'd995: toneL = `sil;
                12'd996: toneL = `sil;
                12'd997: toneL = `sil;
                12'd998: toneL = `sil;
                12'd999: toneL = `sil;
                12'd1000: toneL = `sil;
                12'd1001: toneL = `sil;
                12'd1002: toneL = `sil;
                12'd1003: toneL = `sil;
                12'd1004: toneL = `sil;
                12'd1005: toneL = `sil;
                12'd1006: toneL = `sil;
                12'd1007: toneL = `sil;
                12'd1008: toneL = `la;
                12'd1009: toneL = `la;
                12'd1010: toneL = `la;
                12'd1011: toneL = `la;
                12'd1012: toneL = `la;
                12'd1013: toneL = `la;
                12'd1014: toneL = `la;
                12'd1015: toneL = `la;
                12'd1016: toneL = `lb;
                12'd1017: toneL = `lb;
                12'd1018: toneL = `lb;
                12'd1019: toneL = `lb;
                12'd1020: toneL = `lb;
                12'd1021: toneL = `lb;
                12'd1022: toneL = `lb;
                12'd1023: toneL = `lb;
                12'd1024: toneL = `c;
                12'd1025: toneL = `c;
                12'd1026: toneL = `c;
                12'd1027: toneL = `c;
                12'd1028: toneL = `c;
                12'd1029: toneL = `c;
                12'd1030: toneL = `c;
                12'd1031: toneL = `c;
                12'd1032: toneL = `d;
                12'd1033: toneL = `d;
                12'd1034: toneL = `d;
                12'd1035: toneL = `d;
                12'd1036: toneL = `d;
                12'd1037: toneL = `d;
                12'd1038: toneL = `d;
                12'd1039: toneL = `d;
                12'd1040: toneL = `f;
                12'd1041: toneL = `f;
                12'd1042: toneL = `f;
                12'd1043: toneL = `f;
                12'd1044: toneL = `f;
                12'd1045: toneL = `f;
                12'd1046: toneL = `f;
                12'd1047: toneL = `f;
                12'd1048: toneL = `d;
                12'd1049: toneL = `d;
                12'd1050: toneL = `d;
                12'd1051: toneL = `d;
                12'd1052: toneL = `d;
                12'd1053: toneL = `d;
                12'd1054: toneL = `d;
                12'd1055: toneL = `d;
                12'd1056: toneL = `c;
                12'd1057: toneL = `c;
                12'd1058: toneL = `c;
                12'd1059: toneL = `c;
                12'd1060: toneL = `c;
                12'd1061: toneL = `c;
                12'd1062: toneL = `c;
                12'd1063: toneL = `c;
                12'd1064: toneL = `c;
                12'd1065: toneL = `c;
                12'd1066: toneL = `c;
                12'd1067: toneL = `c;
                12'd1068: toneL = `c;
                12'd1069: toneL = `c;
                12'd1070: toneL = `c;
                12'd1071: toneL = `c;
                12'd1072: toneL = `lg;
                12'd1073: toneL = `lg;
                12'd1074: toneL = `lg;
                12'd1075: toneL = `lg;
                12'd1076: toneL = `lg;
                12'd1077: toneL = `lg;
                12'd1078: toneL = `lg;
                12'd1079: toneL = `lg;
                12'd1080: toneL = `lg;
                12'd1081: toneL = `lg;
                12'd1082: toneL = `lg;
                12'd1083: toneL = `lg;
                12'd1084: toneL = `lg;
                12'd1085: toneL = `lg;
                12'd1086: toneL = `lg;
                12'd1087: toneL = `lg;
                12'd1088: toneL = `sil;
                12'd1089: toneL = `sil;
                12'd1090: toneL = `sil;
                12'd1091: toneL = `sil;
                12'd1092: toneL = `sil;
                12'd1093: toneL = `sil;
                12'd1094: toneL = `sil;
                12'd1095: toneL = `sil;
                12'd1096: toneL = `c;
                12'd1097: toneL = `c;
                12'd1098: toneL = `c;
                12'd1099: toneL = `c;
                12'd1100: toneL = `c;
                12'd1101: toneL = `c;
                12'd1102: toneL = `c;
                12'd1103: toneL = `c;
                12'd1104: toneL = `lb;
                12'd1105: toneL = `lb;
                12'd1106: toneL = `lb;
                12'd1107: toneL = `lb;
                12'd1108: toneL = `lb;
                12'd1109: toneL = `lb;
                12'd1110: toneL = `lb;
                12'd1111: toneL = `lb;
                12'd1112: toneL = `sil;
                12'd1113: toneL = `sil;
                12'd1114: toneL = `sil;
                12'd1115: toneL = `sil;
                12'd1116: toneL = `sil;
                12'd1117: toneL = `sil;
                12'd1118: toneL = `sil;
                12'd1119: toneL = `sil;
                12'd1120: toneL = `sil;
                12'd1121: toneL = `sil;
                12'd1122: toneL = `sil;
                12'd1123: toneL = `sil;
                12'd1124: toneL = `sil;
                12'd1125: toneL = `sil;
                12'd1126: toneL = `sil;
                12'd1127: toneL = `sil;
                12'd1128: toneL = `sil;
                12'd1129: toneL = `sil;
                12'd1130: toneL = `sil;
                12'd1131: toneL = `sil;
                12'd1132: toneL = `sil;
                12'd1133: toneL = `sil;
                12'd1134: toneL = `sil;
                12'd1135: toneL = `sil;
                12'd1136: toneL = `sil;
                12'd1137: toneL = `sil;
                12'd1138: toneL = `sil;
                12'd1139: toneL = `sil;
                12'd1140: toneL = `sil;
                12'd1141: toneL = `sil;
                12'd1142: toneL = `sil;
                12'd1143: toneL = `sil;
                12'd1144: toneL = `sil;
                12'd1145: toneL = `sil;
                12'd1146: toneL = `sil;
                12'd1147: toneL = `sil;
                12'd1148: toneL = `sil;
                12'd1149: toneL = `sil;
                12'd1150: toneL = `sil;
                12'd1151: toneL = `sil;
                12'd1152: toneL = `a;
                12'd1153: toneL = `a;
                12'd1154: toneL = `a;
                12'd1155: toneL = `a;
                12'd1156: toneL = `a;
                12'd1157: toneL = `a;
                12'd1158: toneL = `a;
                12'd1159: toneL = `a;
                12'd1160: toneL = `b;
                12'd1161: toneL = `b;
                12'd1162: toneL = `b;
                12'd1163: toneL = `b;
                12'd1164: toneL = `b;
                12'd1165: toneL = `b;
                12'd1166: toneL = `b;
                12'd1167: toneL = `b;
                12'd1168: toneL = `hc;
                12'd1169: toneL = `hc;
                12'd1170: toneL = `hc;
                12'd1171: toneL = `hc;
                12'd1172: toneL = `hc;
                12'd1173: toneL = `hc;
                12'd1174: toneL = `hc;
                12'd1175: toneL = `hc;
                12'd1176: toneL = `b;
                12'd1177: toneL = `b;
                12'd1178: toneL = `b;
                12'd1179: toneL = `b;
                12'd1180: toneL = `b;
                12'd1181: toneL = `b;
                12'd1182: toneL = `b;
                12'd1183: toneL = `b;
                12'd1184: toneL = `a;
                12'd1185: toneL = `a;
                12'd1186: toneL = `a;
                12'd1187: toneL = `a;
                12'd1188: toneL = `a;
                12'd1189: toneL = `a;
                12'd1190: toneL = `a;
                12'd1191: toneL = `a;
                12'd1192: toneL = `a;
                12'd1193: toneL = `a;
                12'd1194: toneL = `a;
                12'd1195: toneL = `a;
                12'd1196: toneL = `a;
                12'd1197: toneL = `a;
                12'd1198: toneL = `a;
                12'd1199: toneL = `a;
                12'd1200: toneL = `e;
                12'd1201: toneL = `e;
                12'd1202: toneL = `e;
                12'd1203: toneL = `e;
                12'd1204: toneL = `e;
                12'd1205: toneL = `e;
                12'd1206: toneL = `e;
                12'd1207: toneL = `e;
                12'd1208: toneL = `e;
                12'd1209: toneL = `e;
                12'd1210: toneL = `e;
                12'd1211: toneL = `e;
                12'd1212: toneL = `e;
                12'd1213: toneL = `e;
                12'd1214: toneL = `e;
                12'd1215: toneL = `e;
                12'd1216: toneL = `c;
                12'd1217: toneL = `c;
                12'd1218: toneL = `c;
                12'd1219: toneL = `c;
                12'd1220: toneL = `c;
                12'd1221: toneL = `c;
                12'd1222: toneL = `c;
                12'd1223: toneL = `c;
                12'd1224: toneL = `hc;
                12'd1225: toneL = `hc;
                12'd1226: toneL = `hc;
                12'd1227: toneL = `hc;
                12'd1228: toneL = `hc;
                12'd1229: toneL = `hc;
                12'd1230: toneL = `hc;
                12'd1231: toneL = `hc;
                12'd1232: toneL = `sil;
                12'd1233: toneL = `sil;
                12'd1234: toneL = `sil;
                12'd1235: toneL = `sil;
                12'd1236: toneL = `sil;
                12'd1237: toneL = `sil;
                12'd1238: toneL = `sil;
                12'd1239: toneL = `sil;
                12'd1240: toneL = `sil;
                12'd1241: toneL = `sil;
                12'd1242: toneL = `sil;
                12'd1243: toneL = `sil;
                12'd1244: toneL = `sil;
                12'd1245: toneL = `sil;
                12'd1246: toneL = `sil;
                12'd1247: toneL = `sil;
                12'd1248: toneL = `sil;
                12'd1249: toneL = `sil;
                12'd1250: toneL = `sil;
                12'd1251: toneL = `sil;
                12'd1252: toneL = `sil;
                12'd1253: toneL = `sil;
                12'd1254: toneL = `sil;
                12'd1255: toneL = `sil;
                12'd1256: toneL = `sil;
                12'd1257: toneL = `sil;
                12'd1258: toneL = `sil;
                12'd1259: toneL = `sil;
                12'd1260: toneL = `sil;
                12'd1261: toneL = `sil;
                12'd1262: toneL = `sil;
                12'd1263: toneL = `sil;
                12'd1264: toneL = `c;
                12'd1265: toneL = `c;
                12'd1266: toneL = `c;
                12'd1267: toneL = `c;
                12'd1268: toneL = `c;
                12'd1269: toneL = `c;
                12'd1270: toneL = `c;
                12'd1271: toneL = `c;
                12'd1272: toneL = `c;
                12'd1273: toneL = `c;
                12'd1274: toneL = `c;
                12'd1275: toneL = `c;
                12'd1276: toneL = `c;
                12'd1277: toneL = `c;
                12'd1278: toneL = `c;
                12'd1279: toneL = `sil;
                12'd1280: toneL = `c;
                12'd1281: toneL = `c;
                12'd1282: toneL = `c;
                12'd1283: toneL = `c;
                12'd1284: toneL = `c;
                12'd1285: toneL = `c;
                12'd1286: toneL = `c;
                12'd1287: toneL = `c;
                12'd1288: toneL = `c;
                12'd1289: toneL = `c;
                12'd1290: toneL = `c;
                12'd1291: toneL = `c;
                12'd1292: toneL = `c;
                12'd1293: toneL = `c;
                12'd1294: toneL = `c;
                12'd1295: toneL = `c;
                12'd1296: toneL = `lb;
                12'd1297: toneL = `lb;
                12'd1298: toneL = `lb;
                12'd1299: toneL = `lb;
                12'd1300: toneL = `lb;
                12'd1301: toneL = `lb;
                12'd1302: toneL = `lb;
                12'd1303: toneL = `lb;
                12'd1304: toneL = `lb;
                12'd1305: toneL = `lb;
                12'd1306: toneL = `lb;
                12'd1307: toneL = `lb;
                12'd1308: toneL = `lb;
                12'd1309: toneL = `lb;
                12'd1310: toneL = `lb;
                12'd1311: toneL = `lb;
                12'd1312: toneL = `c;
                12'd1313: toneL = `c;
                12'd1314: toneL = `c;
                12'd1315: toneL = `c;
                12'd1316: toneL = `c;
                12'd1317: toneL = `c;
                12'd1318: toneL = `c;
                12'd1319: toneL = `c;
                12'd1320: toneL = `lb;
                12'd1321: toneL = `lb;
                12'd1322: toneL = `lb;
                12'd1323: toneL = `lb;
                12'd1324: toneL = `lb;
                12'd1325: toneL = `lb;
                12'd1326: toneL = `lb;
                12'd1327: toneL = `lb;
                12'd1328: toneL = `la;
                12'd1329: toneL = `la;
                12'd1330: toneL = `la;
                12'd1331: toneL = `la;
                12'd1332: toneL = `la;
                12'd1333: toneL = `la;
                12'd1334: toneL = `la;
                12'd1335: toneL = `la;
                12'd1336: toneL = `lb;
                12'd1337: toneL = `lb;
                12'd1338: toneL = `lb;
                12'd1339: toneL = `lb;
                12'd1340: toneL = `lb;
                12'd1341: toneL = `lb;
                12'd1342: toneL = `lb;
                12'd1343: toneL = `lb;
                12'd1344: toneL = `c;
                12'd1345: toneL = `c;
                12'd1346: toneL = `c;
                12'd1347: toneL = `c;
                12'd1348: toneL = `c;
                12'd1349: toneL = `c;
                12'd1350: toneL = `c;
                12'd1351: toneL = `c;
                12'd1352: toneL = `g;
                12'd1353: toneL = `g;
                12'd1354: toneL = `g;
                12'd1355: toneL = `g;
                12'd1356: toneL = `g;
                12'd1357: toneL = `g;
                12'd1358: toneL = `g;
                12'd1359: toneL = `g;
                12'd1360: toneL = `sil;
                12'd1361: toneL = `sil;
                12'd1362: toneL = `sil;
                12'd1363: toneL = `sil;
                12'd1364: toneL = `sil;
                12'd1365: toneL = `sil;
                12'd1366: toneL = `sil;
                12'd1367: toneL = `sil;
                12'd1368: toneL = `sil;
                12'd1369: toneL = `sil;
                12'd1370: toneL = `sil;
                12'd1371: toneL = `sil;
                12'd1372: toneL = `sil;
                12'd1373: toneL = `sil;
                12'd1374: toneL = `sil;
                12'd1375: toneL = `sil;
                12'd1376: toneL = `b;
                12'd1377: toneL = `b;
                12'd1378: toneL = `b;
                12'd1379: toneL = `b;
                12'd1380: toneL = `b;
                12'd1381: toneL = `b;
                12'd1382: toneL = `b;
                12'd1383: toneL = `b;
                12'd1384: toneL = `b;
                12'd1385: toneL = `b;
                12'd1386: toneL = `b;
                12'd1387: toneL = `b;
                12'd1388: toneL = `b;
                12'd1389: toneL = `b;
                12'd1390: toneL = `b;
                12'd1391: toneL = `b;
                12'd1392: toneL = `b;
                12'd1393: toneL = `b;
                12'd1394: toneL = `b;
                12'd1395: toneL = `b;
                12'd1396: toneL = `b;
                12'd1397: toneL = `b;
                12'd1398: toneL = `b;
                12'd1399: toneL = `b;
                12'd1400: toneL = `b;
                12'd1401: toneL = `b;
                12'd1402: toneL = `b;
                12'd1403: toneL = `b;
                12'd1404: toneL = `b;
                12'd1405: toneL = `b;
                12'd1406: toneL = `b;
                12'd1407: toneL = `b;
                12'd1408: toneL = `f;
                12'd1409: toneL = `f;
                12'd1410: toneL = `f;
                12'd1411: toneL = `f;
                12'd1412: toneL = `f;
                12'd1413: toneL = `f;
                12'd1414: toneL = `f;
                12'd1415: toneL = `f;
                12'd1416: toneL = `lf;
                12'd1417: toneL = `lf;
                12'd1418: toneL = `lf;
                12'd1419: toneL = `lf;
                12'd1420: toneL = `lf;
                12'd1421: toneL = `lf;
                12'd1422: toneL = `lf;
                12'd1423: toneL = `lf;
                12'd1424: toneL = `g;
                12'd1425: toneL = `g;
                12'd1426: toneL = `g;
                12'd1427: toneL = `g;
                12'd1428: toneL = `g;
                12'd1429: toneL = `g;
                12'd1430: toneL = `g;
                12'd1431: toneL = `g;
                12'd1432: toneL = `lg;
                12'd1433: toneL = `lg;
                12'd1434: toneL = `lg;
                12'd1435: toneL = `lg;
                12'd1436: toneL = `lg;
                12'd1437: toneL = `lg;
                12'd1438: toneL = `lg;
                12'd1439: toneL = `lg;
                12'd1440: toneL = `b;
                12'd1441: toneL = `b;
                12'd1442: toneL = `b;
                12'd1443: toneL = `b;
                12'd1444: toneL = `b;
                12'd1445: toneL = `b;
                12'd1446: toneL = `b;
                12'd1447: toneL = `sil;
                12'd1448: toneL = `b;
                12'd1449: toneL = `b;
                12'd1450: toneL = `b;
                12'd1451: toneL = `b;
                12'd1452: toneL = `b;
                12'd1453: toneL = `b;
                12'd1454: toneL = `b;
                12'd1455: toneL = `b;
                12'd1456: toneL = `hc;
                12'd1457: toneL = `hc;
                12'd1458: toneL = `hc;
                12'd1459: toneL = `hc;
                12'd1460: toneL = `hc;
                12'd1461: toneL = `hc;
                12'd1462: toneL = `hc;
                12'd1463: toneL = `hc;
                12'd1464: toneL = `hc;
                12'd1465: toneL = `hc;
                12'd1466: toneL = `hc;
                12'd1467: toneL = `hc;
                12'd1468: toneL = `hc;
                12'd1469: toneL = `hc;
                12'd1470: toneL = `hc;
                12'd1471: toneL = `hc;
                12'd1472: toneL = `c;
                12'd1473: toneL = `c;
                12'd1474: toneL = `d;
                12'd1475: toneL = `d;
                12'd1476: toneL = `e;
                12'd1477: toneL = `e;
                12'd1478: toneL = `f;
                12'd1479: toneL = `f;
                12'd1480: toneL = `g;
                12'd1481: toneL = `g;
                12'd1482: toneL = `a;
                12'd1483: toneL = `a;
                12'd1484: toneL = `b;
                12'd1485: toneL = `b;
                12'd1486: toneL = `hc;
                12'd1487: toneL = `hc;
                12'd1488: toneL = `sil;
                12'd1489: toneL = `sil;
                12'd1490: toneL = `sil;
                12'd1491: toneL = `sil;
                12'd1492: toneL = `sil;
                12'd1493: toneL = `sil;
                12'd1494: toneL = `sil;
                12'd1495: toneL = `sil;
                12'd1496: toneL = `sil;
                12'd1497: toneL = `sil;
                12'd1498: toneL = `sil;
                12'd1499: toneL = `sil;
                12'd1500: toneL = `sil;
                12'd1501: toneL = `sil;
                12'd1502: toneL = `sil;
                12'd1503: toneL = `sil;
                12'd1504: toneL = `lllc;
                12'd1505: toneL = `lllc;
                12'd1506: toneL = `lllc;
                12'd1507: toneL = `lllc;
                12'd1508: toneL = `lllc;
                12'd1509: toneL = `lllc;
                12'd1510: toneL = `lllc;
                12'd1511: toneL = `lllc;
                12'd1512: toneL = `lllc;
                12'd1513: toneL = `lllc;
                12'd1514: toneL = `lllc;
                12'd1515: toneL = `lllc;
                12'd1516: toneL = `lllc;
                12'd1517: toneL = `lllc;
                12'd1518: toneL = `lllc;
                12'd1519: toneL = `lllc;
                12'd1520: toneL = `lllc;
                12'd1521: toneL = `lllc;
                12'd1522: toneL = `lllc;
                12'd1523: toneL = `lllc;
                12'd1524: toneL = `lllc;
                12'd1525: toneL = `lllc;
                12'd1526: toneL = `lllc;
                12'd1527: toneL = `lllc;
                12'd1528: toneL = `lllc;
                12'd1529: toneL = `lllc;
                12'd1530: toneL = `lllc;
                12'd1531: toneL = `lllc;
                12'd1532: toneL = `lllc;
                12'd1533: toneL = `lllc;
                12'd1534: toneL = `lllc;
                12'd1535: toneL = `lllc;
            default:toneL = `sil;
        endcase
    end
    else toneL = `sil;
end
endmodule

module player_control (
	input clk, 
	input reset, 
	input play,
	output reg [11:0] ibeat
);
	parameter LEN = 4095;
    reg [11:0] next_ibeat;

	always @(posedge clk, posedge reset) begin
		if (reset) begin
			ibeat <= 0;
		end else begin
            ibeat <= next_ibeat;
		end
	end

    always @* begin
		next_ibeat = ibeat;
		if(play) begin
			next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : 0;
		end
    end

endmodule

