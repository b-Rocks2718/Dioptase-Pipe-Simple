`timescale 1ps/1ps

// Simple free-running simulation clock.
// Period is 1000 ps (1 GHz in this timescale).
module clock(output clk);
    reg theClock = 1;

    assign clk = theClock;
    
    always begin
        #500;
        theClock = !theClock;
    end
endmodule
