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
    clock_divider #(.n(22)) clock_22(.clk(clk), .clk_div(clkDiv22));
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
        .volume(3),
        .play(1),
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
        .reset(rst),
        .play(1),
        .ibeat(ibeatNum)
    );

endmodule

