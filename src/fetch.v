`timescale 1ps/1ps

// Fetch stage A:
// - owns architectural PC
// - issues instruction memory address every cycle (unless stalled)
// - redirects on taken branch
//
// Invariant:
// - `fetch_addr` presents the address associated with `pc_out` for the slot
//   entering fetch_b.
module fetch_a(input clk, input stall, input flush,
    input branch, input [31:0]branch_tgt,
    output [31:0]fetch_addr, output reg [31:0]pc_out, output reg bubble_out
  );

  reg [31:0]pc = 32'h00000000;

  // During stall, keep issuing previous fetch address so downstream bubbles
  // remain aligned with memory latency.
  assign fetch_addr = branch ? branch_tgt : (stall ? pc - 32'h4 : pc);

  initial begin
    bubble_out = 1;
    pc = 32'h00000000;
  end

  always @(posedge clk) begin
    if (!stall) begin
      // PC tracks "next sequential" after the currently issued address.
      pc <= branch ? branch_tgt + 4 : pc + 4;
      bubble_out <= 0;
      pc_out <= fetch_addr;
    end
  end
endmodule

module fetch_b(input clk, input stall, input flush, input bubble_in,
    input [31:0]pc_in,
    output reg bubble_out, output reg [31:0]pc_out
  );

    // Fetch stage B aligns fetch PC/bubble with the second cycle of
    // instruction memory latency.

    initial begin
      bubble_out = 1;
    end

    always @(posedge clk) begin 
      if (!stall) begin
        bubble_out <= flush ? 1 : bubble_in;
        pc_out <= pc_in;
      end
    end
endmodule
