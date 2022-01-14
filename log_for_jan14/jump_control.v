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
                if (p1_y>=180)begin
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
                if (p2_y>=180)begin
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
