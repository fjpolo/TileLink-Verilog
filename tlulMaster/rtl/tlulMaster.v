// =============================================================================
// File          : tlulMaster.v
// Author        : @fjpolo
// email         : fjpolo@gmail.com
// Description   : Basic TileLink UL master (Single Write Transaction)
// License       : MIT License
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

`default_nettype none
`timescale 1ns/1ps

// `define TL_FULL_INIT // Commented saves LEs

module tlulMaster #(
    parameter TL_DATA_WIDTH = 64,
    parameter TL_ADDR_WIDTH = 32
)(
    // System
    input  logic i_clk,
    input  logic i_reset,

    // Channel A (Request to Slave)
    output logic o_a_valid,
    input  logic i_a_ready,
    output logic [2:0] o_a_opcode,
    output logic [3:0] o_a_size,
    output logic [7:0] o_a_source,
    output logic [(TL_ADDR_WIDTH-1):0] o_a_address,
    output logic [(TL_DATA_WIDTH-1):0] o_a_data,

    // Channel D (Response from Slave)
    input  logic i_d_valid,
    output logic o_d_ready,
    input  logic [2:0] i_d_opcode,
    input  logic [1:0] i_d_denied
);

    // --- Local Parameters for Transaction ---
    localparam TL_OP_PUT_FULL_DATA = 3'b001;
    localparam TL_OP_ACCESS_ACK    = 3'b010;
    localparam TARGET_ADDRESS      = 32'h0;
    localparam WRITE_DATA          = 64'hC3; // Data to write (8-bit value C3h in the lower byte)
    localparam WRITE_SIZE          = 4'b011; // 8 bytes (64-bit)
    localparam SOURCE_ID           = 8'h0A;

    // --- State Machine ---
    typedef enum {
        RESET_ST,       // Initial state after reset
        REQUEST_ST,     // Sending A-Channel request
        WAIT_ACK_ST,    // Waiting for D-Channel response
        DONE_ST         // Transaction complete
    } master_state_t;

    // Registers for current state and output handshakes (Sequential Logic)
    master_state_t r_state; 
    logic r_a_valid; 
    logic r_d_ready; 
    
    // Combinational signals for next state and next output handshakes
    master_state_t r_next_state;
    logic r_a_valid_next;
    logic r_d_ready_next;

    // Assign outputs from the registered values
    assign o_a_valid = r_a_valid;
    assign o_d_ready = r_d_ready;
    
    // Constant output signals for the A-channel payload (driven combinatorially)
    assign o_a_opcode  = TL_OP_PUT_FULL_DATA;
    assign o_a_size    = WRITE_SIZE;
    assign o_a_source  = SOURCE_ID;
    assign o_a_address = TARGET_ADDRESS;
    assign o_a_data    = WRITE_DATA;


    // --- Combinational Logic: Next State and Next Output Handshakes ---
    always @(*) begin
        // Default assignments (no change or idle state defaults)
        r_next_state     = r_state;
        r_a_valid_next   = r_a_valid; // Default to holding current value
        r_d_ready_next   = r_d_ready; // Default to holding current value
        
        case (r_state)
            RESET_ST: begin
                r_next_state = REQUEST_ST; // Start immediately after reset
                r_a_valid_next = 1'b0;
                r_d_ready_next = 1'b0;
            end

            REQUEST_ST: begin
                r_a_valid_next = 1'b1; // Assert request
                // Handshake condition
                if (o_a_valid && i_a_ready) begin
                    r_a_valid_next = 1'b0; // Deassert valid one cycle later
                    r_next_state = WAIT_ACK_ST;
                end
            end

            WAIT_ACK_ST: begin
                r_d_ready_next = 1'b1; // Assert ready to receive the response
                
                // Handshake condition
                if (i_d_valid && o_d_ready) begin
                    r_d_ready_next = 1'b0; // Deassert ready after acceptance
                    
                    // The actual transaction status check remains, but without simulation tasks.
                    // Check for successful Write Acknowledge (TL_OP_ACCESS_ACK and not denied)
                    if (i_d_opcode == TL_OP_ACCESS_ACK && i_d_denied == 2'b0) begin
                        // Transaction successful
                    end else begin
                        // Transaction failed (In a real design, this would flag an error state)
                    end
                    r_next_state = DONE_ST;
                end
            end

            DONE_ST: begin
                // Master is idle
                r_a_valid_next = 1'b0; 
                r_d_ready_next = 1'b0; 
            end
        endcase
    end

    // --- Sequential Logic: Register Updates ---
    always @(posedge i_clk) begin
        if (i_reset) begin
            r_state   <= RESET_ST;
            r_a_valid <= 1'b0;
            r_d_ready <= 1'b0;
        end else begin
            r_state   <= r_next_state;
            
            // Only update registered handshake signals from their _next calculated values
            r_a_valid <= r_a_valid_next;
            r_d_ready <= r_d_ready_next;
        end
    end

endmodule
