// =============================================================================
// File        : Formal Properties for tlulSlaveLeds.v
// Author      : @fjpolo
// email       : fjpolo@gmail.com
// Description : Basic TileLink UL slave: 8xLED controller with Put and Get. White Box Formal Properties
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
`ifdef	FORMAL
// Change direction of assumes
`define	ASSERT	assert
`ifdef	tlulSlaveLeds
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif

    ////////////////////////////////////////////////////
	//
	// f_past_valid register
	//
	////////////////////////////////////////////////////
	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;



    ////////////////////////////////////////////////////
	//
	// Reset
	//
	////////////////////////////////////////////////////

	// i_reset
	always @(posedge i_clk)
		if(!f_past_valid)
			assume(i_reset);

	// signals
	always @(posedge i_clk) begin
		if((f_past_valid)&&($past(i_reset))) begin
			assert(o_d_valid == 'b0);
			assert(r_leds == 'b0);
            assert(o_d_opcode == 'b0);
            assert(o_d_param == 'b0);
            assert(o_d_size == 'b0);
            assert(o_d_source == 'b0);
            assert(o_d_data == 'b0);
            assert(o_d_denied == 'b0);
		end
	end

    ////////////////////////////////////////////////////
	//
	// BMC
	//
	////////////////////////////////////////////////////
	
	// Unsupported Opcode
	// Assert that an unsupported opcode results in a HintAck (3'b110) and Denial (2'b1).
	always @(posedge i_clk) begin
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		) begin
			if(
				($past(i_a_valid))&&($past(o_a_ready))&&		// Valid request
				($past(i_a_address == LEDS_REG_ADDR))&&			// Correct register address
				(!$past(i_a_opcode == 'b000))&&
				(!$past(i_a_opcode == 'b001))
			  ) begin
			  assert(o_d_valid == 'b1);
			  assert(o_d_denied == 'b1);
			  assert(o_d_opcode == 'b110); // HintAck
			end
		end
	end

	// Unsupported Address
	// Assert that an unsupported address results in a HintAck (3'b110) and Denial (2'b1).
	always @(posedge i_clk) begin
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		) begin
			if(
				($past(i_a_valid))&&($past(o_a_ready))&&	// Valid request
				($past(i_a_address != LEDS_REG_ADDR))		// Incorrect address
			) begin
				assert(o_d_valid == 'b1);
				assert(o_d_denied == 'b1);
				assert(o_d_opcode == 'b110); // HintAck
			end	
		end
	end

    ////////////////////////////////////////////////////
	//
	// Contract
	//
	////////////////////////////////////////////////////   

	// o_valid - MUST be HIGH next cycle if valid high, ready high, correct register address and Get opcode
	always @(posedge i_clk) begin
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		) begin
			if(
				($past(i_a_valid))&&($past(o_a_ready))&&	// Valid request
				($past(i_a_address == LEDS_REG_ADDR))&&		// Correct register address
				($past(i_a_opcode == 'b000))				// Get Operation opcode
			) begin
			  assert(d_valid_next == 'b1);
			  assert(o_d_valid == 'b1);
			end
		end
	end

	// Put Operation: Writing to register must match i_a_data on next clock cycle
	always @(posedge i_clk) begin
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		) begin
			if(
				($past(i_a_valid))&&($past(o_a_ready))&&	// Valid request
				($past(i_a_address == LEDS_REG_ADDR))&&		// Correct register address
				($past(i_a_opcode == 'b001))				// Put Operation opcode
			) begin
			  assert(o_d_valid == 'b1);
			  assert(r_leds == $past(i_a_data[7:0]));
			end
		end
	end

	// Get Operation
	always @(posedge i_clk) begin
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		) begin
			if(
				($past(i_a_valid))&&($past(o_a_ready))&&	// Valid request
				($past(i_a_address == LEDS_REG_ADDR))&&		// Correct register address
				($past(i_a_opcode == 'b000))				// Get Operation opcode
			) begin
			  assert(o_d_valid == 'b1);
			  assert(o_d_data[7:0] == $past(r_leds[7:0]));
			end
		end
	end

	// Ready-Valid handshake
	// o_d_valid must be LOW when there was no active request on Channel A in the previous cycle. (No spurious response)
	always @(posedge i_clk) begin
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		) begin
			if(!($past(i_a_valid)&&$past(o_a_ready))) begin
			  assert(o_d_valid == 'b0);
			end
		end
	end

    ////////////////////////////////////////////////////
	//
	// Induction
	//
	////////////////////////////////////////////////////
    
	////////////////////////////////////////////////////
	//
	// Cover
	//
	////////////////////////////////////////////////////     

	// o_d_valid
	always @(posedge i_clk)
		if((f_past_valid)&&(!i_reset))
			cover(d_valid_next);

`endif

