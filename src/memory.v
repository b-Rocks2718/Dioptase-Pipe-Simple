`timescale 1ps/1ps

module memory(input clk, input halt,
    input bubble_in,
    input [2:0]opcode_in, input [2:0]tgt_in, input [15:0]result_in, input halt_in,
    
    output reg [2:0]tgt_out, output reg [2:0] opcode_out, output reg [15:0]result_out,
    output reg bubble_out, output reg halt_out
  );

  initial begin
    bubble_out = 1;
    halt_out = 0;
    tgt_out = 3'b000;
  end

  always @(posedge clk) begin
    if (~halt) begin
      tgt_out <= tgt_in;
      opcode_out <= opcode_in;
      result_out <= result_in;
      bubble_out <= halt_out ? 1 : bubble_in;
      halt_out <= halt_in && !bubble_in;
    end
  end

endmodule