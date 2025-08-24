`timescale 1ps/1ps

module execute(input clk, input halt, 
    input bubble_in, input halt_in_wb,
    input [4:0]opcode, input [4:0]s_1, input [4:0]s_2, input [4:0]tgt_1, input [4:0]tgt_2, input [4:0]alu_op,
    input [31:0]imm, input [4:0]branch_code,
    
    input [4:0]mem_tgt_1, input [4:0]mem_tgt_2, 
    input [4:0]wb_tgt_1, input [4:0]wb_tgt_2,
    
    input [31:0]reg_out_1, input [31:0]reg_out_2,

    input [31:0]mem_result_out_1, input [31:0]mem_result_out_2,
    input [31:0]wb_result_out_1, input [31:0]wb_result_out_2, 
    
    input [31:0]decode_pc_out, input halt_in,
    input [4:0]mem_opcode_out,

    input is_load, input is_store, input is_branch, input mem_bubble, input is_load_mem,
    input is_post_inc,
    
    output reg [31:0]result_1, output reg [31:0]result_2,
    output [31:0]addr, output [31:0]store_data, output we,
    output reg [4:0]opcode_out, output reg [4:0]tgt_out_1, output reg [4:0]tgt_out_2,
    
    output reg bubble_out,
    output branch, output [31:0]branch_tgt, output reg halt_out,
    output [3:0]flags,

    output stall, 

    output reg is_load_out, output reg is_store_out
  );

  // todo: emit multiple instructions for misaligned memory

  initial begin
    bubble_out = 1;
    tgt_out_1 = 5'd0;
    tgt_out_2 = 5'd0;
  end

  wire [31:0]op1;
  wire [31:0]op2;

  assign op1 = 
    (tgt_out_1 == s_1 && s_1 != 5'b0) ? result_1 :
    (tgt_out_2 == s_1 && s_1 != 5'b0) ? result_2 :
    (mem_tgt_1 == s_1 && s_1 != 5'b0) ? mem_result_out_1 : 
    (mem_tgt_2 == s_1 && s_1 != 5'b0) ? mem_result_out_2 : 
    (wb_tgt_1 == s_1 && s_1 != 5'b0) ? wb_result_out_1 :
    (wb_tgt_2 == s_1 && s_1 != 5'b0) ? wb_result_out_2 :
    reg_out_1;

  assign op2 = 
    (tgt_out_1 == s_2 && s_2 != 5'b0) ? result_1 :
    (tgt_out_2 == s_2 && s_2 != 5'b0) ? result_2 :
    (mem_tgt_1 == s_2 && s_2 != 5'b0) ? mem_result_out_1 : 
    (mem_tgt_2 == s_2 && s_2 != 5'b0) ? mem_result_out_2 : 
    (wb_tgt_1 == s_2 && s_2 != 5'b0) ? wb_result_out_1 :
    (wb_tgt_2 == s_2 && s_2 != 5'b0) ? wb_result_out_2 :
    reg_out_2;

  assign stall = 
   ((((tgt_out_1 == s_1 ||
     tgt_out_1 == s_2) &&
     tgt_out_1 != 5'd0) || 
     ((tgt_out_2 == s_1 ||
     tgt_out_2 == s_2) &&
     tgt_out_2 != 5'd0)) &&
     is_load_out && // lw can cause stalls
     !bubble_in && !bubble_out) ||
  ((((mem_tgt_1 == s_1 ||
     mem_tgt_1 == s_2) &&
     mem_tgt_1 != 5'd0) || 
     ((mem_tgt_2 == s_1 ||
     mem_tgt_2 == s_2) &&
     mem_tgt_2 != 5'd0)) &&
     is_load_mem && // lw can cause stalls
     !bubble_in && !mem_bubble);

  // nonsense to make subtract immediate work how i want
  wire [31:0]lhs = (opcode == 5'd1 && alu_op == 5'd16) ? imm : op1;
  wire [31:0]rhs = ((opcode == 5'd1 && alu_op != 5'd16) || (opcode == 5'd2) || (5'd3 <= opcode && opcode <= 5'd11)) ? 
                    imm : (opcode == 5'd1 && alu_op == 5'd16) ? op1 : op2;

  // memory stuff
  assign store_data = (5'd3 <= opcode && opcode <= 5'd5) ? op2 :
                    (5'd6 <= opcode && opcode <= 5'd8) ? (op2 & 32'hffff) :
                    (5'd9 <= opcode && opcode <= 5'd11) ? (op2 & 32'hff) :
                    32'h0;
  assign we = is_store && !bubble_in && !halt_out && !halt_in_wb;
  assign addr = 
    (opcode == 5'd3 || opcode == 5'd6 || opcode == 5'd9) ? alu_rslt : // absolute mem
    (opcode == 5'd4 || opcode == 5'd7 || opcode == 5'd10) ? alu_rslt + decode_pc_out + 32'h4 : // relative mem
    (opcode == 5'd5 || opcode == 5'd8 || opcode == 5'd11) ? alu_rslt + decode_pc_out + 32'h4 : // relative immediate mem
    32'h0;

  wire [31:0]alu_rslt;
  ALU ALU(clk, opcode, alu_op, lhs, rhs, bubble_in, alu_rslt, flags);

  always @(posedge clk) begin
    if (~halt) begin
      result_1 <= (opcode == 5'd13 || opcode == 5'd14) ? decode_pc_out + 32'd4 : 
                  is_post_inc ? op2 : alu_rslt;
      result_2 <= alu_rslt;
      tgt_out_1 <= (halt_in_wb || stall) ? 5'd0 : tgt_1;
      tgt_out_2 <= (halt_in_wb || stall) ? 5'd0 : tgt_2;
      opcode_out <= opcode;
      bubble_out <= (halt_in_wb || stall) ? 1 : bubble_in;
      halt_out <= halt_in && !bubble_in;

      is_load_out <= is_load;
      is_store_out <= is_store;
    end
  end

  wire taken;
  assign taken = (branch_code == 5'd0) ? 1 : // br
                 (branch_code == 5'd1) ? flags[1] : // bz
                 (branch_code == 5'd2) ? !flags[1] : // bnz
                 (branch_code == 5'd3) ? flags[2] : // bs
                 (branch_code == 5'd4) ? !flags[2] : // bns
                 (branch_code == 5'd5) ? flags[0] : // bc
                 (branch_code == 5'd6) ? !flags[0] : // bnc
                 (branch_code == 5'd7) ? flags[3] : // bo
                 (branch_code == 5'd8) ? !flags[3] : // bno
                 (branch_code == 5'd9) ? !flags[1] && !flags[2] : // bps
                 (branch_code == 5'd10) ? flags[1] || flags[2] : // bnps
                 (branch_code == 5'd11) ? flags[2] == flags[3] && !flags[1] : // bg
                 (branch_code == 5'd12) ? flags[2] == flags[3] : // bge
                 (branch_code == 5'd13) ? flags[2] != flags[3] && !flags[1] : // bl
                 (branch_code == 5'd14) ? flags[2] != flags[3] || flags[1] : // ble
                 (branch_code == 5'd15) ? !flags[1] && flags[0] : // ba
                 (branch_code == 5'd16) ? flags[0] || flags[1] : // bae
                 (branch_code == 5'd17) ? !flags[0] && !flags[1] : // bb
                 (branch_code == 5'd18) ? !flags[0] || flags[1] : // bbe
                 0;

  assign branch = !bubble_in && !halt_in_wb && taken && is_branch;
  
  assign branch_tgt = 
            (opcode == 5'd12) ? decode_pc_out + imm + 32'h4 :
            (opcode == 5'd13) ? op1 :
            (opcode == 5'd14) ? decode_pc_out + op1 + 32'h4 : 
            decode_pc_out + 32'h4;

endmodule