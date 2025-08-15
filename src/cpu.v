`timescale 1ps/1ps

module pipelined_cpu(
  input clk, output mem_read_en,
  output [31:0]mem_read0_addr, input [31:0]mem_read0_data,
  output [31:0]mem_read1_addr, input [31:0]mem_read1_data,
  output mem_write_en, output [31:0]mem_write_addr, output [31:0]mem_write_data,
  output [31:0]ret_val, output [3:0]flags, output [31:0]curr_pc
);

    reg halt = 0;

`ifdef SIMULATION
    counter ctr(halt, clk, ret_val);
`endif

    // read from memory
    wire [31:0]fetch_instr_out;
    wire [31:0]mem_out_1;
    wire [31:0]fetch_addr;
    wire [31:0]mem_out_2;

    wire mem_we;
    wire [31:0]exec_result_out;
    wire [31:0]addr;
    wire [31:0]store_data;

    wire [31:0]reg_write_data;
    wire reg_we;

    wire branch;
    wire flush;
    wire mem_halt;
    assign flush = branch || mem_halt;

    reg mem_ren = 1;
    assign mem_read_en = mem_ren;
    assign mem_read0_addr = fetch_addr;
    assign mem_read1_addr = addr;
    assign mem_out_1 = mem_read0_data;
    assign mem_out_2 = mem_read1_data;
    assign mem_write_en = mem_we;
    assign mem_write_addr = addr;
    assign mem_write_data = store_data;

    wire stall;
    wire [31:0]branch_tgt;
    wire [31:0]decode_pc_out;
    wire [31:0]fetch_a_pc_out;
    wire fetch_a_bubble_out;

    fetch_a fetch_a(clk, stall | halt, flush, branch, branch_tgt,
      fetch_addr, fetch_a_pc_out, fetch_a_bubble_out);

    wire fetch_b_bubble_out;
    wire [31:0]fetch_b_pc_out;

    fetch_b fetch_b(clk, stall | halt, flush, fetch_a_bubble_out, fetch_a_pc_out,
      fetch_b_bubble_out, fetch_b_pc_out);

    wire [31:0] decode_op1_out;
    wire [31:0] decode_op2_out;

    wire [2:0] decode_opcode_out;
    wire [2:0] decode_s_1_out;
    wire [2:0] decode_s_2_out;
    wire [2:0] decode_tgt_out;
    wire [3:0] decode_alu_op_out;
    wire [15:0] decode_imm_out;
    wire [5:0] decode_branch_code_out;
    
    wire decode_bubble_out;
    wire decode_halt_out;
    wire [2:0]mem_tgt_out;

    decode decode(clk, flush, halt,
      mem_out_1, fetch_b_bubble_out, fetch_b_pc_out,
      reg_we, mem_tgt_out, reg_write_data,
      decode_op1_out, decode_op2_out, decode_pc_out,
      decode_opcode_out, decode_s_1_out, decode_s_2_out, decode_tgt_out,
      decode_alu_op_out, decode_imm_out, decode_branch_code_out,
      decode_bubble_out, stall, decode_halt_out, ret_val);

    wire exec_bubble_out;
    wire [31:0]mem_result_out;
    wire [2:0]exec_opcode_out;
    wire [2:0]exec_tgt_out;
    wire exec_halt_out;
    wire [2:0]wb_tgt_out;
    wire [31:0]wb_result_out;
    wire [2:0]mem_opcode_out;
    
    assign curr_pc = decode_pc_out;
    execute execute(clk, halt, decode_bubble_out, mem_halt, 
      decode_opcode_out, decode_s_1_out, decode_s_2_out, decode_tgt_out,
      decode_alu_op_out, decode_imm_out, decode_branch_code_out,
      mem_tgt_out, wb_tgt_out, decode_op1_out, decode_op2_out, mem_result_out, wb_result_out, decode_pc_out,
      decode_halt_out, mem_opcode_out, mem_out_2,

      exec_result_out, addr, store_data, mem_we, exec_opcode_out, exec_tgt_out, exec_bubble_out, 
      branch, branch_tgt, exec_halt_out, flags);

    wire mem_bubble_out;

    memory memory(clk, halt,
      exec_bubble_out, exec_opcode_out, exec_tgt_out, exec_result_out, exec_halt_out,
      mem_tgt_out, mem_opcode_out, mem_result_out, mem_bubble_out, mem_halt);

    writeback writeback(clk, halt, mem_bubble_out, mem_tgt_out, mem_opcode_out, mem_result_out, mem_out_2,
      reg_write_data, reg_we, wb_tgt_out, wb_result_out);

    always @(posedge clk) begin
      halt <= halt ? 1 : mem_halt;
    end

endmodule