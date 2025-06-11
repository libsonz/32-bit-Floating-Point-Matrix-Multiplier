`timescale 1ns / 1ps
module multiplier_tb();

    reg clk, rst;
    reg [31:0] i_a, i_b;
    reg i_vld;
    wire [31:0] o_res;
    wire o_res_vld;
    wire overflow;

    // Instantiate DUT
    multiplier_32bit dut (
        .clk(clk),
        .rst(rst),
        .i_a(i_a),
        .i_b(i_b),
        .i_vld(i_vld),
        .o_res(o_res),
        .o_res_vld(o_res_vld),
        .overflow(overflow)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $display("Time\t\tA\t\tB\t\tResult\t\t\tOverflow");
        clk = 0; rst = 1; i_vld = 0;
        #10 rst = 0;

        // Test Case 1: 3.5 * 2.0 = 7.0
        #10 i_a = 32'h40600000; i_b = 32'h40000000; i_vld = 1;  // 3.5 * 2.0
        #10 i_vld = 0;

        // Test Case 2: -1.5 * 4.0 = -6.0
        #10 i_a = 32'hBFC00000; i_b = 32'h40800000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 3: 0 * 5.0 = 0
        #10 i_a = 32'h00000000; i_b = 32'h40A00000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 4: INF * 2.0 = INF
        #10 i_a = 32'h7F800000; i_b = 32'h40000000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 5: -INF * 2.0 = -INF
        #10 i_a = 32'hFF800000; i_b = 32'h40000000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 6: INF * 0 = NaN
        #10 i_a = 32'h7F800000; i_b = 32'h00000000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 7: NaN * 1.0 = NaN
        #10 i_a = 32'h7FC00001; i_b = 32'h3F800000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 8: 1e20 * 1e20 = overflow
        #10 i_a = 32'h5A0A1F0A; i_b = 32'h5A0A1F0A; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 9: -3.0 * -2.0 = 6.0
        #10 i_a = 32'hC0400000; i_b = 32'hC0000000; i_vld = 1;
        #10 i_vld = 0;

        // Test Case 10: 1.0 * 1.0 = 1.0
        #10 i_a = 32'h3F800000; i_b = 32'h3F800000; i_vld = 1;
        #10 i_vld = 0;

        // Wait and finish
        #50 $finish;
    end
endmodule

