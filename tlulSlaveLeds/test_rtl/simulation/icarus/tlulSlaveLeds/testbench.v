// =============================================================================
// File          : testbench.v for tlulSlaveLeds.v
// Author        : @fjpolo
// email         : fjpolo@gmail.com
// Description   : Basic TileLink UL slave: 8xLED controller with Put and Get. Self-checking testbench
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

module testbench;

    localparam FULL_CLK = 10;
    localparam HALF_CLK = 5;

    // Parameters must match the DUT (tlulSlaveLeds)
    localparam TL_DATA_WIDTH = 64;
    localparam TL_ADDR_WIDTH = 32;
    localparam LEDS_REG_ADDR = 32'h0;

    // --- TL Master (Testbench) Interface Registers ---
    reg  i_clk = 1'b1;
    reg  i_reset;
    
    // Channel A (Inputs to Slave)
    reg              i_a_valid;
    wire             o_a_ready;
    reg  [2:0]       i_a_opcode;
    reg  [2:0]       i_a_param;
    reg  [3:0]       i_a_size;
    reg  [7:0]       i_a_source;
    reg  [(TL_ADDR_WIDTH-1):0] i_a_address;
    reg  [(TL_DATA_WIDTH-1):0] i_a_data;
    reg  [7:0]       i_a_mask; // Unused, but included for completeness
    
    // Channel D (Outputs from Slave)
    wire             o_d_valid;
    reg              i_d_ready;
    wire [2:0]       o_d_opcode;
    wire [2:0]       o_d_param;
    wire [3:0]       o_d_size;
    wire [7:0]       o_d_source;
    wire [(TL_DATA_WIDTH-1):0] o_d_data;
    wire [1:0]       o_d_denied;

    // --- Peripheral Output ---
    wire [7:0]       o_leds;

    // --- Internal Test State ---
    reg [7:0] expected_led_data;
    integer errors = 0;

    // Instantiate the Unit Under Test (UUT)
    tlulSlaveLeds 
