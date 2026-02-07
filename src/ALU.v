`timescale 1ps/1ps

// ALU datapath and flag producer.
//
// Interface contract:
// - `result` is purely combinational from current inputs.
// - `flags` update on clock edge when `bubble` is false.
// - Flag bit order is {overflow, sign, zero, carry}.
//
// Notes:
// - Carry for opcode 0/1 operations is generated from ALU core operation.
// - Non-ALU opcodes preserve previous carry by design.
module ALU(input clk,
    input [4:0]op, input [4:0]alu_op, input [31:0]s_1, input [31:0]s_2, 
    input [31:0]pc, input bubble,
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

  // ALU-op-local combinational core used by opcode 0/1 execution.
  reg [31:0]alu_core_result;
  reg alu_core_carry;
  always @(*) begin
    alu_core_result = 32'd0;
    alu_core_carry = 1'b0;
    case (alu_op)
      5'd0: begin // and
        alu_core_result = s_1 & s_2;
      end
      5'd1: begin // nand
        alu_core_result = ~(s_1 & s_2);
      end
      5'd2: begin // or
        alu_core_result = s_1 | s_2;
      end
      5'd3: begin // nor
        alu_core_result = ~(s_1 | s_2);
      end
      5'd4: begin // xor
        alu_core_result = s_1 ^ s_2;
      end
      5'd5: begin // xnor
        alu_core_result = ~(s_1 ^ s_2);
      end
      5'd6: begin // not
        alu_core_result = ~s_2;
      end
      5'd7: begin // lsl
        alu_core_result = s_1 << s_2;
        alu_core_carry = s_1[31];
      end
      5'd8: begin // lsr
        alu_core_result = s_1 >> s_2;
        alu_core_carry = s_1[0];
      end
      5'd9: begin // asr
        alu_core_result = {{32{s_1[31]}}, s_1} >> s_2;
        alu_core_carry = s_1[0];
      end
      5'd10: begin // rotl
        alu_core_result = (s_1 << s_2) | (s_1 >> (32 - s_2));
        alu_core_carry = s_1[31];
      end
      5'd11: begin // rotr
        alu_core_result = (s_1 >> s_2) | (s_1 << (32 - s_2));
        alu_core_carry = s_1[0];
      end
      5'd12: begin // lslc
        alu_core_result = (s_1 << s_2) | ({flags[0], 31'b0} >> (32 - s_2)) | (s_1 >> (33 - s_2));
        alu_core_carry = s_1[31];
      end
      5'd13: begin // lsrc
        alu_core_result = (s_1 >> s_2) | ({31'b0, flags[0]} << (32 - s_2)) | (s_1 << (33 - s_2));
        alu_core_carry = s_1[0];
      end
      5'd14: begin // add
        alu_core_result = sum[31:0];
        alu_core_carry = sum[32];
      end
      5'd15: begin // addc
        alu_core_result = carry_sum[31:0];
        alu_core_carry = carry_sum[32];
      end
      5'd16: begin // sub
        alu_core_result = diff[31:0];
        alu_core_carry = diff[32];
      end
      5'd17: begin // subb
        alu_core_result = carry_diff[31:0];
        alu_core_carry = carry_diff[32];
      end
      5'd18: begin // sxtb (only valid for opcode 0)
        alu_core_result = (op == 5'd0) ? {{24{s_2[7]}}, s_2[7:0]} : 32'd0;
      end
      5'd19: begin // sxtd (only valid for opcode 0)
        alu_core_result = (op == 5'd0) ? {{16{s_2[15]}}, s_2[15:0]} : 32'd0;
      end
      5'd20: begin // tncb (only valid for opcode 0)
        alu_core_result = (op == 5'd0) ? {{24{1'b0}}, s_2[7:0]} : 32'd0;
      end
      5'd21: begin // tncd (only valid for opcode 0)
        alu_core_result = (op == 5'd0) ? {{16{1'b0}}, s_2[15:0]} : 32'd0;
      end
      default: begin
        alu_core_result = 32'd0;
        alu_core_carry = 1'b0;
      end
    endcase
  end

  // Top-level opcode selection around the ALU core.
  reg [31:0]result_r;
  always @(*) begin
    result_r = 32'd0;
    case (op)
      5'd0, 5'd1: result_r = alu_core_result;        // ALU reg/imm
      5'd2: result_r = s_2;                          // lui
      5'd3, 5'd4, 5'd5,
      5'd6, 5'd7, 5'd8,
      5'd9, 5'd10, 5'd11: result_r = s_1 + s_2;      // memory address
      5'd12: result_r = 32'd0;                       // branch immediate
      5'd13, 5'd14: result_r = s_1;                  // branch and link
      5'd15: result_r = 32'd0;                       // syscall
      5'd22: result_r = pc + 32'h4 + s_2;            // adpc
      default: result_r = 32'd0;
    endcase
  end

  assign result = result_r;

  // Carry is only produced by opcode 0/1 ALU ops; other opcodes preserve it.
  wire c = ((op == 5'd0) || (op == 5'd1)) ? alu_core_carry : flags[0];

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
