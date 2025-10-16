// =============================================================================
// File        : tlulSlaveLeds.v
// Author      : @fjpolo
// email       : fjpolo@gmail.com
// Description : Basic TileLink UL slave: 8xLED controller with Put and Get
// License     : MIT License
//
// Copyright (c) 2025 | @fjpolo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// =============================================================================

// =============================================================================
// TL-UL SLAVE COMPLETENESS REVIEW
// =============================================================================
//
// This module is a BASIC, MINIMAL TL-UL slave, not a full implementation.
//
// | Aspect | Current Module Status | TL-UL Specification Requirement |
// | :---: | :--- | :--- |
// | Transaction Types | Supports Get (Read) and PutFullData (Write). | Must support PutFullData, PutPartialData, ArithmeticData, LogicalData, Get, Intent, AcquireBlock, and AcquireData. |
// | Address Space | Handles only a single address (32'h0). | Should support a defined, larger address range. |
// | Masking | Ignores i_a_mask for writes (only uses i_a_data[7:0]). | PutPartialData requires correct use of i_a_mask for partial updates. |
// | Ready Signals | Always asserts o_a_ready = 1'b1. | Valid for simple, single-cycle slaves, but a full slave may need to deassert o_a_ready to back-pressure the master. |
// | D Channel Echo | o_d_param, o_d_size, o_d_source are correct echoes. | The module correctly echoes necessary D-channel fields. |
// | Denial/Error | Supports unsupported address/opcode via HintAck and o_d_denied. | Handled adequately for a basic register. |
//
// =============================================================================
`default_nettype none
`timescale 1ps/1ps

// TODO: Uncomment to initialize all registers
// `define TL_FULL_INIT // Commented saves 49LEs

module tlulSlaveLeds #(
    parameter TL_DATA_WIDTH = 64,
    parameter TL_ADDR_WIDTH = 32
)(
    // System
    input  logic        i_clk,
    input  logic        i_reset,
    // Channel A (Request)
    input  logic        i_a_valid,
    output logic        o_a_ready,
    input  logic [2:0]  i_a_opcode,
    // input  logic [2:0]  i_a_param,
    input  logic [3:0]  i_a_size,
    input  logic [7:0]  i_a_source,
    input  logic [(TL_ADDR_WIDTH-1):0] i_a_address,
    input  logic [(TL_DATA_WIDTH-1):0] i_a_data,
    // input  logic [7:0]  i_a_mask,
    // Channel D (Response)
    output logic        o_d_valid,
    input  logic        i_d_ready,
    output logic [2:0]  o_d_opcode,
    output logic [2:0]  o_d_param,
    output logic [3:0]  o_d_size,
    output logic [7:0]  o_d_source,
    output logic [(TL_DATA_WIDTH-1):0] o_d_data,
    output logic [1:0]  o_d_denied,
    // LEDs output
    output logic [7:0]  o_leds
);
    // Internal register for the LEDs
    logic [7:0] r_leds;
    localparam LEDS_REG_ADDR = 32'h0;
    assign o_leds = r_leds; // Output the LED state


    // Response valid flag logic
    logic d_valid_next;
    assign o_d_valid = d_valid_next; 

    // The slave is always ready to accept a request (simplification for TL-UL register)
    assign o_a_ready = 1'b1;

    // Register logic for LEDs and D Channel Outputs
    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            // 1. Slave MUST drive o_d_valid LOW during i_reset
            d_valid_next <= 1'b0;   // Important to initialize 
            
            // 2. Clear internal state
            r_leds <= '0;       // Important to initialize
`ifdef TL_FULL_INIT
            o_d_opcode <= 3'b0; // Initialization could be ignored because o_d_valid initializes as 0
            o_d_param <= 3'b0;  // Initialization could be ignored because o_d_valid initializes as 0
            o_d_size <= 4'b0;   // Initialization could be ignored because o_d_valid initializes as 0
            o_d_source <= 8'b0; // Initialization could be ignored because o_d_valid initializes as 0
            o_d_data <= 64'b0;  // Initialization could be ignored because o_d_valid initializes as 0
            o_d_denied <= 2'b0; // Initialization could be ignored because o_d_valid initializes as 0
`endif // TL_FULL_INIT
        end else begin
            // The slave is now out of i_reset. o_d_valid can be driven HIGH from the first rising edge.
            // Valid request
            if ((i_a_valid)&&(o_a_ready)) begin // Incoming request
                if (i_a_address == LEDS_REG_ADDR) begin // Supported address
                    case (i_a_opcode)
                        3'b000: begin // Get (Read)
                            o_d_opcode <= 3'b100; // AccessAckData
                            o_d_data <= {{(TL_DATA_WIDTH - 8){1'b0}}, r_leds}; 
                            d_valid_next <= 'b1;
                        end
                        3'b001: begin // PutFullData (Write)
                            r_leds <= i_a_data[7:0]; // Write the lower 8 bits
                            o_d_opcode <= 'b010; // AccessAck
                            o_d_data <= 'b0;
                            d_valid_next <= 'b1;
                        end
                        default: begin // Unsupported opcode
                            o_d_opcode <= 'b110; // HintAck (or error)
                            o_d_data <= 'b0;
                            d_valid_next <= 'b1;
                            o_d_denied <= 'b1;
                        end
                    endcase
                end else begin // Unsupported address
                    o_d_opcode <= 'b110; // HintAck
                    o_d_data <= 'b0;
                    d_valid_next <= 'b1;
                    o_d_denied <= 'b1;
                end

                // Common D-channel assignments
                o_d_param <= 'b0;
                o_d_size <= i_a_size;
                o_d_source <= i_a_source;
                // Note: o_d_denied is set in the case statement above if needed, otherwise it retains i_reset/previous value.
            end else begin
                d_valid_next <= 'b0; // No valid A-channel request this cycle
            end
        end
    end

endmodule
