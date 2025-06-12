`timescale 1ns / 1ps

module adder_tb();

    reg clk, rst;
    reg [31:0] i_a, i_b;
    reg i_vld;
    wire [31:0] o_res;
    wire o_res_vld;
    wire overflow;

    integer pass_count = 0;
    integer fail_count = 0;
    integer test_num = 0;

    // Instantiate DUT
    adder_32bit uut (
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

    // Task for running a single test
    task automatic run_test;
        input [31:0] a_val;
        input [31:0] b_val;
        input [31:0] expected;
        begin
            test_num = test_num + 1;
            // ??m b?o input ?n ??nh tr??c khi vào test
            @(negedge clk);
            i_a = a_val;
            i_b = b_val;
            i_vld = 1'b1;
            @(posedge clk); // ??i m?t chu k? ?? DUT nh?n input
            i_vld = 1'b0;
            // Ch? ??n khi o_res_vld lên 1
            wait (o_res_vld == 1);
            #1; // Cho output settle

            $display("----------------------------------");
            $display("Test %0d: 0x%08h + 0x%08h", test_num, a_val, b_val);
            $display("  Expected: 0x%08h", expected);
            $display("  Actual:   0x%08h", o_res);
            $display("  Overflow: %b", overflow);

            if (o_res === expected) begin
                $display("  Result:   PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("  Result:   FAIL");
                fail_count = fail_count + 1;
            end

            // Ch? o_res_vld xu?ng 0 tr??c test ti?p theo, tránh l?p l?i trên cùng k?t qu?
            @(negedge o_res_vld);
        end
    endtask

    initial begin
        $display("\nStarting adder_32bit testbench\n");
        clk = 0; rst = 1; i_vld = 0;
        #15 rst = 0;
        @(posedge clk); // Ch? thêm 1 chu k? sau khi reset

        // Test cases (expected value ?ã chu?n hóa theo IEEE 754)
// 2.0 + 3.0 = 5.0
run_test(32'h40000000, 32'h40400000, 32'h40A00000);

// -2.0 + 3.0 = 1.0
run_test(32'hC0000000, 32'h40400000, 32'h3F800000);

// 0.0 + 123.456 = 123.456
run_test(32'h00000000, 32'h42F6E979, 32'h42F6E979);

// inf + 2.0 = inf
run_test(32'h7F800000, 32'h40000000, 32'h7F800000);

// inf + -2.0 = inf
run_test(32'h7F800000, 32'hC0000000, 32'h7F800000);

// nan + 2.0 = nan
run_test(32'h7FC00000, 32'h40000000, 32'h7FC00000);

// inf + 0.0 = inf
run_test(32'h7F800000, 32'h00000000, 32'h7F800000);

// 1.5 + -4.25 = -2.75
run_test(32'h3FC00000, 32'hC0880000, 32'hC0300000);

// 10.24 + -4.25 = 5.99
run_test(32'h4123D70A, 32'hC0880000, 32'h40BFAE14);

// 1e-09 + -10.88888888 = -10.888888879
run_test(32'h3089705F, 32'hC12E38E4, 32'hC12E38E4);
        $display("\nTestbench Complete.");
        $display("Tests Run: %0d", test_num);
        $display("Passed:    %0d", pass_count);
        $display("Failed:    %0d", fail_count);

        if (fail_count == 0) $display("SUCCESS: All tests passed!");
        else                 $display("FAILURE: Some tests failed.");

        #10 $finish;
    end

    // Optional: waveform dump for GTKWave
    initial begin
        $dumpfile("adder_tb.vcd");
        $dumpvars(0, adder_tb);
    end

endmodule
