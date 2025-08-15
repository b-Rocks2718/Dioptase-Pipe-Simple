`timescale 1ps/1ps

module ALU(input clk,
    input [2:0]op, input [3:0]alu_op, input [15:0]s_1, input [15:0]s_2, 
    input bubble,
    output [15:0]result, output reg [3:0]flags);

  // flags: O | S | Z | C

  initial begin
    flags = 4'b0000;
  end

  wire [16:0]sum;
  assign sum = {1'b0, s_1} + {1'b0, s_2};
  wire [16:0]carry_sum;
  assign carry_sum = {1'b0, s_1} + {1'b1, s_2} + {15'b0, flags[0]};

  wire [15:0]s_1_sub;
  assign s_1_sub = 16'b1 + (~s_1);
  wire [15:0]s_1_subc;
  assign s_1_subc = 16'b1 + ~(s_1 + {15'b0, ~flags[0]});

  wire [16:0]diff;
  assign diff = {1'b0, s_2} + {1'b0, s_1_sub};
  wire [16:0]carry_diff;
  assign carry_diff = {1'b0, s_2} + {1'b0, s_1_subc};

  assign result = (op == 3'b000) ? 
      ((alu_op == 4'b0000) ? (~(s_1 & s_2)) : // nand
      (alu_op == 4'b0001) ? sum[15:0] : // add
      (alu_op == 4'b0010) ? carry_sum[15:0] : // addc
      (alu_op == 4'b0011) ? (s_1 | s_2) : // or
      (alu_op == 4'b0100) ? carry_diff[15:0] : // subc
      (alu_op == 4'b0101) ? (s_1 & s_2) : // and
      (alu_op == 4'b0110) ? diff[15:0]  : // sub
      (alu_op == 4'b0111) ? (s_1 ^ s_2) : // xor
      (alu_op == 4'b1000) ? (~s_2) : // not
      (alu_op == 4'b1001) ? ({s_2[14:0], 1'b0}) : // shl
      (alu_op == 4'b1010) ? ({1'b0, s_2[15:1]}) : // shr
      (alu_op == 4'b1011) ? ({s_2[14:0], s_2[15]}) : // rotl
      (alu_op == 4'b1100) ? ({s_2[0], s_2[15:1]}) : // rotr
      (alu_op == 4'b1101) ? ({s_2[15], s_2[15:1]}) : // sshr
      (alu_op == 4'b1110) ? ({flags[0], s_2[15:1]}) : // shrc
      (alu_op == 4'b1111) ? ({s_2[14:0], flags[0]}) : // shlc
      0) :
    (op == 3'b001) ? (s_1 + s_2) : // addi
    (op == 3'b011) ? s_1 : // lui
    (op == 3'b100) ? (s_1 + s_2) : // sw
    (op == 3'b101) ? (s_1 + s_2) : // lw
    (op == 3'b110) ? 0 : // branch
    (op == 3'b111) ? s_1 : // jalr
    0;

  wire c;
  assign c = (op == 3'b000) ? 
      ((alu_op == 4'b0000) ? 0 : // nand
      (alu_op == 4'b0001) ? sum[16] : // add
      (alu_op == 4'b0010) ? carry_sum[16] : // addc
      (alu_op == 4'b0011) ? 0 : // or
      (alu_op == 4'b0100) ? carry_diff[16] : // subc
      (alu_op == 4'b0101) ? 0 : // and
      (alu_op == 4'b0110) ? diff[16] : // sub
      (alu_op == 4'b0111) ? 0 : // xor
      (alu_op == 4'b1000) ? 0 : // not
      (alu_op == 4'b1001) ? s_2[15] : // shl
      (alu_op == 4'b1010) ? s_2[0] : // shr
      (alu_op == 4'b1011) ? s_2[15] : // rotl
      (alu_op == 4'b1100) ? s_2[0] : // rotr
      (alu_op == 4'b1101) ? s_2[0] : // sshr
      (alu_op == 4'b1110) ? s_2[0] : // shrc
      (alu_op == 4'b1111) ? s_2[15] : // shlc
      0) :
    (op == 3'b001) ? sum[16] : 
    0;

  wire zero;
  assign zero = (result == 0);

  wire s;
  assign s = result[15];

  wire [15:0]s_1_for_o = (alu_op == 4'b0100) ? s_1_subc :
                         (alu_op == 4'b0110) ? s_1_sub :
                         s_1;

  wire o;
  assign o = (result[15] != s_1_for_o[15]) & (s_1_for_o[15] == s_2[15]);

  always @(posedge clk) begin
    if (!bubble) begin
      flags <= {o, s, zero, c};
    end
  end

endmodule