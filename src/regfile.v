`timescale 1ps/1ps

module regfile(input clk,
    input [4:0]raddr0, output reg [31:0]rdata0,
    input [4:0]raddr1, output reg [31:0]rdata1,
    input wen0, input [4:0]waddr0, input [31:0]wdata0, 
    input wen1, input [4:0]waddr1, input [31:0]wdata1,
    input stall, output [31:0]ret_val);

  reg [31:0]regfile[0:5'b11111];

  // compiler puts return value in r3
  // expose it here to allow for testing
  assign ret_val = regfile[5'd3];

  always @(posedge clk) begin
    if (wen0) begin
        regfile[waddr0] <= wdata0;
    end
    if (wen1 && waddr0 != waddr1) begin // load data takes precedence over address
        // 2nd write port used for pre/post increment memory operations
        regfile[waddr1] <= wdata1;
    end

    if (!stall) begin
      rdata0 <= (raddr0 == 0) ? 32'b0 : regfile[raddr0];
      rdata1 <= (raddr1 == 0) ? 32'b0 : regfile[raddr1];
    end

  end

endmodule