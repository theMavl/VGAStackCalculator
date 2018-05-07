//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Engineer: Mavl
//
//
// Create Date:    22/03/2018  
// Last modified:  27/04/2018
//
// Module Name:    NumberBuilder
// Project Name:   VGAStackCalculator
// Description:    Builds a number from sequence of digits
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////

// ==============================================================================================
//                                             Define Module
// ==============================================================================================
module NumberBuilder(
    input             clk,
    input [3:0]       token,
    input             strobe,
    input             clear,
    output reg [31:0] number
);

// ==============================================================================================
//                                                 Implementation
// ==============================================================================================
always@(posedge clk or posedge clear) begin
    if (clear)
        number <= 0;        
    else if (strobe) begin                            // If receiver enabled
        number = (number * 4'b1010) + token;          // build a number
    end
end
endmodule