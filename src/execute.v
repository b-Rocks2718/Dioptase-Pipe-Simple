`timescale 1ps/1ps

module execute(input clk, input halt, 
    input bubble_in, input halt_in_wb,
    input [2:0]opcode, input [2:0]s_1, input [2:0]s_2, input [2:0]tgt, input [3:0]alu_op,
    input [15:0]imm, input [5:0]branch_code,
    input [2:0] mem_tgt, input [2:0]wb_tgt,
    input [15:0]reg_out_1, input [15:0]reg_out_2,
    input [15:0]mem_result_out, input [15:0]wb_result_out, input [15:0]decode_pc_out, input halt_in,
    input [2:0]mem_opcode_out, input [15:0]mem_out_2,
    output reg [15:0]result, output [15:0]addr, output [15:0]store_data, output we, output reg [2:0]opcode_out,
    output reg [2:0]tgt_out,
    output reg bubble_out,
    output branch, output [15:0]branch_tgt, output reg halt_out,
    output [3:0]flags
  );

  initial begin
    bubble_out = 1;
    tgt_out = 3'b000;
  end

  wire [15:0]op1;
  wire [15:0]op2;

  assign op1 = 
    (tgt_out == s_1 && s_1 != 3'b000) ? result :
    (mem_tgt == s_1 && s_1 != 3'b000) ? 
      ((mem_opcode_out == 3'b101) ? mem_out_2 : mem_result_out) :
    (wb_tgt == s_1 && s_1 != 3'b000) ? wb_result_out :
    reg_out_1;
  assign op2 = 
    (tgt_out == s_2 && s_2 != 3'b000) ? result :
    (mem_tgt == s_2 && s_2 != 3'b000) ?  
      ((mem_opcode_out == 3'b101) ? mem_out_2 : mem_result_out) :
    (wb_tgt == s_2 && s_2 != 3'b000) ? wb_result_out :
    reg_out_2;

  wire mux_lhs = (opcode == 3'b011);
  wire mux_rhs = (opcode == 3'b001) || (opcode == 3'b100) || (opcode == 3'b101) || (opcode == 3'b101);

  wire [15:0]lhs = mux_lhs ? imm : op1;
  wire [15:0]rhs = mux_rhs ? imm : op2;

  // wire [3:0]flags;
  wire [15:0]alu_rslt;
  ALU ALU(clk, opcode, alu_op, lhs, rhs, bubble_in, alu_rslt, flags);

  assign addr = (opcode == 3'b111) ? decode_pc_out + 1 : alu_rslt;
  assign store_data = op2;
  assign we = (opcode == 3'b100) && !bubble_in && !halt_out && !halt_in_wb;

  always @(posedge clk) begin
    if (~halt) begin
      result <= addr;
      tgt_out <= halt_in_wb ? 3'b000 : tgt;
      opcode_out <= opcode;
      bubble_out <= halt_in_wb ? 1 : bubble_in;
      halt_out <= halt_in && !bubble_in;
    end
  end

  wire taken;
  assign taken = (branch_code == 6'b000000) ? flags[1] : // bz beq
                    (branch_code == 6'b000001) ? !flags[1] && !flags[2] : // bp
                    (branch_code == 6'b000010) ? flags[2] : // bn
                    (branch_code == 6'b000011) ? flags[0] : // bc
                    (branch_code == 6'b000100) ? flags[3] : // bo
                    (branch_code == 6'b000101) ? !flags[1] : // bne
                    (branch_code == 6'b000110) ? 1 : // jmp
                    (branch_code == 6'b000111) ? !flags[0] : // bnc
                    (branch_code == 6'b001000) ? !flags[1] && flags[2] == flags[3] : // bg
                    (branch_code == 6'b001001) ? flags[2] == flags[3] || flags[1] : // bge
                    (branch_code == 6'b001010) ? flags[2] != flags[3] && !flags[1] : // bl
                    (branch_code == 6'b001011) ? flags[2] != flags[3] || flags[1] : // ble
                    (branch_code == 6'b001100) ? !flags[1] && flags[0] : // ba
                    (branch_code == 6'b001101) ? flags[0] || flags[1] : // bae
                    (branch_code == 6'b001110) ? !flags[0] && !flags[1] : // bb
                    (branch_code == 6'b001111) ? !flags[0] || flags[1] : // bbe
                    (branch_code == 6'b010000) ? !flags[3] : // bno
                    0;

  assign branch = !bubble_in && !halt_in_wb && (taken && (opcode == 3'b110) || opcode == 3'b111);
  wire [1:0]mux_pc = (opcode == 3'b111) ? 2'b10 :
                     (opcode == 3'b110 && branch) ? 2'b01 :
                     2'b00;
  
  assign branch_tgt = 
            (mux_pc == 2'b00) ? decode_pc_out + 16'h0001 : 
            (mux_pc == 2'b01) ? decode_pc_out + imm + 16'h0001 :
            (mux_pc == 2'b10) ? op1 :
            0;

endmodule