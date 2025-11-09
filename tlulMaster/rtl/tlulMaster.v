// =============================================================================
// File          : tlulMaster.v
// Author        : @fjpolo
// email         : fjpolo@gmail.com
// Description   : Generic TileLink UL master with simple handshake interface
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

// TODO: Uncomment to initialize all registers
// `define TL_FULL_INIT // Commented saves LEs

module tlulMaster #(
    parameter TL_DATA_WIDTH = 64,
    parameter TL_ADDR_WIDTH = 32
)(
    // System
    input  logic i_clk,
    input  logic i_reset,

    // Generic Master Interface (Handshake Protocol) 
    input  logic i_req,                             // Request signal from external module
    output logic o_ack,                             // Acknowledge signal (transaction complete)
    output logic o_busy,                            // Master is processing a transaction
    input  logic i_write,                           // 1: Write (PutFullData), 0: Read (Get)
    input  logic [(TL_ADDR_WIDTH-1):0] i_addr,      // Transaction address
    input  logic [(TL_DATA_WIDTH-1):0] i_wdata,     // Write data (valid if i_write=1)
    output logic [(TL_DATA_WIDTH-1):0] o_rdata,     // Read data (valid if o_ack=1 and i_write=0)

    // TileLink Channel A (Request to Slave) 
    output logic o_a_valid,
    input  logic i_a_ready,
    output logic [2:0] o_a_opcode,
    output logic [3:0] o_a_size,
    output logic [7:0] o_a_source,
    output logic [(TL_ADDR_WIDTH-1):0] o_a_address,
    output logic [(TL_DATA_WIDTH-1):0] o_a_data,

    // TileLink Channel D (Response from Slave) 
    input  logic i_d_valid,
    output logic o_d_ready,
    input  logic [2:0] i_d_opcode,
    input  logic [1:0] i_d_denied,
    // Removed i_d_param (unused)
    input  logic [(TL_DATA_WIDTH-1):0] i_d_data 
);

    // Local Parameters for TileLink Operations 
    localparam TL_OP_PUT_FULL_DATA = 3'b001;    // Write Request
    localparam TL_OP_GET           = 3'b100;    // Read Request
    localparam TL_OP_ACCESS_ACK    = 3'b010;    // Write Acknowledge
    localparam TL_OP_ACCESS_ACK_DATA = 3'b011;  // Read Acknowledge with Data
    
    localparam DEFAULT_SIZE        = 4'b011;    // 8 bytes (64-bit)
    localparam SOURCE_ID           = 8'h0A;

    // State Machine 
    typedef enum {
        RESET_ST,       // Initial state after reset
        IDLE_ST,        // Waiting for i_req
        REQUEST_ST,     // Sending A-Channel request
        WAIT_ACK_ST,    // Waiting for D-Channel response
        ACK_ST          // Asserting o_ack for one cycle
    } master_state_t;

    // Internal Registers (Sequential Logic) 
    master_state_t r_state; 
    logic r_a_valid; 
    logic r_d_ready; 
    logic r_ack;
    
    // Registers to hold the captured transaction details
    logic r_busy;
    logic r_write;                                  // Now synchronous, only assigned with <=
    logic [(TL_ADDR_WIDTH-1):0] r_addr;             // Now synchronous, only assigned with <=
    logic [(TL_DATA_WIDTH-1):0] r_wdata;            // Now synchronous, only assigned with <=
    logic [(TL_DATA_WIDTH-1):0] r_rdata_captured;   // Captured read data

    // Combinational Signals (Next State/Output Logic) 
    master_state_t r_next_state;
    logic r_a_valid_next;
    logic r_d_ready_next;
    logic r_ack_next;
    logic r_busy_next;
    logic [(TL_DATA_WIDTH-1):0] r_rdata_captured_next;

    // Output Assignments 
    assign o_a_valid = r_a_valid;
    assign o_d_ready = r_d_ready;
    assign o_ack     = r_ack;
    assign o_busy    = r_busy;
    assign o_rdata   = r_rdata_captured;

    // TL-UL Channel A Payload: driven by the captured request details
    assign o_a_opcode  = r_write ? TL_OP_PUT_FULL_DATA : TL_OP_GET;
    assign o_a_size    = DEFAULT_SIZE;
    assign o_a_source  = SOURCE_ID;
    assign o_a_address = r_addr;
    assign o_a_data    = r_wdata; // Only relevant for writes, but driven constantly


    // Combinational Logic: FSM and Next Outputs 
    always @(*) begin
        // Default assignments (hold current state/value)
        r_next_state          = r_state;
        r_a_valid_next        = r_a_valid; 
        r_d_ready_next        = r_d_ready;
        r_ack_next            = 1'b0;
        r_busy_next           = r_busy;
        r_rdata_captured_next = r_rdata_captured;
        
        case (r_state)
            RESET_ST: begin
                r_next_state = IDLE_ST;
                r_busy_next  = 1'b0;
            end

            IDLE_ST: begin
                if (i_req && !r_busy) begin // Check for new request only if not busy
                    // Only update FSM and busy signal here. Data capture moved to sequential block.
                    r_next_state = REQUEST_ST;
                    r_busy_next  = 1'b1;
                end
            end

            REQUEST_ST: begin
                r_a_valid_next = 1'b1; // Assert request to the slave
                
                // A-Channel handshake completes
                if (o_a_valid && i_a_ready) begin
                    r_a_valid_next = 1'b0; // Deassert valid
                    r_next_state   = WAIT_ACK_ST;
                end
            end

            WAIT_ACK_ST: begin
                r_d_ready_next = 1'b1; // Assert ready to receive the response
                
                // D-Channel handshake completes
                if (i_d_valid && o_d_ready) begin
                    r_d_ready_next = 1'b0; // Deassert ready
                    
                    // Check for successful Write Ack (AccessAck) or Read Ack (AccessAckData)
                    if (i_d_denied == 2'b0) begin
                        if (r_write && (i_d_opcode == TL_OP_ACCESS_ACK)) begin
                            // Successful Write
                        end else if (!r_write && (i_d_opcode == TL_OP_ACCESS_ACK_DATA)) begin
                            // Successful Read: Capture the data
                            r_rdata_captured_next = i_d_data;
                        end else begin
                            // Error: Unexpected opcode
                        end
                    end else begin
                        // Error: Transaction denied
                    end
                    
                    r_next_state = ACK_ST;
                end
            end

            ACK_ST: begin
                r_ack_next  = 1'b1; // Assert acknowledgment to the user for one cycle
                r_busy_next = 1'b0; // Clear busy signal
                r_next_state = IDLE_ST; // Return to waiting for new requests
            end
        endcase
    end

    // Sequential Logic: Register Updates 
    always @(posedge i_clk) begin
        if (i_reset) begin
            r_state           <= RESET_ST;
            r_a_valid         <= 1'b0;
            r_d_ready         <= 1'b0;
            r_ack             <= 1'b0;
            r_busy            <= 1'b0;
            r_write           <= 1'b0;
            r_addr            <= {TL_ADDR_WIDTH{1'b0}};
            r_wdata           <= {TL_DATA_WIDTH{1'b0}};
            r_rdata_captured  <= {TL_DATA_WIDTH{1'b0}};
        end else begin
            // 1. Data Capture (must happen before FSM update if checking current state)
            if (r_state == IDLE_ST && i_req && !r_busy) begin
                r_write           <= i_write;
                r_addr            <= i_addr;
                r_wdata           <= i_wdata;
            end
            
            // 2. State and Output Updates
            r_state           <= r_next_state;
            r_a_valid         <= r_a_valid_next;
            r_d_ready         <= r_d_ready_next;
            r_ack             <= r_ack_next;
            r_busy            <= r_busy_next;

            // Update captured read data
            r_rdata_captured  <= r_rdata_captured_next;
        end
    end

endmodule
