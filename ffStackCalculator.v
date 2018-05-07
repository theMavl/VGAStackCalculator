//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Engineer: mcavoya (https://github.com/mcavoya)
//           Mavl
//           Alexey Zhuchkov
//
//
// Create Date:    ? 
// Last modified:  27/04/2018
//
// Module Name:    ffStackCalculator
// Project Name:   VGAStackCalculator
// Description:    Four Function Calculator
//                 strobe is used to enter a new token
//                 tokens are BCD 0 through 9, plus
//                 A : + (addition)
//                 B : - (subtraction)
//                 C : * (multiplication)
//                 D : / (division)
//                 E : = (equals)
//                 F : clear
//                 MUST first enter clear to initialize each calculation
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// ==============================================================================================
//                                             Define Module
// ==============================================================================================
module ffStackCalculator (
    input             clk,           // clock
    input             strobe,        // active-high synchronous write enable
    input [31:0]      token,         // infix expression input
    output            ready,         // active-high ready to accept next token
    output reg [31:0] answer,        // intermediate and final answers
    output reg [5:0]  stages,        // Debug information - shows which stages has been visited overall
    output [5:0]      sh_stages      // Debug information - shows which stages has been visited overall by shuShuntingYardnting_yard            
);
// ==============================================================================================
//                                       Parameters, Regsiters, and Wires
// ==============================================================================================   
    parameter token_ADD = 32'h8000000A;
    parameter token_SUB = 32'h8000000B;
    parameter token_MUL = 32'h8000000C;
    parameter token_DIV = 32'h8000000D;
    parameter token_EQU = 32'h8000000E;
    parameter token_CLR = 32'h8000000F;

    // State machine states
    parameter fsm_IDLE        = 3'd0; // waiting for token
    parameter fsm_WAIT        = 3'd1; // waiting for shunting yard
    parameter fsm_CALC        = 3'd2; // calculate answer
    parameter fsm_PUSH_NUMBER = 3'd3; // push number onto stack
    parameter fsm_EXECUTE     = 3'd4; // do arithmetic function

    // convert infix to RPN
    wire        rd_en;            // active-high synchronous read enable for shunting yard output_queue
    wire        shunt_yard_ready; // active-high when shunting yard is ready to accept next token
    wire [31:0] output_queue;     // shunting yard postfix expression output
    
    ShuntingYard shunt_yard(
        .clk(clk),
        .rd_en(rd_en),
        .wr_en(strobe),
        .token(token),
        .ready(shunt_yard_ready),
        .output_queue(output_queue),
        .stages(sh_stages)
    );

    // helper signals
    wire clear = strobe & (token == token_CLR);
    wire is_equal = (token==token_EQU);
    wire is_number = (output_queue > token_CLR) || (output_queue < token_ADD);
    wire is_finished = (output_queue == token_EQU);

    // ff_calc FSM
    reg [2:0] state = fsm_IDLE;
    reg [2:0] next_state = fsm_IDLE;
    reg [4:0] stack_pointer = 5'd0;
    reg [31:0] accumulator;
            
// ==============================================================================================
//                                                 Implementation
// ==============================================================================================

    always @(posedge clk) begin
        if (clear) state <= fsm_IDLE;
        else state <= next_state;
    end
    
    always @(posedge clk) begin
        if (clear) stages <= 6'd0;
        else stages[state] <= 1'b1;
    end
    
    // next state logic
    always @* begin
      case (state)
        // idle, wait for a token
        fsm_IDLE  : if (strobe) next_state = fsm_WAIT;
                    else next_state = fsm_IDLE;

        // wait for shunting yard
        fsm_WAIT : if (shunt_yard_ready) next_state = is_equal ? fsm_CALC : fsm_IDLE;
                   else next_state = fsm_WAIT;

        // do calculation
        fsm_CALC : if (is_number) next_state = fsm_PUSH_NUMBER;
                   else next_state = is_finished ? fsm_IDLE : fsm_EXECUTE;

        // push number onto stack
        fsm_PUSH_NUMBER : next_state = fsm_CALC;

        // do operation
        fsm_EXECUTE : next_state = fsm_CALC;

        default: next_state = fsm_IDLE;
      endcase
    end

    // FSM outputs
    assign ready = (state == fsm_IDLE);
    assign rd_en = (state == fsm_PUSH_NUMBER) | (state == fsm_EXECUTE);

    // stack
    reg [31:0] stack [0:31];
        
    always @(posedge clk) begin
        if (clear) begin
            stack_pointer <= 5'd0;
            answer <= 32'hFFFFFFFF;
        end
        else if (fsm_PUSH_NUMBER == state) 
        begin
             stack[stack_pointer] <= output_queue;
             stack_pointer <= stack_pointer + 1'd1;
        end
        else if (fsm_EXECUTE==state)
        begin    
            stack[stack_pointer - 2] <= accumulator; 
            stack_pointer <= stack_pointer - 1'd1; 
            answer <= accumulator;
        end
    end

    // ALU    
    always @* begin
        case (output_queue)
            token_ADD : accumulator = stack[stack_pointer-2] + stack[stack_pointer-1];
            token_SUB : accumulator = stack[stack_pointer-2] - stack[stack_pointer-1];
            token_MUL : accumulator = stack[stack_pointer-2] - stack[stack_pointer-1];
            token_DIV : accumulator = stack[stack_pointer-2] - stack[stack_pointer-1];
            default : accumulator = 4'd0;
        endcase
    end
endmodule