`ifndef MCY
    # (
        .TL_DATA_WIDTH (TL_DATA_WIDTH),
        .TL_ADDR_WIDTH (TL_ADDR_WIDTH)
    ) 
`endif
    uut (
        // System
        .i_clk      (i_clk),
        .i_reset    (i_reset),
        // Channel A (Request)
        .i_a_valid  (i_a_valid),
        .o_a_ready  (o_a_ready),
        .i_a_opcode (i_a_opcode),
        // .i_a_param  (i_a_param),
        .i_a_size   (i_a_size),
        .i_a_source (i_a_source),
        .i_a_address(i_a_address),
        .i_a_data   (i_a_data),
        // .i_a_mask   (i_a_mask),
        // Channel D (Response)
        .o_d_valid  (o_d_valid),
        .i_d_ready  (i_d_ready),
        .o_d_opcode (o_d_opcode),
        .o_d_param  (o_d_param),
        .o_d_size   (o_d_size),
        .o_d_source (o_d_source),
        .o_d_data   (o_d_data),
        .o_d_denied (o_d_denied),
        // LEDs output
        .o_leds     (o_leds)
    );

    // =================================================================
    // Tasks: Transaction Generation and Checking
    // =================================================================
    
    // Task to perform a TL-UL transaction (Put or Get)
    task automatic tlul_transaction;
        input [2:0] opcode;
        input [(TL_ADDR_WIDTH-1):0] address;
        input [(TL_DATA_WIDTH-1):0] data;
        input [3:0] size;
        input [7:0] source;
        output [(TL_DATA_WIDTH-1):0] resp_data;
        output [2:0] resp_opcode;
        output [1:0] resp_denied;
        
        begin
            // 1. Setup A-channel request
            i_a_opcode  = opcode;
            i_a_address = address;
            i_a_data    = data;
            i_a_size    = size;
            i_a_source  = source;
            i_a_param   = 3'b0;
            i_a_mask    = 8'hFF; // PutFullData mask
            i_a_valid   = 1'b1;

            #FULL_CLK;
            i_a_valid = 1'b0;
            
            // 2. Wait for the slave to accept (since o_a_ready is always 1, this is 1 cycle)
            if (!o_a_ready) $fatal(1, "Slave not ready, but it should be!");
            
            // 3. Wait for the D-channel response (one cycle after A-channel acceptance)
            if (!o_d_valid) $fatal(1, "Expected D channel response, but o_d_valid is low!");
            
            // 4. Capture response and assert i_d_ready to complete
            resp_data   = o_d_data;
            resp_opcode = o_d_opcode;
            resp_denied = o_d_denied;
            i_d_ready   = 1'b1; 
            
            // 5. Final cycle to clear i_d_ready
            #FULL_CLK;
        end
    endtask

    // =================================================================
    // Clock generation
    // =================================================================
    initial begin
        i_clk = 1;
        forever #HALF_CLK i_clk = ~i_clk; // 10ns clock period
    end

    // Waveform dumping (standard Icarus Verilog)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);
    end

    // =================================================================
    // Test Sequence
    // =================================================================
    initial begin
        // --- Initialization ---
        i_reset = 1;
        i_a_valid = 0;
        i_d_ready = 0;
        
        // Apply reset for a few cycles
        #20; 
        i_reset = 0; 
        #FULL_CLK; // Ensure one clock edge after reset goes low
        
        // --- Test 1: Check Reset State (o_leds) ---
        expected_led_data = 8'h00;
        if (o_leds !== expected_led_data) begin
            $display("FAIL [T1]: Reset state check failed. Expected LEDS 8'h%h, got 8'h%h", 
                expected_led_data, o_leds);
            errors = errors + 1;
        end else begin
            $display("PASS [T1]: Reset state check.");
        end

        // --- Test 2: Write (PutFullData) to LEDS Register ---
        begin : test_put
            reg [(TL_DATA_WIDTH-1):0] dummy_data;
            reg [2:0] dummy_opcode;
            reg [1:0] dummy_denied;
            
            expected_led_data = 8'hA5;
            
            $display("INFO [T2]: Writing LEDS value 8'h%h...", expected_led_data);
            tlul_transaction(
                .opcode(3'b001), 
                .address(LEDS_REG_ADDR), 
                .data({56'h0, expected_led_data}), 
                .size(4'b011), // 8-byte/64-bit size
                .source(8'h01),
                .resp_data(dummy_data),
                .resp_opcode(dummy_opcode),
                .resp_denied(dummy_denied)
            );

            #FULL_CLK;
            
            // Check D-Channel Response
            if (dummy_opcode != 3'b010 || dummy_denied != 2'b0) begin
                $display("FAIL [T2.1]: Write response check failed. Expected AccessAck (3'b010/0), got 3'b%b/%b", 
                    dummy_opcode, dummy_denied);
                errors = errors + 1;
            end
            
            // Check LED Output state (o_leds)
            if (o_leds !== expected_led_data) begin
                $display("FAIL [T2.2]: LED write check failed. Expected LEDS 8'h%h, got 8'h%h", 
                    expected_led_data, o_leds);
                errors = errors + 1;
            end else begin
                $display("PASS [T2]: Write operation successful.");
            end
        end
        
        // --- Test 3: Read (Get) from LEDS Register ---
        begin : test_get
            reg [(TL_DATA_WIDTH-1):0] read_data;
            reg [2:0] dummy_opcode;
            reg [1:0] dummy_denied;
            
            expected_led_data = 8'hA5; // Should still be A5 from the write test
            
            $display("INFO [T3]: Reading LEDS value...");
            tlul_transaction(
                .opcode(3'b000), 
                .address(LEDS_REG_ADDR), 
                .data(64'h0), 
                .size(4'b011),
                .source(8'h02),
                .resp_data(read_data),
                .resp_opcode(dummy_opcode),
                .resp_denied(dummy_denied)
            );
            
            // Check D-Channel Response
            if (dummy_opcode != 3'b100 || dummy_denied != 2'b0) begin
                $display("FAIL [T3.1]: Read response check failed. Expected AccessAckData (3'b100/0), got 3'b%b/%b", 
                    dummy_opcode, dummy_denied);
                errors = errors + 1;
            end
            
            // Check Data Payload
            if (read_data[7:0] !== expected_led_data) begin
                $display("FAIL [T3.2]: LED read data check failed. Expected 8'h%h, got 8'h%h", 
                    expected_led_data, read_data[7:0]);
                errors = errors + 1;
            end else begin
                $display("PASS [T3]: Read operation successful.");
            end
        end

        // --- Test 4: Unsupported Address ---
        begin : test_unsupported_addr
            reg [(TL_DATA_WIDTH-1):0] dummy_data;
            reg [2:0] resp_opcode;
            reg [1:0] resp_denied;
            
            $display("INFO [T4]: Testing unsupported address 32'hFFFFFFFF...");
            tlul_transaction(
                .opcode(3'b000), 
                .address(32'hFFFFFFFF), 
                .data(64'h0), 
                .size(4'b011),
                .source(8'h03),
                .resp_data(dummy_data),
                .resp_opcode(resp_opcode),
                .resp_denied(resp_denied)
            );
            
            // Check D-Channel Response for error
            if (resp_opcode != 3'b110 || resp_denied != 2'b1) begin
                $display("FAIL [T4]: Unsupported address check failed. Expected HintAck/Denied (3'b110/1), got 3'b%b/%b", 
                    resp_opcode, resp_denied);
                errors = errors + 1;
            end else begin
                $display("PASS [T4]: Unsupported address correctly denied.");
            end
        end
        
        // --- Final Summary ---
        if (errors == 0) begin
            $display("\n=======================================================");
            $display("PASS: All TileLink LED Slave tests completed successfully.");
            $display("=======================================================");
        end else begin
            $display("\n=======================================================");
            $display("FAIL: %d test error(s) found.", errors);
            $display("=======================================================");
        end
        
        $finish;
    end

    // Monitor for time-out (Catches errors/hangs)
    initial begin
        #1000; // Increased timeout for safety
        $display("\n=======================================================");
        $display("ERROR: Simulation timed out. Check for hangs.");
        $display("=======================================================");
        $finish;
    end

endmodule
