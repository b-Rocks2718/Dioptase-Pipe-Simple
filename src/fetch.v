`timescale 1ps/1ps

module fetch_a(input clk, input stall, input flush,
    input branch, input [31:0]branch_tgt,
    output [31:0]fetch_addr, output reg [31:0]pc_out, output reg bubble_out
  );

  reg [31:0]pc = 32'h00000000;

  // -4 is a hack to save a cycle on branches
  assign fetch_addr = branch ? branch_tgt : (stall ? pc - 32'h4 : pc);

  initial begin
    bubble_out = 1;
    pc = 32'h00000000;
  end

  always @(posedge clk) begin
    if (!stall) begin
      pc <= branch ? branch_tgt + 4 : pc + 4; // +4 is a hack to save a cycle on branches
      bubble_out <= 0;
      pc_out <= fetch_addr;
    end
  end
endmodule

module fetch_b(input clk, input stall, input flush, input bubble_in,
    input [31:0]pc_in,
    output reg bubble_out, output reg [31:0]pc_out
  );

    // fetch is 2 stages because memory is 2-cycle
    // pipelining allows us to average fetching 1 instruction every cycle

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