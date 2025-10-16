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
			assert(o_d_valid == 1'b0);
			assert(r_leds == '0);
            assert(o_d_opcode == 3'b0);
            assert(o_d_param == 3'b0);
            assert(o_d_size == 4'b0);
            assert(o_d_source == 8'b0);
            assert(o_d_data == 64'b0);
            assert(o_d_denied == 2'b0);
		end
	end

    ////////////////////////////////////////////////////
	//
	// BMC
	//
	////////////////////////////////////////////////////

    ////////////////////////////////////////////////////
	//
	// Contract
	//
	////////////////////////////////////////////////////   

	// o_valid
	always @(posedge i_clk)
		if(
			(f_past_valid)&&(!i_reset)&&
			($past(f_past_valid))&&(!$past(i_reset))
		  )
			if(
				($past(i_a_valid))&&($past(o_a_ready))&&
				($past(i_a_address == LEDS_REG_ADDR))&&($past(i_a_opcode == 3'b000))
			) begin
			  assert(d_valid_next == 1'b1);
			  assert(o_d_valid == 1'b1);
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
	
	// // i_a_opcode == 3'b000 (get)
	// always @(posedge i_clk)
	// 	if((f_past_valid)&&(!i_reset)&&(i_a_valid)&&(o_a_ready)&&(i_a_address == LEDS_REG_ADDR)&&(i_a_opcode == 3'b000))
	// 		cover(i_a_opcode == 3'b000);

	// // o_d_valid
	// always @(posedge i_clk)
	// 	if((f_past_valid)&&(!i_reset)&&(i_a_valid)&&(o_a_ready)&&(i_a_opcode == 3'b000))
	// 		cover(d_valid_next);

`endif

