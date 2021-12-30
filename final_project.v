module final_project(
    input clk,
    input rst,
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output hsync,
    output vsync
);
reg [11:0] pixel_out;
wire [11:0] pixel;
wire [11:0] pixel2;

wire [9:0] h_cnt; //640
wire [9:0] v_cnt;  //480
wire [11:0] data;
wire valid;
reg [16:0] pixel_addr;
reg [12:0] pixel_addr2; //64*64
wire clk_25MHz;

reg [9:0]p1_x,p1_y;


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
      .addra(pixel_addr),
      .dina(data[11:0]),
      .douta(pixel)
);
blk_mem_gen_1 blk_mem_gen_1_inst( //p1
      .clka(clk_25MHz),
      .wea(0),
      .addra(pixel_addr2),
      .dina(data[11:0]),
      .douta(pixel2)
);

always@(*)begin
    p1_x=70;
    p1_y=180;
end



always @(*) begin
    pixel_addr = ((h_cnt>>1)+320*(v_cnt>>1))% 76800;
end
always @(*) begin
    if(pixel_out==pixel2)begin
        pixel_addr2=2080;
        if(h_cnt>>1 >= p1_x) pixel_addr2= pixel_addr2+ ((h_cnt>>1) -p1_x);
        else pixel_addr2= pixel_addr2- (p1_x - (h_cnt>>1) );
        if(v_cnt>>1 >= p1_y) pixel_addr2= pixel_addr2+ ((v_cnt>>1) -p1_y)*64;
        else pixel_addr2= pixel_addr2- (p1_y - (v_cnt>>1) )*64;
    end else begin
        pixel_addr2=0;
    end
end

reg [30:0]dist_sq;
always @(*) begin
    dist_sq=0;
    if(h_cnt>>1 >= p1_x) dist_sq= dist_sq+ ((h_cnt>>1) -p1_x)*((h_cnt>>1) -p1_x);
    else dist_sq= dist_sq+ (p1_x - (h_cnt>>1) )*(p1_x - (h_cnt>>1));
    if(v_cnt>>1 >= p1_y) dist_sq= dist_sq+ ((v_cnt>>1) -p1_y)*((v_cnt>>1) -p1_y);
    else dist_sq= dist_sq+ (p1_y - (v_cnt>>1) )*(p1_y - (v_cnt>>1));

    if(dist_sq<=900) pixel_out=pixel2;
    else pixel_out=pixel;
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
