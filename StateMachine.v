//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Engineer: Mavl
//           Alexey Zhuchkov
//
//
// Create Date:    22/03/2018 
// Last modified:  27/04/2018
//
// Module Name:    StateMachine
// Project Name:   VGAStackCalculator
// Description:    A state machine that produces control signal for synchronizing activities of
//                 other modules
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// ==============================================================================================
//                                             Define Module
// ==============================================================================================
module StateMachine (
    clock,
    reset,
    decoder_ready,
    built_number,
    calc_ready,
    calc_answer,
    decoded_token,
    control_signals
    );
// ==============================================================================================
//                                          Port Declarations
// ==============================================================================================
    input        clock;
    input        reset;         
    input        decoder_ready;     // Decoder received new token
    input        calc_ready;        // ffStackCalculator is ready for new tokens
    input [3:0]  decoded_token;     // Output from Decoder
    input [31:0] built_number;      // Output from NumberBuilder
    input [31:0] calc_answer;       // Output from ffStackCalculator
    output [49:0] control_signals;  // Generated control signals 

    /*
        Control signals mapping:
        [0]     - NumberBuilder strobe
        [1]     - VGABuffer strobe
        [2]     - ffStackCalculator strobe
        [3]     - Unassigned
        [9:4]   - Token size
        [41:10] - Token sender for VGABuffer
        [73:42] - Token sender for ffStackCalculator
        [81:74] - Debug information (current fstate)
        [82]    - Clear NumberBuilder
    */

