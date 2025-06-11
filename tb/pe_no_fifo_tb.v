`timescale 1ns/1ps
module pe_no_fifo_tb;

    reg clk, rst_n;
    reg start, valid_in, last;
    reg [31:0] a, b;
    wire [31:0] c;
    wire output_valid;

    // Instantiate DUT
    pe_no_fifo dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .valid_in(valid_in),
        .last(last),
        .a(a),
        .b(b),
        .c(c),
        .output_valid(output_valid)
    );

    // Clock generation
    always #5 clk = ~clk;

    integer test_num;

    initial begin
        $display("Time\t\tTest\tResult(hex)\t\tOutput_Valid");
        clk = 0; rst_n = 0;
        start = 0; valid_in = 0; last = 0; a = 0; b = 0;
        #10 rst_n = 1;

        // Test 1: 3.5*2.0 + 1.5*4.0 = 7.0 + 6.0 = 13.0 (0x41500000)
        test_num = 1;
        @(posedge clk);
        start = 1; valid_in = 1; last = 0;
        a = 32'h40600000; b = 32'h40000000; // 3.5  * 2.0
        @(posedge clk);
        start = 0; valid_in = 1; last = 1;
        a = 32'h3FC00000; b = 32'h40800000; // 1.5  * 4.0
        @(posedge clk);
        valid_in = 0; last = 0;
        // Wait for pipeline to drain (3 cycles)
        repeat(3) @(posedge clk);
        $display("%0t\tTest %0d\t%h\t\t%b", $time, test_num, c, output_valid);

        // Test 2: -1.5*4.0 + 2.0*-3.5 = -6.0 + -7.0 = -13.0 (0xC1500000)
        test_num = 2;
        @(posedge clk);
        start = 1; valid_in = 1; last = 0;
        a = 32'hBFC00000; b = 32'h40800000; // -1.5 * 4.0
        @(posedge clk);
        start = 0; valid_in = 1; last = 1;
        a = 32'h40000000; b = 32'hC0600000; // 2.0  * -3.5
        @(posedge clk);
        valid_in = 0; last = 0;
        repeat(3) @(posedge clk);
        $display("%0t\tTest %0d\t%h\t\t%b", $time, test_num, c, output_valid);

        // Test 3: 0*5.0 + 2.0*0 = 0.0 + 0.0 = 0.0 (0x00000000)
        test_num = 3;
        @(posedge clk);
        start = 1; valid_in = 1; last = 0;
        a = 32'h00000000; b = 32'h40A00000; // 0 * 5.0
        @(posedge clk);
        start = 0; valid_in = 1; last = 1;
        a = 32'h40000000; b = 32'h00000000; // 2.0 * 0
        @(posedge clk);
        valid_in = 0; last = 0;
        repeat(3) @(posedge clk);
        $display("%0t\tTest %0d\t%h\t\t%b", $time, test_num, c, output_valid);

        // Test 4: INF*2.0 + 0*1.0 = INF + 0 = INF (0x7F800000)
        test_num = 4;
        @(posedge clk);
        start = 1; valid_in = 1; last = 0;
        a = 32'h7F800000; b = 32'h40000000; // INF * 2.0
        @(posedge clk);
        start = 0; valid_in = 1; last = 1;
        a = 32'h00000000; b = 32'h3F800000; // 0 * 1.0
        @(posedge clk);
        valid_in = 0; last = 0;
        repeat(3) @(posedge clk);
        $display("%0t\tTest %0d\t%h\t\t%b", $time, test_num, c, output_valid);

        // Test 5: NaN*1.0 + 1.0*NaN = NaN + NaN = NaN (0x7FC00000 or similar)
        test_num = 5;
        @(posedge clk);
        start = 1; valid_in = 1; last = 0;
        a = 32'h7FC00000; b = 32'h3F800000; // NaN * 1.0
        @(posedge clk);
        start = 0; valid_in = 1; last = 1;
        a = 32'h3F800000; b = 32'h7FC00000; // 1.0 * NaN
        @(posedge clk);
        valid_in = 0; last = 0;
        repeat(3) @(posedge clk);
        $display("%0t\tTest %0d\t%h\t\t%b", $time, test_num, c, output_valid);

        #20 $finish;
    end
endmodule
