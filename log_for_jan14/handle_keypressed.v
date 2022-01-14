
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
