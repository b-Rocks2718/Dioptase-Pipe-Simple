`timescale 1ps/1ps

module mem(input clk,
    input [31:0]raddr0, output reg [31:0]rdata0,
    input [31:0]raddr1, output reg [31:0]rdata1,
    input [3:0]wen, input [31:0]waddr, input [31:0]wdata
);

    // limited memory address range for now
    reg [31:0]ram[0:16'hffff];

    reg [1023:0] hexfile; // buffer for filename

    initial begin
        if (!$value$plusargs("hex=%s", hexfile)) begin
            $display("ERROR: no +hex=<file> argument given!");
            $finish;
        end
        $readmemh(hexfile, ram);  // mem is your instruction/data memory
    end

    reg wen_buf;

    reg [31:0]data0_out;
    reg [31:0]data1_out;

    always @(posedge clk) begin

      wen_buf <= wen;

      data0_out <= ram[raddr0[15:2]];
      data1_out <= ram[raddr1[15:2]];

      rdata0 <= data0_out;
      rdata1 <= data1_out;

      if (wen[0]) ram[waddr[15:2]][7:0]   <= wdata[7:0];
      if (wen[1]) ram[waddr[15:2]][15:8]  <= wdata[15:8];
      if (wen[2]) ram[waddr[15:2]][23:16] <= wdata[23:16];
      if (wen[3]) ram[waddr[15:2]][31:24] <= wdata[31:24];
    end

endmodule