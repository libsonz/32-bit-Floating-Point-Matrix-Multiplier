`timescale 1ns / 1ps
module adder_tb;
    reg clk;
    reg rst;
    reg [31:0] i_a, i_b;
    reg i_vld;
    wire [31:0] o_res;
    wire o_res_vld;
    wire overflow;

    adder_32bit dut (
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
        $monitor("Time=%0t i_a=%b i_b=%b o_res=%b o_res_vld=%b overflow=%b",
                 $time, i_a, i_b, o_res, o_res_vld, overflow);
        
        clk = 0;
        rst = 1;
        i_vld = 0;
        #10 rst = 0;

        // Test Case 1: Addition of two normal numbers
        i_a = 32'h40600000; // 3.5
        i_b = 32'hC0100000; // -2.25
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 2: Addition of two positive numbers
        i_a = 32'h3F800000; // 1.0
        i_b = 32'h40000000; // 2.0
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 3: Addition of positive and negative numbers
        i_a = 32'hC0900000; // -4.5
        i_b = 32'h40200000; // 2.5
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 4: Addition of small numbers
        i_a = 32'h3F000000; // 0.5
        i_b = 32'h3E800000; // 0.25
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 5: Addition of +0.0 and -0.0
        i_a = 32'h80000000; // -0.0
        i_b = 32'h00000000; // +0.0
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 6: Addition with NaN
        i_a = 32'h7FC00000; // NaN (Quiet NaN)
        i_b = 32'h3F800000; // 1.0
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 7: Addition with positive infinity
        i_a = 32'h7F800000; // +Infinity
        i_b = 32'h3F800000; // 1.0
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 8: Addition with negative infinity
        i_a = 32'hFF800000; // -Infinity
        i_b = 32'h3F800000; // 1.0
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 9: +Infinity + +Infinity
        i_a = 32'h7F800000; // +Infinity
        i_b = 32'h7F800000; // +Infinity
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 10: -Infinity + -Infinity
        i_a = 32'hFF800000; // -Infinity
        i_b = 32'hFF800000; // -Infinity
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 11: +Infinity + -Infinity → NaN
        i_a = 32'h7F800000; // +Infinity
        i_b = 32'hFF800000; // -Infinity
        i_vld = 1;
        #10 i_vld = 0;
        
        // Test Case 12: -Infinity + +Infinity → NaN
        i_a = 32'hFF800000; // -Infinity
        i_b = 32'h7F800000; // +Infinity
        i_vld = 1;
        #10 i_vld = 0;

        #50;
        $finish;
    end
endmodule

