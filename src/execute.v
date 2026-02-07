`timescale 1ps/1ps

// Execute stage.
//
// Purpose:
// - Resolve operand forwarding for both ALU inputs.
// - Detect load-use hazards and request pipeline stalls.
// - Compute ALU result, branch decision/target, and memory request signals.
// - Register execute outputs into the first MEM boundary.
//
// Assumptions:
// - Forwarding priority is newest-to-oldest:
//   EX (current stage outputs) -> MEM_A -> MEM_B -> WB -> stall buffers -> regfile.
// - `stall` freezes younger pipeline state and prevents store side effects.
module execute(input clk, input halt, 
    input bubble_in, input halt_in_wb,
    input [4:0]opcode, input [4:0]s_1, input [4:0]s_2, input [4:0]tgt_1, input [4:0]tgt_2, input [4:0]alu_op,
    input [31:0]imm, input [4:0]branch_code,
    
    input [4:0]mem_a_tgt_1, input [4:0]mem_a_tgt_2,
    input [4:0]mem_b_tgt_1, input [4:0]mem_b_tgt_2, 
    input [4:0]wb_tgt_1, input [4:0]wb_tgt_2,
    
    input [31:0]reg_out_1, input [31:0]reg_out_2,

    input [31:0]mem_a_result_out_1, input [31:0]mem_a_result_out_2,
    input [31:0]mem_b_result_out_1, input [31:0]mem_b_result_out_2,
    input [31:0]wb_result_out_1, input [31:0]wb_result_out_2, 
    
    input [31:0]decode_pc_out, input halt_in,
    input [4:0]mem_opcode_out,

    input is_load, input is_store, input is_branch, 
    input mem_a_bubble, input mem_a_is_load, input mem_b_bubble, input mem_b_is_load,
    input is_post_inc,
    
    output reg [31:0]result_1, output reg [31:0]result_2,
    output reg [31:0]addr, output reg [31:0]store_data, output reg [3:0]we,
    output reg [4:0]opcode_out, output reg [4:0]tgt_out_1, output reg [4:0]tgt_out_2,
    
    output reg bubble_out,
    output branch, output [31:0]branch_tgt, output reg halt_out,
    output [3:0]flags,

    output stall, 

    output reg is_load_out, output reg is_store_out
  );

  initial begin
    bubble_out = 1;
    tgt_out_1 = 5'd0;
    tgt_out_2 = 5'd0;
    reg_tgt_buf_a_1 = 5'd0;
    reg_tgt_buf_a_2 = 5'd0;
    reg_tgt_buf_b_1 = 5'd0;
    reg_tgt_buf_b_2 = 5'd0;
  end

  reg [4:0]reg_tgt_buf_a_1;
  reg [4:0]reg_tgt_buf_a_2;
  reg [4:0]reg_tgt_buf_b_1;
  reg [4:0]reg_tgt_buf_b_2;
  reg [31:0]reg_data_buf_a_1;
  reg [31:0]reg_data_buf_a_2;
  reg [31:0]reg_data_buf_b_1;
  reg [31:0]reg_data_buf_b_2;

  wire [31:0]op1;
  wire [31:0]op2;

  wire is_mem_w = (5'd3 <= opcode && opcode <= 5'd5);
  wire is_mem_d = (5'd6 <= opcode && opcode <= 5'd8);
  wire is_mem_b = (5'd9 <= opcode && opcode <= 5'd11);

  // Forwarding hit/data terms for source 1.
  wire ex1_hit_1 = (tgt_out_1 == s_1) && (s_1 != 5'd0);
  wire ex1_hit_2 = (tgt_out_2 == s_1) && (s_1 != 5'd0);
  wire ex1_hit = ex1_hit_1 || ex1_hit_2;
  wire [31:0]ex1_data = ex1_hit_1 ? result_1 : result_2;

  wire mema1_hit_1 = (mem_a_tgt_1 == s_1) && (s_1 != 5'd0);
  wire mema1_hit_2 = (mem_a_tgt_2 == s_1) && (s_1 != 5'd0);
  wire mema1_hit = mema1_hit_1 || mema1_hit_2;
  wire [31:0]mema1_data = mema1_hit_1 ? mem_a_result_out_1 : mem_a_result_out_2;

  wire memb1_hit_1 = (mem_b_tgt_1 == s_1) && (s_1 != 5'd0);
  wire memb1_hit_2 = (mem_b_tgt_2 == s_1) && (s_1 != 5'd0);
  wire memb1_hit = memb1_hit_1 || memb1_hit_2;
  wire [31:0]memb1_data = memb1_hit_1 ? mem_b_result_out_1 : mem_b_result_out_2;

  wire wb1_hit_1 = (wb_tgt_1 == s_1) && (s_1 != 5'd0);
  wire wb1_hit_2 = (wb_tgt_2 == s_1) && (s_1 != 5'd0);
  wire wb1_hit = wb1_hit_1 || wb1_hit_2;
  wire [31:0]wb1_data = wb1_hit_1 ? wb_result_out_1 : wb_result_out_2;

  wire bufa1_hit_1 = (reg_tgt_buf_a_1 == s_1) && (s_1 != 5'd0);
  wire bufa1_hit_2 = (reg_tgt_buf_a_2 == s_1) && (s_1 != 5'd0);
  wire bufa1_hit = bufa1_hit_1 || bufa1_hit_2;
  wire [31:0]bufa1_data = bufa1_hit_1 ? reg_data_buf_a_1 : reg_data_buf_a_2;

  wire bufb1_hit_1 = (reg_tgt_buf_b_1 == s_1) && (s_1 != 5'd0);
  wire bufb1_hit_2 = (reg_tgt_buf_b_2 == s_1) && (s_1 != 5'd0);
  wire bufb1_hit = bufb1_hit_1 || bufb1_hit_2;
  wire [31:0]bufb1_data = bufb1_hit_1 ? reg_data_buf_b_1 : reg_data_buf_b_2;

  assign op1 =
    ex1_hit ? ex1_data :
    mema1_hit ? mema1_data :
    memb1_hit ? memb1_data :
    wb1_hit ? wb1_data :
    bufa1_hit ? bufa1_data :
    bufb1_hit ? bufb1_data :
    reg_out_1;

  // Forwarding hit/data terms for source 2.
  wire ex2_hit_1 = (tgt_out_1 == s_2) && (s_2 != 5'd0);
  wire ex2_hit_2 = (tgt_out_2 == s_2) && (s_2 != 5'd0);
  wire ex2_hit = ex2_hit_1 || ex2_hit_2;
  wire [31:0]ex2_data = ex2_hit_1 ? result_1 : result_2;

  wire mema2_hit_1 = (mem_a_tgt_1 == s_2) && (s_2 != 5'd0);
  wire mema2_hit_2 = (mem_a_tgt_2 == s_2) && (s_2 != 5'd0);
  wire mema2_hit = mema2_hit_1 || mema2_hit_2;
  wire [31:0]mema2_data = mema2_hit_1 ? mem_a_result_out_1 : mem_a_result_out_2;

  wire memb2_hit_1 = (mem_b_tgt_1 == s_2) && (s_2 != 5'd0);
  wire memb2_hit_2 = (mem_b_tgt_2 == s_2) && (s_2 != 5'd0);
  wire memb2_hit = memb2_hit_1 || memb2_hit_2;
  wire [31:0]memb2_data = memb2_hit_1 ? mem_b_result_out_1 : mem_b_result_out_2;

  wire wb2_hit_1 = (wb_tgt_1 == s_2) && (s_2 != 5'd0);
  wire wb2_hit_2 = (wb_tgt_2 == s_2) && (s_2 != 5'd0);
  wire wb2_hit = wb2_hit_1 || wb2_hit_2;
  wire [31:0]wb2_data = wb2_hit_1 ? wb_result_out_1 : wb_result_out_2;

  wire bufa2_hit_1 = (reg_tgt_buf_a_1 == s_2) && (s_2 != 5'd0);
  wire bufa2_hit_2 = (reg_tgt_buf_a_2 == s_2) && (s_2 != 5'd0);
  wire bufa2_hit = bufa2_hit_1 || bufa2_hit_2;
  wire [31:0]bufa2_data = bufa2_hit_1 ? reg_data_buf_a_1 : reg_data_buf_a_2;

  wire bufb2_hit_1 = (reg_tgt_buf_b_1 == s_2) && (s_2 != 5'd0);
  wire bufb2_hit_2 = (reg_tgt_buf_b_2 == s_2) && (s_2 != 5'd0);
  wire bufb2_hit = bufb2_hit_1 || bufb2_hit_2;
  wire [31:0]bufb2_data = bufb2_hit_1 ? reg_data_buf_b_1 : reg_data_buf_b_2;

  assign op2 =
    ex2_hit ? ex2_data :
    mema2_hit ? mema2_data :
    memb2_hit ? memb2_data :
    wb2_hit ? wb2_data :
    bufa2_hit ? bufa2_data :
    bufb2_hit ? bufb2_data :
    reg_out_2;

  // Stall only on load-use dependencies where forwarding cannot satisfy data
  // in time for this execute slot.
  wire ex_load_hazard =
    (((tgt_out_1 == s_1) || (tgt_out_1 == s_2)) && (tgt_out_1 != 5'd0)) ||
    (((tgt_out_2 == s_1) || (tgt_out_2 == s_2)) && (tgt_out_2 != 5'd0));

  wire mem_a_load_hazard =
    (((mem_a_tgt_1 == s_1) || (mem_a_tgt_1 == s_2)) && (mem_a_tgt_1 != 5'd0)) ||
    (((mem_a_tgt_2 == s_1) || (mem_a_tgt_2 == s_2)) && (mem_a_tgt_2 != 5'd0));

  wire mem_b_load_hazard =
    (((mem_b_tgt_1 == s_1) || (mem_b_tgt_1 == s_2)) && (mem_b_tgt_1 != 5'd0)) ||
    (((mem_b_tgt_2 == s_1) || (mem_b_tgt_2 == s_2)) && (mem_b_tgt_2 != 5'd0));

  assign stall =
    (ex_load_hazard && is_load_out && !bubble_in && !bubble_out) ||
    (mem_a_load_hazard && mem_a_is_load && !bubble_in && !mem_a_bubble) ||
    (mem_b_load_hazard && mem_b_is_load && !bubble_in && !mem_b_bubble);

  // ISA quirk: immediate sub uses imm as lhs and register as rhs.
  wire [31:0]lhs = (opcode == 5'd1 && alu_op == 5'd16) ? imm : op1;
  wire [31:0]rhs = ((opcode == 5'd1 && alu_op != 5'd16) || (opcode == 5'd2) || 
                    (5'd3 <= opcode && opcode <= 5'd11) || (opcode == 5'd22)) ? 
                    imm : (opcode == 5'd1 && alu_op == 5'd16) ? op1 : op2;

  // Stores are inhibited on bubbles/halts/stalls so side effects only occur
  // for committed execute slots.
  wire we_bit = is_store && !bubble_in && !halt_out && !halt_in_wb && !stall;

  wire [31:0]alu_rslt;
  ALU ALU(clk, opcode, alu_op, lhs, rhs, decode_pc_out, bubble_in, alu_rslt, flags);

  always @(posedge clk) begin
    if (~halt) begin
      result_1 <= (opcode == 5'd13 || opcode == 5'd14) ? decode_pc_out + 32'd4 : alu_rslt;
      result_2 <= alu_rslt;
      tgt_out_1 <= (halt_in_wb || stall) ? 5'd0 : tgt_1;
      tgt_out_2 <= (halt_in_wb || stall) ? 5'd0 : tgt_2;
      opcode_out <= opcode;
      bubble_out <= (halt_in_wb || stall) ? 1 : bubble_in;
      halt_out <= halt_in && !bubble_in;

      // Memory addressing:
      // - absolute uses base+imm from ALU, except post-inc stores/loads use
      //   original base for this memory access and write back incremented base.
      // - relative forms add PC+4.
      addr <= (opcode == 5'd3 || opcode == 5'd6 || opcode == 5'd9) ? (is_post_inc ? op1 : alu_rslt) : // absolute mem
        (opcode == 5'd4 || opcode == 5'd7 || opcode == 5'd10) ? alu_rslt + decode_pc_out + 32'h4 : // relative mem
        (opcode == 5'd5 || opcode == 5'd8 || opcode == 5'd11) ? alu_rslt + decode_pc_out + 32'h4 : // relative immediate mem
        32'h0;
      store_data <= op2;
      we <= 
        is_mem_w ? {4{we_bit}} : 
        is_mem_d ? {2'b0, {2{we_bit}}} :
        is_mem_b ? {3'b0, we_bit}:
        4'h0;

      is_load_out <= is_load;
      is_store_out <= is_store;

      if (stall) begin
        // Preserve latest WB values in local buffers for prolonged stalls so
        // dependent instructions can still forward once unstalled.
        reg_tgt_buf_a_1 <= stall ? wb_tgt_1 : 0;
        reg_tgt_buf_a_2 <= stall ? wb_tgt_2 : 0;
        reg_data_buf_a_1 <= wb_result_out_1;
        reg_data_buf_a_2 <= wb_result_out_2;
        reg_tgt_buf_b_1 <= stall ? reg_tgt_buf_a_1 : 0;
        reg_tgt_buf_b_2 <= stall ? reg_tgt_buf_a_2 : 0;
        reg_data_buf_b_1 <= reg_data_buf_a_1;
        reg_data_buf_b_2 <= reg_data_buf_a_2;
      end
    end
  end

  // Branch condition decode mirrors ISA branch code table.
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
  
  // Branch target calculation:
  // - immediate branch uses word-offset immediate (imm << 2) + PC + 4.
  // - absolute register branch jumps to op1.
  // - relative register branch jumps to PC + 4 + op1.
  assign branch_tgt = 
            (opcode == 5'd12) ? decode_pc_out + (imm << 2) + 32'h4 :
            (opcode == 5'd13) ? op1 :
            (opcode == 5'd14) ? decode_pc_out + op1 + 32'h4 : 
            decode_pc_out + 32'h4;

endmodule
