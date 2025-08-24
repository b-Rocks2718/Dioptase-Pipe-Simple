`timescale 1ps/1ps

module ALU(input clk,
    input [4:0]op, input [4:0]alu_op, input [31:0]s_1, input [31:0]s_2, 
    input bubble,
    output [31:0]result, output reg [3:0]flags);

  // flags: O | S | Z | C

  initial begin
    flags = 4'b0000;
  end

  wire [32:0]sum;
  assign sum = {1'b0, s_1} + {1'b0, s_2};
  wire [32:0]carry_sum;
  assign carry_sum = {1'b0, s_1} + {1'b0, s_2} + {32'b0, flags[0]};

  wire [31:0]s_2_sub;
  assign s_2_sub = 32'b1 + (~s_2);
  wire [31:0]s_2_subb;
  assign s_2_subb = 32'b1 + ~(s_2 + {31'b0, ~flags[0]});

  wire [32:0]diff;
  assign diff = {1'b0, s_2_sub} + {1'b0, s_1};
  wire [32:0]carry_diff;
  assign carry_diff = {1'b0, s_2_subb} + {1'b0, s_1};

  assign result = (op == 5'd0 || op == 5'd1) ? (
      (alu_op == 5'd0) ? (s_1 & s_2) : // and
      (alu_op == 5'd1) ? (~(s_1 & s_2)) : // nand
      (alu_op == 5'd2) ? (s_1 | s_2) : // or
      (alu_op == 5'd3) ? (~(s_1 | s_2)) : // nor
      (alu_op == 5'd4) ? (s_1 ^ s_2) : // xor
      (alu_op == 5'd5) ? (~(s_1 ^ s_2)) : // xnor
      (alu_op == 5'd6) ? (~s_2) : // not
      (alu_op == 5'd7) ? (s_1 << s_2) : // lsl
      (alu_op == 5'd8) ? (s_1 >> s_2) : // lsr
      (alu_op == 5'd9) ? ({{32{ s_1[31] }}, s_1} >> s_2) : // asr
      (alu_op == 5'd10) ? ((s_1 << s_2) | (s_1 >> (32 - s_2))) : // rotl
      (alu_op == 5'd11) ? ((s_1 >> s_2) | (s_1 << (32 - s_2))) : // rotr
      (alu_op == 5'd12) ? ((s_1 << s_2) | ({flags[0], 31'b0} >> (32 - s_2)) | (s_1 >> (33 - s_2))) : // lslc 
      (alu_op == 5'd13) ? ((s_1 >> s_2) | ({31'b0, flags[0]} << (32 - s_2)) | (s_1 << (33 - s_2))) : // lsrc
      (alu_op == 5'd14) ? sum[31:0] : // add
      (alu_op == 5'd15) ? carry_sum[31:0] : // addc
      (alu_op == 5'd16) ? diff[31:0]  : // sub
      (alu_op == 5'd17) ? carry_diff[31:0] : // subb
      (alu_op == 5'd18) ? (s_1 * s_2) : // mul
      0) :
    (op == 5'd2) ? s_2 : // lui
    (5'd3 <= op && op <= 5'd11) ? (s_1 + s_2) : // memory
    (op == 5'd12) ? 0 : // branch
    (op == 5'd13 || op == 5'd14) ? s_1 : // branch and link
    (op == 5'd15) ? 0 : // syscall
    0;

  // carry flag
  wire c;
  assign c = (op == 5'd0 || op == 5'd1) ? (

      (alu_op == 5'd0) ? 0 : // and
      (alu_op == 5'd1) ? 0 : // nand
      (alu_op == 5'd2) ? 0 : // or
      (alu_op == 5'd3) ? 0 : // nor
      (alu_op == 5'd4) ? 0 : // xor
      (alu_op == 5'd5) ? 0 : // xnor
      (alu_op == 5'd6) ? 0 : // not
      (alu_op == 5'd7) ? s_1[31] : // lsl
      (alu_op == 5'd8) ? s_1[0] : // lsr
      (alu_op == 5'd9) ? s_1[0] : // asr
      (alu_op == 5'd10) ? s_1[31] : // rotl
      (alu_op == 5'd11) ? s_1[0] : // rotr
      (alu_op == 5'd12) ? s_1[31] : // lslc
      (alu_op == 5'd13) ? s_1[0] : // lsrc
      (alu_op == 5'd14) ? sum[32] : // add
      (alu_op == 5'd15) ? carry_sum[32] : // addc
      (alu_op == 5'd16) ? diff[32] : // sub
      (alu_op == 5'd17) ? carry_diff[32] : // subb
      (alu_op == 5'd18) ? 0 : // mul
      0) :
      flags[0];

  wire zero;
  assign zero = (result == 0);

  wire s;
  assign s = result[31];

  // detect subtraction
  wire [31:0]s_2_for_o = (alu_op == 5'd16) ? s_2_sub :
                         (alu_op == 5'd17) ? s_2_subb :
                         s_2;

  wire o;
  assign o = (result[31] != s_2_for_o[31]) & (s_2_for_o[31] == s_1[31]);

  always @(posedge clk) begin
    if (!bubble) begin
      flags <= {o, s, zero, c};
    end
  end

endmodule