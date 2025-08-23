`timescale 1ps/1ps

module counter(input isHalt, input clk, input [31:0]ret_val);

    reg [31:0] count = 0;

    always @(posedge clk) begin
        if (isHalt) begin
            // $fdisplay(32'h8000_0002,"%d\n",count);
            $display("%08h", ret_val);
            $finish;
        end
        if (count == 500) begin
            $display("ran for 500 cycles");
            $finish;
        end
        count <= count + 1;
    end

endmodule