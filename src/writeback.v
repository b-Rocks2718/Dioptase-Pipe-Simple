`timescale 1ps/1ps

module writeback(input clk, input halt, input bubble_in, 
    input [4:0]tgt_in_1, input [4:0]tgt_in_2, input is_load, input is_store,
    
    input [4:0]opcode, 
    input [31:0]alu_result_1, input [31:0]alu_result_2, input [31:0]mem_result, 
    input [31:0]addr,

    output [31:0]result_out_1,
    output [31:0]result_out_2,
    
    output we1, output reg [4:0]wb_tgt_out_1, output reg [31:0]wb_result_out_1,
    output we2, output reg [4:0]wb_tgt_out_2, output reg [31:0]wb_result_out_2
  );

  initial begin
    wb_tgt_out_1 = 5'd0;
    wb_tgt_out_2 = 5'd0;
  end

  always @(posedge clk) begin
    if (~halt) begin
      wb_tgt_out_1 <= tgt_in_1;
      wb_tgt_out_2 <= tgt_in_2;
      wb_result_out_1 <= result_out_1;
      wb_result_out_2 <= result_out_2;
    end
  end

  // todo: combine results for misaligned memory
  wire [31:0]masked_mem_result = 
    (5'd3 <= opcode && opcode <= 5'd5) ? mem_result :
    (5'd6 <= opcode && opcode <= 5'd8 && !addr[1]) ? mem_result & 32'hffff :
    (5'd6 <= opcode && opcode <= 5'd8 && addr[1]) ? mem_result >> 16 :
    (5'd9 <= opcode && opcode <= 5'd11 && !addr[0] && !addr[1]) ? mem_result & 32'hff :
    (5'd9 <= opcode && opcode <= 5'd11 && addr[0] && !addr[1]) ? (mem_result & 32'hff00) >> 8 :
    (5'd9 <= opcode && opcode <= 5'd11 && !addr[0] && addr[1]) ? (mem_result & 32'hff0000) >> 16 :
    (5'd9 <= opcode && opcode <= 5'd11 && addr[0] && addr[1]) ? (mem_result & 32'hff000000) >> 24 :
    32'h0;

  // stores and immediate branches don't write to register file, everything else does
  assign we1 = (tgt_in_1 != 0) && (!is_store && opcode != 5'd12) && !bubble_in;
  assign we2 = (tgt_in_2 != 0) && (opcode != 5'd12) && !bubble_in;
  assign result_out_1 = is_load ? masked_mem_result : alu_result_1;
  assign result_out_2 = alu_result_2;

endmodule