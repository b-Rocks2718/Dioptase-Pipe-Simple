`timescale 1ps/1ps

// Decode stage.
//
// Purpose:
// - Parse instruction fields from fetch.
// - Generate immediates and per-op control bits.
// - Read source operands from regfile.
// - Register decode outputs into the execute boundary.
//
// Stall behavior:
// - Instruction memory is pipelined, so decode keeps a local `mem_out_buf`.
// - `exec_stall` and decode-side crack stalls use this buffer so a held slot
//   keeps decoding the same instruction bits across repeated cycles.
// - `was_decode_stall` distinguishes first-cycle crack stall (capture buffer)
//   from continued crack stall (hold buffer).
module decode(input clk,
    input flush, input halt,

    input [31:0]mem_out_0, input bubble_in, input [31:0]pc_in,

    input we1, input [4:0]target_1, input [31:0]write_data_1,
    input we2, input [4:0]target_2, input [31:0]write_data_2,

    input exec_stall,

    output [31:0]d_1, output [31:0]d_2, output reg [31:0]pc_out,
    output reg [4:0]opcode_out, output reg [4:0]s_1_out, output reg [4:0]s_2_out, 
    output reg [4:0]tgt_out_1, output reg [4:0]tgt_out_2,
    output reg [4:0]alu_op_out, output reg [31:0]imm_out, output reg [4:0]branch_code_out,
    output reg bubble_out, output reg halt_out, output [31:0]ret_val,
    output reg is_load_out, output reg is_store_out, output reg is_branch_out,
    output reg is_post_inc_out, output decode_stall,
    output reg is_atomic_out, output reg is_fetch_add_atomic_out,
    output reg [1:0]atomic_step_out
  );

  reg was_stall;
  reg was_was_stall;
  reg was_decode_stall;

  wire [31:0]instr_in;
  reg  [31:0]instr_buf;

  reg [31:0]mem_out_buf;
  // Replay buffered instruction while any stall history is active.
  assign instr_in = (was_stall || was_was_stall || was_decode_stall) ? mem_out_buf : mem_out_0;

  wire [4:0]opcode = instr_in[31:27];

  // Branch-and-link register forms encode rA/rB in low bits.
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

  // Atomic opcode families from docs/ISA.md.
  wire is_fetch_add = (opcode == 5'd16 || opcode == 5'd17 || opcode == 5'd18);
  wire is_swap_abs = (opcode == 5'd19);
  wire is_swap_rel = (opcode == 5'd20);
  wire is_swap_imm = (opcode == 5'd21);
  wire is_swap = is_swap_abs || is_swap_rel || is_swap_imm;
  wire is_fetch_add_v = (is_fetch_add == 1'b1);
  wire is_swap_v = (is_swap == 1'b1);

  reg [1:0]fetch_add_step; // 0 => load, 1 => add, 2 => store
  reg [1:0]swap_step; // 0 => load, 1 => store

  // swap rA, rC [rB, i] =>
  //    lw   rA, [rB, i]
  //    sw   rC, [rB, i]

  // fetch_add rA, rC [rB, i] =>
  //    lw   rA, [rB, i]
  //    add  rA, rC, rA
  //    sw   rA, [rB, i]

  // Backpressure fetch/decode while atomic crack sequences are in flight.
  // swap uses 2 steps (load, store); fetch_add uses 3 (load, add, store).
  assign decode_stall =
    ((is_fetch_add_v && (fetch_add_step != 2'd2)) || (is_swap_v && (swap_step != 2'd1))) && !bubble_in;

  // 0 => offset, 1 => preincrement, 2 => postincrement
  wire [1:0]increment_type = instr_in[15:14];

  wire [1:0]mem_shift = instr_in[13:12];

  // Absolute memory opcodes can write both destination and updated base.
  wire is_absolute_mem = opcode == 5'd3 || opcode == 5'd6 || opcode == 5'd9;

  // swap cracking:
  //   step 0: decode as load word (read old value into rA)
  //   step 1: decode as store word (write rC back to same address)
  wire [4:0]swap_mem_opcode = is_swap_abs ? 5'd3 : (is_swap_rel ? 5'd4 : 5'd5);
  // assembler/simple-emulator encoding places swap rC in [21:17]
  // and swap rB in [16:12] for absolute/relative forms.
  wire [4:0]swap_base = (is_swap_abs || is_swap_rel) ? instr_in[16:12] : 5'd0;
  wire [4:0]swap_data = instr_in[21:17];
  wire [31:0]swap_imm = is_swap_imm ?
    { {15{instr_in[16]}}, instr_in[16:0] } :
    { {20{instr_in[11]}}, instr_in[11:0] };

  wire swap_load_step = is_swap_v && (swap_step == 2'd0);
  wire swap_store_step = is_swap_v && (swap_step == 2'd1);

  // fetch-add cracking:
  //   step 0: decode as load word
  //   step 1: decode as ALU add (rA <- rC + rA)
  //   step 2: decode as store word
  wire fetch_add_load_step = is_fetch_add_v && (fetch_add_step == 2'd0);
  wire fetch_add_add_step = is_fetch_add_v && (fetch_add_step == 2'd1);
  wire fetch_add_store_step = is_fetch_add_v && (fetch_add_step == 2'd2);

  wire [4:0]fetch_add_mem_opcode = (opcode == 5'd16) ? 5'd3 :
                                   (opcode == 5'd17) ? 5'd4 : 5'd5;
  wire [4:0]fetch_add_base = (opcode == 5'd18) ? 5'd0 : instr_in[16:12];
  wire [4:0]fetch_add_data = instr_in[21:17];
  wire [31:0]fetch_add_imm = (opcode == 5'd18) ?
    { {15{instr_in[16]}}, instr_in[16:0] } :
    { {20{instr_in[11]}}, instr_in[11:0] };

  // Select source slot 1 register. Many opcodes use implicit zero for src1.
  wire [4:0]base_s_1 = (opcode == 5'd2 || opcode == 5'd5 || opcode == 5'd8
                     || opcode == 5'd11 || opcode == 5'd12 || opcode == 5'd15 ||
                     ((opcode == 5'd0 || opcode == 5'd1) && alu_op == 5'd6)) ? 5'd0 : r_b;
  
  // store instructions read from r_a instead of writing there
  // only alu-reg instructions use r_c as a source
  wire [4:0]base_s_2 = is_store ? r_a : ((opcode == 5'd0) ? r_c : 5'd0);

  // Cracked atomic micro-ops override opcode and source register selection.
  wire [4:0]decode_opcode =
    is_swap_v ? swap_mem_opcode :
    is_fetch_add_v ? (fetch_add_add_step ? 5'd0 : fetch_add_mem_opcode) :
    opcode;
  wire [4:0]s_1 =
    is_swap_v ? swap_base :
    is_fetch_add_v ? (fetch_add_add_step ? fetch_add_data : fetch_add_base) :
    base_s_1;
  wire [4:0]s_2 =
    is_swap_v ? swap_data :
    is_fetch_add_v ? (fetch_add_load_step ? fetch_add_data :
                     (fetch_add_add_step ? r_a : (fetch_add_store_step ? r_a : 5'd0))) :
    base_s_2;

  regfile regfile(clk,
        s_1, d_1,
        s_2, d_2,
        we1, target_1, write_data_1,
        we2, target_2, write_data_2,
        exec_stall, ret_val);

  // ISA immediate decode. Width/sign/shift depend on opcode family.
  wire [31:0]base_imm =
    (opcode == 5'd1 && is_bitwise) ? { 24'b0, instr_in[7:0] } << alu_shift : // zero extend, then shift
    (opcode == 5'd1 && is_shift) ? { 27'b0, instr_in[4:0] } : // zero extend 5 bit
    (opcode == 5'd1 && is_arithmetic) ? { {20{instr_in[11]}}, instr_in[11:0] } : // sign extend 12 bit
    (opcode == 5'd2) ? {instr_in[21:0], 10'b0} : // shift left 
    opcode == 5'd12 ? { {10{instr_in[21]}}, instr_in[21:0] } : // sign extend 22 bit
    is_absolute_mem ? { {20{instr_in[11]}}, instr_in[11:0] } << mem_shift : // sign extend 12 bit with shift
    (opcode == 5'd4 || opcode == 5'd7 || opcode == 5'd10) ? { {16{instr_in[15]}}, instr_in[15:0] } : // sign extend 16 bit 
    (opcode == 5'd5 || opcode == 5'd8 || opcode == 5'd11) ? { {11{instr_in[20]}}, instr_in[20:0] } : // sign extend 21 bit 
    (opcode == 5'd22) ? { {10{instr_in[21]}}, instr_in[21:0] } : // sign extend 22 bit
    32'd0;

  wire [31:0]imm =
    is_swap_v ? swap_imm :
    is_fetch_add_v ? (fetch_add_add_step ? 32'd0 : fetch_add_imm) :
    base_imm;

  wire [4:0]decode_alu_op =
    (is_fetch_add_v && fetch_add_add_step) ? 5'd14 : alu_op;

  wire decode_is_load =
    is_swap_v ? swap_load_step :
    is_fetch_add_v ? fetch_add_load_step :
    is_load;
  wire decode_is_store =
    is_swap_v ? swap_store_step :
    is_fetch_add_v ? fetch_add_store_step :
    is_store;
  wire decode_is_branch = (is_swap_v || is_fetch_add_v) ? 1'b0 : is_branch;
  wire decode_is_atomic = is_swap_v || is_fetch_add_v;
  wire decode_is_fetch_add_atomic = is_fetch_add_v;
  wire [1:0]decode_atomic_step = is_fetch_add_v ? fetch_add_step : swap_step;
  wire decode_is_absolute_mem =
    !is_swap_v && !is_fetch_add_v &&
    (decode_opcode == 5'd3 || decode_opcode == 5'd6 || decode_opcode == 5'd9);

  initial begin
    bubble_out = 1;
    tgt_out_1 = 5'b00000;
    tgt_out_2 = 5'b00000;

    was_stall = 0;
    was_was_stall = 0;
    was_decode_stall = 0;
    mem_out_buf = 0;
    instr_buf = 0;

    fetch_add_step = 0;
    swap_step = 0;
    is_atomic_out = 0;
    is_fetch_add_atomic_out = 0;
    atomic_step_out = 0;
  end

  always @(posedge clk) begin
    if (~halt) begin
      if (~exec_stall) begin 
        opcode_out <= decode_opcode;
        s_1_out <= s_1;
        s_2_out <= s_2;

        tgt_out_1 <= (flush || bubble_in || decode_is_store) ? 5'b0 : r_a;
        tgt_out_2 <= (flush || bubble_in || !decode_is_absolute_mem || increment_type == 2'd0) ? 5'b0 : r_b;

        imm_out <= imm;
        branch_code_out <= branch_code;
        alu_op_out <= decode_alu_op;
        bubble_out <= flush ? 1 : bubble_in;
        pc_out <= pc_in;
        halt_out <= (opcode == 5'b01111) && (instr_in[6:0] == 7'b1) && !bubble_in;

        is_load_out <= decode_is_load;
        is_store_out <= decode_is_store;
        is_branch_out <= decode_is_branch;
        is_post_inc_out <= decode_is_absolute_mem && (increment_type == 2'd2);
        is_atomic_out <= (flush || bubble_in) ? 1'b0 : decode_is_atomic;
        is_fetch_add_atomic_out <= (flush || bubble_in) ? 1'b0 : decode_is_fetch_add_atomic;
        atomic_step_out <= (flush || bubble_in) ? 2'd0 : decode_atomic_step;

        if (flush || bubble_in) begin
          fetch_add_step <= 2'd0;
          swap_step <= 1'b0;
        end else begin
          // fetch_add is a 3-step crack sequence: load -> add -> store.
          if (is_fetch_add_v) begin
            fetch_add_step <= (fetch_add_step == 2'd2) ? 2'd0 : (fetch_add_step + 2'd1);
          end else begin
            fetch_add_step <= 2'd0;
          end

          // swap is a 2-step crack sequence: load -> store.
          if (is_swap_v) begin
            swap_step <= (swap_step == 2'd1) ? 2'd0 : (swap_step + 2'd1);
          end else begin
            swap_step <= 2'd0;
          end
        end

        instr_buf <= instr_in;
      end

  // Keep a copy of instruction memory output for multi-cycle stalls.
  // For decode-side stalls (atomic cracking), capture on stall entry and
  // then hold the buffered instruction through the rest of the sequence.
      if (!(exec_stall && was_stall) && !(decode_stall && was_decode_stall)) begin
        mem_out_buf <= mem_out_0;
      end
      was_stall <= exec_stall;
      was_was_stall <= was_stall;
      was_decode_stall <= decode_stall;
    end
  end

endmodule
