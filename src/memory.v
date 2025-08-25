`timescale 1ps/1ps

module memory(input clk, input halt,
    input bubble_in,
    input [4:0]opcode_in, input [4:0]tgt_in_1, input [4:0]tgt_in_2, 
    input [31:0]result_in_1, input [31:0]result_in_2, input halt_in,

    input [31:0]addr_in,

    input is_load, input is_store, input is_misaligned,
    
    output reg [4:0]tgt_out_1, output reg [4:0]tgt_out_2,
    output reg [31:0]result_out_1, output reg [31:0]result_out_2,
    output reg [4:0]opcode_out, output reg [31:0]addr_out,
    output reg bubble_out, output reg halt_out,

    output reg is_load_out, output reg is_store_out, output reg is_misaligned_out
  );

  initial begin
    bubble_out = 1;
    halt_out = 0;
    tgt_out_1 = 5'd0;
    tgt_out_2 = 5'd0;
  end

  always @(posedge clk) begin
    if (~halt) begin
      tgt_out_1 <= tgt_in_1;
      tgt_out_2 <= tgt_in_2;
      opcode_out <= opcode_in;
      result_out_1 <= result_in_1;
      result_out_2 <= result_in_2;
      bubble_out <= halt_out ? 1 : bubble_in;
      halt_out <= halt_in && !bubble_in;
      addr_out <= addr_in;

      is_load_out <= is_load;
      is_store_out <= is_store;
      is_misaligned_out <= is_misaligned;
    end
  end

endmodule
