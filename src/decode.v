`timescale 1ps/1ps

module decode(input clk,
    input flush, input halt,

    input [31:0]mem_out_0, input bubble_in, input [31:0]pc_in,

    input we1, input [4:0]target_1, input [31:0]write_data_1,
    input we2, input [4:0]target_2, input [31:0]write_data_2,

    input stall,

    output [31:0]d_1, output [31:0]d_2, output reg [31:0]pc_out,
    output reg [4:0]opcode_out, output reg [4:0]s_1_out, output reg [4:0]s_2_out, 
    output reg [4:0]tgt_out_1, output reg [4:0]tgt_out_2,
    output reg [4:0]alu_op_out, output reg [31:0]imm_out, output reg [4:0]branch_code_out,
    output reg bubble_out, output reg halt_out, output [31:0]ret_val,
    output reg is_load_out, output reg is_store_out, output reg is_branch_out,
    output reg is_post_inc_out
  );

  reg was_stall;
  reg was_was_stall;

  wire [31:0]instr_in;
  reg [31:0]instr_buf;
  assign instr_in = (was_stall || was_was_stall) ? instr_buf : mem_out_0;

  wire [4:0]opcode = instr_in[31:27];

  // branch instruction has r_a and r_b in a different spot than normal
  wire [4:0]r_a = (opcode == 5'd13 || opcode == 5'd14) ? instr_in[9:5] : instr_in[26:22];
  wire [4:0]r_b = (opcode == 5'd13 || opcode == 5'd14) ? instr_in[4:0] : instr_in[21:17];
  
  // alu_op location is different for alu-reg and alu-imm instructions
  wire [4:0]alu_op = (opcode == 5'd0) ? instr_in[9:5] : instr_in[16:12];
  
  wire is_bitwise = (5'd0 <= alu_op && alu_op <= 5'd6);
  wire is_shift = (5'd7 <= alu_op && alu_op <= 5'd13);
  wire is_arithmetic = (5'd14 <= alu_op && alu_op <= 5'd18);

  wire [4:0]alu_shift = { instr_in[9:8], 3'b0};

  wire [4:0]r_c = instr_in[4:0];

  wire [4:0]branch_code = instr_in[26:22];

  // bit to distinguish loads from stores
  wire load_bit = (opcode == 5'd5 || opcode == 5'd8 || opcode == 5'd11) ? 
                  instr_in[21] : instr_in[16];

  wire is_mem = (5'd3 <= opcode && opcode <= 5'd11);
  wire is_branch = (5'd12 <= opcode && opcode <= 5'd14);

  wire is_load = is_mem && load_bit;
  wire is_store = is_mem && !load_bit;

  // 0 => offset, 1 => preincrement, 2 => postincrement
  wire [1:0]increment_type = instr_in[15:14];

  wire [1:0]mem_shift = instr_in[13:12];

  // possibility of making two writes to regfile (pre/postincremnt)
  wire is_absolute_mem = opcode == 5'd3 || opcode == 5'd6 || opcode == 5'd9;

  // some instructions don't read from r_b
  wire [4:0]s_1 = (opcode == 5'd2 || opcode == 5'd5 || opcode == 5'd8
                || opcode == 5'd11 || opcode == 5'd12 || opcode == 5'd15 ||
                ((opcode == 5'd0 || opcode == 5'd1) && alu_op == 5'd6)) ? 5'd0 : r_b;
  
  // store instructions read from r_a instead of writing there
  // only alu-reg instructions use r_c as a source
  wire [4:0]s_2 = is_store ? r_a : ((opcode == 5'd0) ? r_c : 5'd0);

  regfile regfile(clk,
        s_1, d_1,
        s_2, d_2,
        we1, target_1, write_data_1,
        we2, target_2, write_data_2,
        stall, ret_val);

  wire [31:0]imm = 
    (opcode == 5'd1 && is_bitwise) ? { 24'b0, instr_in[7:0] } << alu_shift : // zero extend, then shift
    (opcode == 5'd1 && is_shift) ? { 27'b0, instr_in[4:0] } : // zero extend 5 bit
    (opcode == 5'd1 && is_arithmetic) ? { {20{instr_in[11]}}, instr_in[11:0] } : // sign extend 12 bit
    (opcode == 5'd2) ? {instr_in[21:0], 10'b0} : // shift left 
    opcode == 5'd12 ? { {10{instr_in[21]}}, instr_in[21:0] } : // sign extend 22 bit
    is_absolute_mem ? { {20{instr_in[11]}}, instr_in[11:0] } << mem_shift : // sign extend 12 bit with shift
    (opcode == 5'd4 || opcode == 5'd7 || opcode == 5'd10) ? { {16{instr_in[15]}}, instr_in[15:0] } : // sign extend 16 bit 
    (opcode == 5'd5 || opcode == 5'd8 || opcode == 5'd11) ? { {11{instr_in[20]}}, instr_in[20:0] } : // sign extend 21 bit 
    32'd0;

  initial begin
    bubble_out = 1;
    tgt_out_1 = 5'b00000;
    tgt_out_2 = 5'b00000;
  end

  always @(posedge clk) begin
    if (~halt) begin
      if (~stall) begin 
        opcode_out <= opcode;
        s_1_out <= s_1;
        s_2_out <= s_2;

        tgt_out_1 <= (flush || bubble_in || is_store) ? 5'b0 : r_a;
        tgt_out_2 <= (flush || bubble_in || !is_absolute_mem || increment_type == 5'd0) ? 5'b0 : r_b;

        imm_out <= imm;
        branch_code_out <= branch_code;
        alu_op_out <= alu_op;
        bubble_out <= flush ? 1 : bubble_in;
        pc_out <= pc_in;
        halt_out <= (opcode == 5'b01111) && (instr_in[6:0] == 7'b0) && !bubble_in;

        is_load_out <= is_load;
        is_store_out <= is_store;
        is_branch_out <= is_branch;
        is_post_inc_out <= is_absolute_mem && increment_type == 2;
      end

      // lol experimental programming W
      if (!(stall && was_stall)) begin
        instr_buf <= mem_out_0;
      end
      was_stall <= stall;
      was_was_stall <= was_stall;
    end
  end

endmodule