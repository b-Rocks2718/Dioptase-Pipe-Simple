`timescale 1ps/1ps

// Top-level 7-stage pipeline wrapper.
//
// Stages:
//   1) fetch_a
//   2) fetch_b
//   3) decode
//   4) execute
//   5) memory_a
//   6) memory_b
//   7) writeback
//
// Invariants:
// - All stage-to-stage data/control transfer is edge-registered.
// - `flush` kills younger instructions on taken branch or halt.
// - External memory port 1 (`mem_read1_addr`) is driven by execute's
//   registered address output, so load data aligns with downstream MEM/WB.
module pipelined_cpu(
  input clk,
  output [31:0]mem_read0_addr, input [31:0]mem_read0_data,
  output [31:0]mem_read1_addr, input [31:0]mem_read1_data,
  output [3:0]mem_we, output [31:0]mem_write_addr, output [31:0]mem_write_data,
  output [31:0]ret_val, output [3:0]flags, output [31:0]curr_pc
);

    reg halt = 0;

    counter ctr(halt, clk, ret_val);

    // Instruction fetch path and data memory return path.
    wire [31:0]fetch_instr_out;
    wire [31:0]mem_out_0;
    wire [31:0]fetch_addr;
    wire [31:0]mem_out_1;

    wire [31:0]exec_result_out_1;
    wire [31:0]exec_result_out_2;
    wire [31:0]addr;
    wire [31:0]store_data;

    wire [31:0]reg_write_data_1;
    wire [31:0]reg_write_data_2;
    wire reg_we_1;
    wire reg_we_2;

    wire branch;
    wire flush;
    wire mem_a_halt;
    wire mem_b_halt;
    assign flush = branch || mem_b_halt;

    // External memory interface bindings.
    reg mem_ren = 1;
    assign mem_read0_addr = fetch_addr;
    assign mem_read1_addr = addr;
    assign mem_out_0 = mem_read0_data;
    assign mem_out_1 = mem_read1_data;
    assign mem_write_addr = addr;
    assign mem_write_data = store_data;

    wire decode_stall;
    wire exec_stall;
    wire [31:0]branch_tgt;
    wire [31:0]decode_pc_out;
    wire [31:0]fetch_a_pc_out;
    wire fetch_a_bubble_out;

    fetch_a fetch_a(clk, decode_stall | exec_stall | halt, flush, branch, branch_tgt,
      fetch_addr, fetch_a_pc_out, fetch_a_bubble_out);

    wire fetch_b_bubble_out;
    wire [31:0]fetch_b_pc_out;

    fetch_b fetch_b(clk, decode_stall | exec_stall | halt, flush, fetch_a_bubble_out, fetch_a_pc_out,
      fetch_b_bubble_out, fetch_b_pc_out);

    wire [31:0] decode_op1_out;
    wire [31:0] decode_op2_out;

    wire [4:0] decode_opcode_out;
    wire [4:0] decode_s_1_out;
    wire [4:0] decode_s_2_out;
    wire [4:0] decode_tgt_out_1;
    wire [4:0] decode_tgt_out_2;
    wire [4:0] decode_alu_op_out;
    wire [31:0] decode_imm_out;
    wire [4:0] decode_branch_code_out;
    
    wire decode_bubble_out;
    wire decode_halt_out;
    wire [4:0]mem_a_tgt_out_1;
    wire [4:0]mem_a_tgt_out_2;
    wire [4:0]mem_b_tgt_out_1;
    wire [4:0]mem_b_tgt_out_2;

    wire decode_is_load_out;
    wire decode_is_store_out;
    wire decode_is_branch_out;
    wire decode_is_post_inc_out;
    wire decode_is_atomic_out;
    wire decode_is_fetch_add_atomic_out;
    wire [1:0]decode_atomic_step_out;

    // Decode stage: instruction field extraction, immediate generation, and
    // source register read with dual writeback ports.
    decode decode(clk, flush, halt,
      mem_out_0, fetch_b_bubble_out, fetch_b_pc_out,
      reg_we_1, mem_b_tgt_out_1, reg_write_data_1,
      reg_we_2, mem_b_tgt_out_2, reg_write_data_2,
      exec_stall,
      decode_op1_out, decode_op2_out, decode_pc_out,
      decode_opcode_out, decode_s_1_out, decode_s_2_out, 
      decode_tgt_out_1, decode_tgt_out_2,
      decode_alu_op_out, decode_imm_out, decode_branch_code_out,
      decode_bubble_out, decode_halt_out, ret_val,
      decode_is_load_out, decode_is_store_out, decode_is_branch_out,
      decode_is_post_inc_out, decode_stall,
      decode_is_atomic_out, decode_is_fetch_add_atomic_out, decode_atomic_step_out);

    wire exec_bubble_out;
    wire [31:0]mem_a_result_out_1;
    wire [31:0]mem_a_result_out_2;
    wire [31:0]mem_b_result_out_1;
    wire [31:0]mem_b_result_out_2;
    wire [4:0]exec_opcode_out;
    wire [4:0]exec_tgt_out_1;
    wire [4:0]exec_tgt_out_2;
    wire exec_halt_out;
    wire [4:0]wb_tgt_out_1;
    wire [4:0]wb_tgt_out_2;
    wire [31:0]wb_result_out_1;
    wire [31:0]wb_result_out_2;
    wire [4:0]mem_a_opcode_out;
    wire [4:0]mem_b_opcode_out;

    wire exec_is_load_out;
    wire exec_is_store_out;

    wire mem_a_bubble_out;
    wire mem_b_bubble_out;
    wire mem_a_is_load_out;
    wire mem_b_is_load_out;
    
    assign curr_pc = decode_pc_out;
    // Execute stage: forwarding, hazard detection, ALU, branch resolve, and
    // registered memory request generation.
    execute execute(clk, halt, decode_bubble_out, mem_b_halt, 
      decode_opcode_out, decode_s_1_out, decode_s_2_out, 
      decode_tgt_out_1, decode_tgt_out_2,
      decode_alu_op_out, decode_imm_out, decode_branch_code_out,
      mem_a_tgt_out_1, mem_a_tgt_out_2,
      mem_b_tgt_out_1, mem_b_tgt_out_2, 
      wb_tgt_out_1, wb_tgt_out_2,
      decode_op1_out, decode_op2_out, 
      mem_a_result_out_1, mem_a_result_out_2,
      mem_b_result_out_1, mem_b_result_out_2, 
      wb_result_out_1, wb_result_out_2, 
      decode_pc_out, decode_halt_out, mem_b_opcode_out,
      decode_is_load_out, decode_is_store_out, decode_is_branch_out, 
      mem_a_bubble_out, mem_a_is_load_out, mem_b_bubble_out, mem_b_is_load_out,
      decode_is_post_inc_out,
      decode_is_atomic_out, decode_is_fetch_add_atomic_out, decode_atomic_step_out,

      exec_result_out_1, exec_result_out_2, 
      addr, store_data, mem_we,
      exec_opcode_out, exec_tgt_out_1, exec_tgt_out_2, exec_bubble_out, 
      branch, branch_tgt, exec_halt_out, flags, exec_stall,
      exec_is_load_out, exec_is_store_out);

    wire mem_a_is_store_out;
    wire [31:0]mem_a_addr_out;

    wire mem_b_is_store_out;
    wire [31:0]mem_b_addr_out;

    // Two MEM pipeline registers are used to align memory latency and to keep
    // writeback timing deterministic.
    memory memory_a(clk, halt,
      exec_bubble_out, exec_opcode_out, exec_tgt_out_1, exec_tgt_out_2,
      exec_result_out_1, exec_result_out_2, exec_halt_out, addr,
      exec_is_load_out, exec_is_store_out,

      mem_a_tgt_out_1, mem_a_tgt_out_2, 
      mem_a_result_out_1, mem_a_result_out_2,
      mem_a_opcode_out, mem_a_addr_out, mem_a_bubble_out, mem_a_halt,
      mem_a_is_load_out, mem_a_is_store_out);


    memory memory_b(clk, halt,
      mem_a_bubble_out, mem_a_opcode_out, mem_a_tgt_out_1, mem_a_tgt_out_2,
      mem_a_result_out_1, mem_a_result_out_2, mem_a_halt, mem_a_addr_out,
      mem_a_is_load_out, mem_a_is_store_out,

      mem_b_tgt_out_1, mem_b_tgt_out_2, 
      mem_b_result_out_1, mem_b_result_out_2,
      mem_b_opcode_out, mem_b_addr_out, mem_b_bubble_out, mem_b_halt,
      mem_b_is_load_out, mem_b_is_store_out);

    // Writeback stage: load lane selection/masking and final regfile enables.
    writeback writeback(clk, halt, mem_b_bubble_out, mem_b_tgt_out_1, mem_b_tgt_out_2,
      mem_b_is_load_out, mem_b_is_store_out,
      mem_b_opcode_out,
      mem_b_result_out_1, mem_b_result_out_2, mem_out_1, mem_b_addr_out,
      reg_write_data_1, reg_write_data_2,
      reg_we_1, wb_tgt_out_1, wb_result_out_1,
      reg_we_2, wb_tgt_out_2, wb_result_out_2);

    always @(posedge clk) begin
      halt <= halt ? 1 : mem_b_halt;
    end

endmodule
