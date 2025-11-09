// =============================================================================
// File        : Formal Properties for tlulMaster.v
// Author      : @fjpolo
// email       : fjpolo@gmail.com
// Description : <Brief description of the module or file>
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
`ifdef	tlulMaster
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
	always @(posedge i_clk)
		if(!f_past_valid)
			assume(!i_reset_n);


    ////////////////////////////////////////////////////
	//
	// Reset
	//
	////////////////////////////////////////////////////

	// r_state
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_state == RESET_ST);
	// r_a_valid
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_a_valid         == 1'b0);
	// r_d_ready
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_d_ready         == 1'b0);
	// r_ack
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_ack             == 1'b0);
	// r_busy
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_busy            == 1'b0);
	// r_write
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_write           == 1'b0);
	// r_addr
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_addr            == {TL_ADDR_WIDTH{1'b0}});
	// r_wdata
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_wdata           == {TL_DATA_WIDTH{1'b0}});
	// r_rdata_captured
	always @(posedge i_clk)
		if(($past(f_past_valid))&&(f_past_valid)&&(!$past(i_reset_n))&&(i_reset_n))
			assert(r_rdata_captured  == {TL_DATA_WIDTH{1'b0}});

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
           
`endif

