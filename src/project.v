/*
 * Copyright (c) 2026 Jacob Kirera
 * 
 * 1-bit Perceptron (Hardware Neuron)
 * 
 * This module implements a simple artificial neuron in silicon.
 * Computes: y = (x0*w0 + x1*w1 + x2*w2 + x3*w3) >= threshold
 * 
 * Pin mapping:
 *   ui_in[3:0]   - binary inputs  x0..x3
 *   ui_in[5:4]   - weight w0 [1:0]  (0-3)
 *   ui_in[7:6]   - weight w1 [1:0]  (0-3)
 *   uio_in[1:0]  - weight w2 [1:0]  (0-3)
 *   uio_in[3:2]  - weight w3 [1:0]  (0-3)
 *   uio_in[5:4]  - threshold [1:0]  (0-3, actual threshold = value+1)
 *
 *   uo_out[0]    - neuron output y  (1 = fires, 0 = silent)
 *   uo_out[4:1]  - weighted sum[3:0] (debug output)
 *   uo_out[7:5]  - unused (tied low)
 *   uio_out      - unused (tied low)
 */

`default_nettype none

module tt_um_IEEE_perceptron (
  input wire [7:0] ui_in,   // Dedicated inputs
  output wire [7:0] uo_out,  // Dedicated outputs
  input wire [7:0] uio_in,  // bidirectional IOs (used as extra inputs)
  output wire [7:0] uio_out, // bidirectional IOs (not used, tied low)
  output wire [7:0] uio_oe,  // bidirectional IOs enable (not used, tied low)
  input wire ena,           // always 1 when the design is powered
  input wire clk,           //clock(unused - purely combinational)
  input wire rst_n          //reset (unused - purely combinational)
);

  // -------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------
  wire        x0 = ui_in[0];
  wire        x1 = ui_in[1];
  wire        x2 = ui_in[2];
  wire        x3 = ui_in[3];
 
  wire [1:0]  w0 = ui_in[5:4];
  wire [1:0]  w1 = ui_in[7:6];
  wire [1:0]  w2 = uio_in[1:0];
  wire [1:0]  w3 = uio_in[3:2];
 
  // threshold: 2-bit value, actual threshold = thresh + 1 (so range is 1...4)
  wire [1:0] thresh_cfg = uio_in[5:4];

  // -------------------------------------------------------------------------
  // Weighted multiply (AND: binary input gates the weight)
  // Each term is at most 3(2-bit weight * 1-bit input)
  // -------------------------------------------------------------------------
  wire [1:0]  term0 = x0 ? w0 : 2'b00;
  wire [1:0]  term1 = x1 ? w1 : 2'b00;
  wire [1:0]  term2 = x2 ? w2 : 2'b00;
  wire [1:0]  term3 = x3 ? w3 : 2'b00;

  // -------------------------------------------------------------------------
  // Adder tree (max sum = 4*3=12, fits in 4 bits)
  // -------------------------------------------------------------------------
  wire [2:0]  partial_a = {1'b0, term0} + {1'b0, term1};
  wire [2:0]  partial_b = {1'b0, term2} + {1'b0, term3};
  wire [3:0]  weighted_sum = {1'b0, partial_a} + {1'b0, partial_b};
 
  // ---------------------------------------------------------------
  // Threshold comparison  (threshold = cfg value + 1, so 1..4)
  // ---------------------------------------------------------------
  wire [3:0]  threshold = {2'b00, thresh_cfg} + 4'd1;
  wire        neuron_out = (weighted_sum >= threshold);
 
  // ---------------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------------
  assign uo_out[0]   = neuron_out;
  assign uo_out[4:1] = weighted_sum;   // debug: inspect the sum
  assign uo_out[7:5] = 3'b000;
 
  // All bidirectional pins set to input mode (output enable = 0)
  assign uio_out = 8'b00000000;
  assign uio_oe  = 8'b00000000;
 
  // Suppress unused signal warnings
  wire _unused = &{ena, clk, rst_n, uio_in[7:6]};



// module tt_um_example (
//     input  wire [7:0] ui_in,    // Dedicated inputs
//     output wire [7:0] uo_out,   // Dedicated outputs
//     input  wire [7:0] uio_in,   // IOs: Input path
//     output wire [7:0] uio_out,  // IOs: Output path
//     output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
//     input  wire       ena,      // always 1 when the design is powered, so you can ignore it
//     input  wire       clk,      // clock
//     input  wire       rst_n     // reset_n - low to reset
// );

//   // All output pins must be assigned. If not used, assign to 0.
//   assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
//   assign uio_out = 0;
//   assign uio_oe  = 0;

//   // List all unused inputs to prevent warnings
//   wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
