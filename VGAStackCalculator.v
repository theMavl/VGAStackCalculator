//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Engineer: Mavl
//           Alexey Zhuchkov
//           Vyacheslav Yastrebov
//
//
// Create Date:    22/03/2018 
// Last modified:  27/04/2018
//
// Module Name:    VGAStackCalculator
// Project Name:   VGAStackCalculator
// Description:    Top module of the project. Launches all other modules 
//                 and provides connection between them
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// ==============================================================================================
//                                             Define Module
// ==============================================================================================
module VGAStackCalculator(
    input         MAX10_CLK1_50,
    input [9:0]   SW,

    inout [7:0]   JA,
    input [1:0]   KEY,

    output [31:0] answer,

    output [7:0]  HEX0,
    output [7:0]  HEX1,
    output [7:0]  HEX2,
    output [7:0]  HEX3,
    output [7:0]  HEX4,
    output [7:0]  HEX5,
    output [9:0]  LEDR,
    output        VGA_HS, 
    output        VGA_VS, 
    output [3:0]  VGA_R, 
    output [3:0]  VGA_G, 
    output [3:0]  VGA_B
);
// ==============================================================================================
//                                       Parameters, Regsiters, and Wires
// ==============================================================================================
    // Inputs
    wire clk   = MAX10_CLK1_50;
    wire reset = !KEY[0];

    // Outputs
    wire [384:0] vgabuff;
    
    // FSM inputs
    wire [31:0] built_number;
    wire [31:0] reg_answer;
    wire        decoder_ready;     // Decoder has decoded new token
    wire [3:0]  decoded_token;     // Token from decoder    
    wire        calc_ready;

    // FSM Output
    wire [82:0] control_signals;
    
    // Debug
    wire        is_number = (decoded_token >= 4'h0 && decoded_token < 4'hA) ? 1'b1 : 1'b0;
    wire        is_equal  = (decoded_token == 4'hE) ? 1'b1 : 1'b0;
    wire [7:0]  state     = control_signals[81:74];
    wire [31:0] ff_stages;
    wire [31:0] sh_stages;
    wire [4:0]  sh_s_p;

// ==============================================================================================
//                                                 Implementation
// ==============================================================================================

// ==============================================================================================
//                                          Keyboard Decoder
// ==============================================================================================
    Decoder C0(
            .clk(clk),
            .Row(JA[7:4]),
            .Col(JA[3:0]),
            .DecodeOut(decoded_token),
            .DecoderState(decoder_ready)
    );

    // ==============================================================================================
    //                                          Number builder
    //                                  Makes number from sequence of digits
    // ==============================================================================================
    NumberBuilder builder(
            .clk(clk),
            .strobe(control_signals[0]),
            .clear(control_signals [82]),
            .token(decoded_token),
            .number(built_number)
    );

    // ==============================================================================================
    //                                          VGA Buffer
    //            						A storage for VGA output
    // ==============================================================================================
    VGABuffer buffer(
            .clk(clk),
            .strobe(control_signals[1]),
            .clear(reset),
            .token_size(control_signals[9:4]),
            .Token(control_signals[41:10]),
            .answ_flag(flag),
            .answ_input(reg_answer),
            .buffer(vgabuff)
    );

    // ==============================================================================================
    //                                      Four-Function Calculator
    //            						
    // ==============================================================================================
    ffStackCalculator ffStackCalculator(
        .clk(clk),
        .strobe(control_signals[2]),
        .token(control_signals[73:42]),
        .ready(calc_ready),
        .answer(reg_answer),    
        .stages(ff_stages),
        .sh_stages(sh_stages)
    );

    // ==============================================================================================
    //              					VGAStackCalculator state machine
    //            
    // ==============================================================================================
    StateMachine StateMachine(
        .clock(clk),
        .reset(reset),
        .decoder_ready(decoder_ready),
        .calc_ready(calc_ready),
        .decoded_token(decoded_token),
        .built_number(built_number),
        .calc_answer(reg_answer),
        .control_signals(control_signals)
    );

    // ==============================================================================================

    reg flag; 
    initial flag <= 1;
    reg a;
    initial a <= 0;
    
    always@(posedge clk)
    begin
        if(!a)
            a <= 1;
        else 
            flag = 0;   
    end
    
    VGAController controller(.numbers(vgabuff),
                             .clk(clk_25),
                             .vga_h_sync(VGA_HS), 
                             .vga_v_sync(VGA_VS), 
                             .vga_R(VGA_R), 
                             .vga_G(VGA_G),
                             .vga_B(VGA_B));

    // ==============================================================================================    
    //             Output representation
    // ==============================================================================================

    assign LEDR[5:0]   = ff_stages;// sh_stages;    
    assign LEDR[7]     = (calc_ready);
    assign LEDR[8]     = (is_equal);    
    assign LEDR[9]     = (is_number);

    wire [ 31:0 ] h7segment = SW[0] ? vgabuff[31:0] : (SW[1] ? built_number : (SW[2] ? reg_answer : (SW[3] ? sh_s_p : state))); //32'h00FFFFFF;

    assign HEX0 [7] = 1'b1;
    assign HEX1 [7] = 1'b1; 
    assign HEX2 [7] = 1'b1;
    assign HEX3 [7] = 1'b1;
    assign HEX4 [7] = 1'b1;
    assign HEX5 [7] = 1'b1;

    sm_hex_display digit_5 ( h7segment [23:20] , HEX5 [6:0] );
    sm_hex_display digit_4 ( h7segment [19:16] , HEX4 [6:0] );
    sm_hex_display digit_3 ( h7segment [15:12] , HEX3 [6:0] );
    sm_hex_display digit_2 ( h7segment [11: 8] , HEX2 [6:0] );
    sm_hex_display digit_1 ( h7segment [ 7: 4] , HEX1 [6:0] );
    sm_hex_display digit_0 ( h7segment [ 3: 0] , HEX0 [6:0] );

endmodule