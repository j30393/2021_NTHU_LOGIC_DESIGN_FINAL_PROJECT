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