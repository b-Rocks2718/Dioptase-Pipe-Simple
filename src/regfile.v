`timescale 1ps/1ps

// Integer register file.
//
// Properties:
// - 32 architectural registers with two read ports and two write ports.
// - Read side enforces r0 == 0.
// - Write port 1 has priority over write port 0 on same destination.
// - `ret_val` exposes r1 for testbench termination reporting.
module regfile(input clk,
    input [4:0]raddr0, output reg [31:0]rdata0,
    input [4:0]raddr1, output reg [31:0]rdata1,
    input wen0, input [4:0]waddr0, input [31:0]wdata0, 
    input wen1, input [4:0]waddr1, input [31:0]wdata1,
    input stall, output [31:0]ret_val);

  reg [31:0]regfile[0:5'b11111];
  integer i;

  // Keep the reset stack pointer inside mem.v's 64K-word RAM window:
  // 65536 words * 4 bytes = 0x0004_0000 bytes total, so choose a high
  // in-range address (with headroom for small negative offsets).
  localparam [31:0]RAM_BYTES = 32'h0004_0000;
  localparam [31:0]STACK_PTR_RESET = RAM_BYTES - 32'h10;

  initial begin
    for (i = 0; i < 32; i = i + 1) begin
      regfile[i] = 32'b0; // initialize registers to 0
    end
    regfile[5'd31] = STACK_PTR_RESET;
    rdata0 = 32'b0;
    rdata1 = 32'b0;
  end

  // compiler puts return value in r1
  // expose it here to allow for testing
  assign ret_val = regfile[5'd1];

  always @(posedge clk) begin
    if (wen0) begin
        regfile[waddr0] <= wdata0;
    end
    if (wen1) begin
        // Port 1 is used by pre/post-increment base writeback. If both
        // ports target the same register, port 1 wins to match emulator
        // ordering (mem op destination write then base writeback).
        regfile[waddr1] <= wdata1;
    end

    if (!stall) begin
      rdata0 <= (raddr0 == 0) ? 32'b0 : regfile[raddr0];
      rdata1 <= (raddr1 == 0) ? 32'b0 : regfile[raddr1];
    end

  end

endmodule
