`timescale 1ps/1ps

module dioptase();

    reg reset = 0;
    wire clk;

    reg [1023:0] vcdfile;
    initial begin
      if ($value$plusargs("vcd=%s", vcdfile)) begin
        $dumpfile(vcdfile);
      end else begin
        $dumpfile("cpu.vcd");
      end
      $dumpvars(0, dioptase);
    end

    clock c0(clk);

    // Memory
    wire [31:0]mem_read0_addr;
    wire [31:0]mem_read0_data;
    wire [31:0]mem_read1_addr;
    wire [31:0]mem_read1_data;
    wire [3:0]mem_write_en;
    wire [31:0]mem_write_addr;
    wire [31:0]mem_write_data;

    mem mem(.clk(clk), 
        .raddr0(mem_read0_addr), .rdata0(mem_read0_data),
        .raddr1(mem_read1_addr), .rdata1(mem_read1_data),
        .wen(mem_write_en), .waddr(mem_write_addr), .wdata(mem_write_data)
    );

    // CPU
    wire [31:0]ret_val;
    wire [31:0]cpu_pc;
    wire [3:0]flags;

    pipelined_cpu cpu(
        clk,
        mem_read0_addr, mem_read0_data,
        mem_read1_addr, mem_read1_data,
        mem_write_en, mem_write_addr, mem_write_data,
        ret_val, flags, cpu_pc
    );

endmodule