// ==============================================================================================
//                                  Parameters, Regsiters, and Wires
// ==============================================================================================
    reg [82:0]    control_signals = 83'd0;      
    reg [82:0]    reg_control_signals = 83'd0;  // Temporal storage of control signals
    reg [7:0]     fstate;                       // Current state of state machine
    reg [7:0]     reg_fstate;                   // Next state
    reg [3:0]     saved_token;                  // Save token form loosing between clocks 
    reg           last_token_is_SIGN = 1'b1;    // Last token was sign, only number allowed next
    wire          normalized_sign;              // Normalized sign (ffStackCalculator received 32-bit tokens, but decoder returns only 4 bits)

    wire          is_number = (decoded_token >= 4'h0 && decoded_token < 4'hA) ? 1'b1 : 1'b0;
    wire          is_equal  = (decoded_token == 4'hE) ? 1'b1 : 1'b0;
    
	 // FSM states
    parameter ff_send_clear = 0,    // Send token_CLR to ffStackCalculator
              ff_wait_clear = 1,    // Wait until ffStackCalculator is ready for receiving tokens
              wait_token    = 2,    // Wait for new token
              build         = 3,    // Send digit to number builder
              send_number   = 4,    // Fetch number from number builder, send it to ffStackCalculator; send new token (sign) to VGABuffer
              sender_wait_1 = 5,    // Wait until ffStackCalculator is ready for receiving tokens
              ff_send_sign  = 6,    // Send token (sign) to ffStackCalculator
              sender_wait_2 = 7,    // Wait until ffStackCalculator is ready for receiving tokens OR finishes calculation
              send_answer   = 8,    // Send answer to VGABuffer
              wait_reset    = 9;    // Wait for reset signal
     
// ==============================================================================================
//                                              Implementation
// ==============================================================================================  
    
    sign_normalizer sign_normalizer(
        .sign(decoded_token),
        .token(normalized_sign)
    );
    
    // Move to next state    
    always @(posedge clock)
    begin
        if (clock) begin
            fstate <= reg_fstate;
            control_signals <= reg_control_signals;
        end
    end

    // Selecting new state, generating control signals
    always @(*)
    begin
        if (reset) begin
                reg_fstate <= ff_send_clear;                   
                reg_control_signals <= 83'd0;
                last_token_is_SIGN = 1'b1;               
        end
        else begin
            reg_control_signals <= 83'd0;
            reg_control_signals[81:74] <= fstate;
            case (fstate)
                    ff_send_clear: begin                // Send token_CLR to ffStackCalculator
                        reg_control_signals [73:42] <= 32'h8000000F;   // Send clear signal to ffStackCalculator
                        reg_control_signals [3:0] <= 4'b0100;          // Enable strobe for ffStackCalculator
                        reg_fstate <= ff_wait_clear;
                     end
                    ff_wait_clear: reg_fstate <= calc_ready? wait_token : ff_wait_clear;
                    wait_token: begin
                        if ((decoder_ready && is_number))
                            reg_fstate <= build;
                        else if (((decoder_ready && (!is_number)) && (!last_token_is_SIGN)))
                                reg_fstate <= send_number;
                        else
                            reg_fstate <= wait_token;
                    end
                    build: begin                        // Send new digit to NB and VGA buffer
                        reg_fstate <= wait_token;
                        reg_control_signals [9:4] <= 6'd4;             // Token size
                        reg_control_signals [41:10] <= decoded_token;  // send digit to VGABuffer
                        reg_control_signals [3:0] <= 4'b0011;          // Enable strobe for VGABuffer & NumberBuilder
                        last_token_is_SIGN = 1'b0;                     // Next time only digit is allowed
                    end
                    send_number: begin                // Send sign to VGA buffer and number from NB to ffStackCalculator
                        reg_fstate <= sender_wait_1;
                        reg_control_signals [9:4] <= 6'd4;              // Token size
                        reg_control_signals [41:10] <= decoded_token;   // send sign to VGABuffer
                        reg_control_signals [73:42] <= built_number;    // send bult number from NumberBuilder to ffStackCalculator
                        reg_control_signals [3:0] <= 4'b0110;           // Enable strobe for VGABuffer & ffStackCalculator
                        saved_token <= decoded_token;                   // Save sign for next clock
                        last_token_is_SIGN = 1'b1;                      // Next time only digit is allowed
                    end
                    sender_wait_1: begin            // Wait until ffStackCalculator receives new token
                        if ((calc_ready))
                            reg_fstate <= ff_send_sign;
                        else
                        reg_fstate <= sender_wait_1;
                    end
                    ff_send_sign: begin                // Send sign to ffStackCalculator
                        reg_fstate <= sender_wait_2;                          
                        reg_control_signals [82] <= 1'b1;               // Clear Number Builder
                        reg_control_signals [73:42] <= normalized_sign; // Send saved sign to ffStackCalculator
                        reg_control_signals [3:0]  <= 4'b0100;          // Enable strobe for ffStackCalculator
                        last_token_is_SIGN = 1'b1;                      // Next time only digit is allowed
                    end
                    sender_wait_2: begin            // Wait until ffStackCalculator received new sign                        
                        if ((calc_ready & is_equal))
                            reg_fstate <= send_answer;
                        else if ((calc_ready & ~is_equal))
                            reg_fstate <= wait_token;
                        else
                            reg_fstate <= sender_wait_2;
                        last_token_is_SIGN = 1'b1;                      // Next time only digit is allowed
                    end
                    send_answer: begin              // Send answer to VGABuffer
                        reg_fstate <= wait_reset;
                        reg_control_signals [9:4] <= 6'd32;            // Token size
                        reg_control_signals [41:10] <= calc_answer;    // Send calculated answer to VGABuffer
                        reg_control_signals [3:0] <= 4'b0010;          // Enable strobe for VGABuffer
                    end
                    wait_reset: begin
                        reg_fstate <= wait_reset;
                        reg_control_signals [82] <= 1'b1;              // NB clear                          
                        last_token_is_SIGN = 1'b1;                     // Next time only digit is allowed
                    end
            endcase
        end
    end
endmodule

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Engineer: Mavl Pond
//
//
// Create Date:    25/04/2018 
// Last modified:  25/04/2018
//
// Module Name:    sign_normalizer
// Project Name:   VGAStackCalculator
// Description:    Convert token to sign
//                 hA -> h8000000A
//
// Revision History: 
//                     Revision 0.01 - File Created (Mavl Pond)
//////////////////////////////////////////////////////////////////////////////////////////////////////////
module sign_normalizer(
    input [3:0]   sign,
    output [31:0] token
);

assign token = 32'h80000000 | sign;

endmodule