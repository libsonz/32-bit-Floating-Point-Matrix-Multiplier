`timescale 1ns / 1ps

module multiplier_tb();

    reg clk, rst;
    reg [31:0] i_a, i_b;
    reg i_vld;
    wire [31:0] o_res;
    wire o_res_vld;
    wire overflow;

    reg [31:0] expected_res;
    integer pass_count = 0, fail_count = 0, test_count = 0;

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

    // Task to run a single test
    task automatic run_test;
        input [31:0] a_val;
        input [31:0] b_val;
        input [31:0] expect_val;
        begin
            @(negedge clk);
            i_a = a_val;
            i_b = b_val;
            i_vld = 1'b1;
            expected_res = expect_val;

            @(negedge clk);
            i_vld = 1'b0;

            // Wait for output valid
            wait (o_res_vld === 1'b1);
            @(posedge clk); // sample at valid

            test_count = test_count + 1;
            $display("Test %0d: 0x%08h * 0x%08h", test_count, a_val, b_val);
            $display("  Expected: 0x%08h", expected_res);
            $display("  Actual:   0x%08h", o_res);
            if (o_res === expected_res) begin
                $display("  Result:   PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("  Result:   FAIL");
                fail_count = fail_count + 1;
            end
            $display("----------------------------------");
        end
    endtask

    // Main test sequence
    initial begin
        $display("Time\t\tA\t\t\tB\t\t\tResult\t\t\tOverflow");
        clk = 0; rst = 1; i_vld = 0; i_a = 0; i_b = 0;
        #10 rst = 0;

        // 2.0 * 3.0 = 6.0
        run_test(32'h40000000, 32'h40400000, 32'h40c00000);

        // -2.0 * 3.0 = -6.0
        run_test(32'hc0000000, 32'h40400000, 32'hc0c00000);

        // 0.0 * 123.456 = 0.0
        run_test(32'h00000000, 32'h42f6e979, 32'h00000000);

        // inf * 2.0 = inf
        run_test(32'h7f800000, 32'h40000000, 32'h7f800000);

        // inf * -2.0 = -inf
        run_test(32'h7f800000, 32'hc0000000, 32'hff800000);

        // nan * 2.0 = nan (canonical nan)
        run_test(32'h7fc00000, 32'h40000000, 32'h7fc00000);

        // inf * 0.0 = nan (canonical nan)
        run_test(32'h7f800000, 32'h00000000, 32'h7fc00000);

        // 1.5 * -4.25 = -6.375
        run_test(32'h3fc00000, 32'hc0880000, 32'hc0cc0000);

        // 10.24 * -4.25 = -43.52
        run_test(32'h4123ae14, 32'hc0880000, 32'hc22de8f5);

        // 0.000000001 * -10.88888888 = -1.08888895e-8
        run_test(32'h2f5c28f5, 32'hc120e147, 32'hb10a5b56);

        // ==== H?t các test case ====

        $display("\nTestbench Complete.");
        $display("Tests Run: %0d", test_count);
        $display("Passed:    %0d", pass_count);
        $display("Failed:    %0d", fail_count);
        #20 $finish;
    end

    // Optional: waveform dump for GTKWave
    initial begin
        $dumpfile("multiplier_tb.vcd");
        $dumpvars(0, multiplier_tb);
    end

    // Optionally: always display when valid output (debug)
    always @(posedge clk) begin
        if (o_res_vld) begin
            $display("%0t\t0x%08h\t0x%08h\t0x%08h\t%b",
                $time, i_a, i_b, o_res, overflow);
        end
    end

endmodule
