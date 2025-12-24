`timescale 1ps/1ps

module counter(input isHalt, input clk, input [31:0]ret_val);

    reg [31:0] count = 0;
    integer cycle_limit;

    initial begin
        if (!$value$plusargs("cycle_limit=%d", cycle_limit)) begin
            cycle_limit = 500;
        end
    end

    always @(posedge clk) begin
        if (isHalt) begin
            // $fdisplay(32'h8000_0002,"%d\n",count);
            $display("%08h", ret_val);
            $finish;
        end
        if (cycle_limit != 0 && count >= cycle_limit) begin
            $display("ran for %0d cycles", cycle_limit);
            $finish;
        end
        count <= count + 1;
    end

endmodule
